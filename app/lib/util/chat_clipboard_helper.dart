import 'dart:io';

import 'package:common/model/file_type.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/determine_image_type.dart';
import 'package:localsend_app/util/file_path_helper.dart';
import 'package:localsend_app/util/image_converter.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uri_content/uri_content.dart';

final _uriContent = UriContent();

class ChatClipboardPayload {
  final String? text;
  final List<CrossFile> files;

  const ChatClipboardPayload({
    required this.text,
    required this.files,
  });

  bool get isEmpty => (text == null || text!.isEmpty) && files.isEmpty;
}

typedef ChatClipboardImageReader = Future<Uint8List?> Function();
typedef ChatClipboardFileReader = Future<List<String>> Function();
typedef ChatClipboardTextReader = Future<String?> Function();
typedef ChatImageTypeDetector = String Function(Uint8List bytes);
typedef ChatBmpConverter = Future<Uint8List> Function(Uint8List bytes);
typedef ChatClipboardFileConverter = Future<CrossFile> Function(String path);
typedef ChatClock = DateTime Function();
typedef ChatClipboardImagePersister =
    Future<String> Function({
      required String fileName,
      required Uint8List bytes,
    });

const _chatClipboardCacheDir = 'localsend-chat';
const _chatClipboardImageDir = 'clipboard';
final _chatClipboardMonthDirPattern = RegExp(r'^\d{6}$');

Future<ChatClipboardPayload> readChatClipboard({
  String? destinationDirectory,
  ChatClipboardImageReader? readImage,
  ChatClipboardFileReader readFiles = Pasteboard.files,
  ChatClipboardTextReader? readText,
  ChatImageTypeDetector detectImageType = determineImageType,
  ChatBmpConverter convertBmp = convertBmpToPng,
  ChatClipboardFileConverter convertFilePath = _convertClipboardFilePath,
  ChatClipboardImagePersister? persistImage,
  ChatClock? now,
}) async {
  final image = await (readImage ?? _readClipboardImage)();
  if (image != null) {
    var imageBytes = image;
    var imageType = detectImageType(imageBytes);
    if (imageType == 'bmp') {
      try {
        imageBytes = await convertBmp(imageBytes);
        imageType = 'png';
      } catch (_) {
        imageType = 'bmp';
      }
    }

    final timestamp = now?.call() ?? DateTime.now();
    final monthDirectoryName = '${timestamp.year}${timestamp.month.twoDigitString}';
    final fileName =
        'clipboard_${timestamp.year}-${timestamp.month.twoDigitString}-${timestamp.day.twoDigitString}_${timestamp.hour.twoDigitString}-${timestamp.minute.twoDigitString}.$imageType';
    final filePath = persistImage == null
        ? await _persistClipboardImage(
            destinationDirectory: destinationDirectory,
            monthDirectoryName: monthDirectoryName,
            fileName: fileName,
            bytes: imageBytes,
          )
        : await persistImage(fileName: fileName, bytes: imageBytes);
    return ChatClipboardPayload(
      text: null,
      files: [
        CrossFile(
          name: fileName,
          fileType: FileType.image,
          size: imageBytes.length,
          thumbnail: imageBytes,
          asset: null,
          path: filePath,
          bytes: null,
          lastModified: null,
          lastAccessed: null,
        ),
      ],
    );
  }

  final filePaths = await readFiles();
  if (filePaths.isNotEmpty) {
    final files = <CrossFile>[];
    for (final filePath in filePaths) {
      files.add(await convertFilePath(filePath));
    }
    return ChatClipboardPayload(text: null, files: files);
  }

  final text = await (readText ?? _readClipboardText)();
  final trimmed = text?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return ChatClipboardPayload(text: text, files: const []);
  }

  return const ChatClipboardPayload(text: null, files: []);
}

Future<String> _persistClipboardImage({
  String? destinationDirectory,
  String? monthDirectoryName,
  required String fileName,
  required Uint8List bytes,
}) async {
  final directory = await _clipboardImageDirectory(
    destinationDirectory: destinationDirectory,
    monthDirectoryName: monthDirectoryName,
  );
  await directory.create(recursive: true);
  final file = File(path.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<bool> isManagedChatClipboardFilePath(String? filePath) async {
  if (filePath == null || filePath.isEmpty) {
    return false;
  }

  final candidatePath = path.normalize(File(filePath).absolute.path);
  if (_isMonthlyManagedClipboardPath(candidatePath)) {
    return true;
  }

  final legacyDirectory = await _legacyClipboardImageDirectory();
  final legacyDirectoryPath = path.normalize(legacyDirectory.absolute.path);
  return path.isWithin(legacyDirectoryPath, candidatePath);
}

Future<Directory> _clipboardImageDirectory({
  String? destinationDirectory,
  String? monthDirectoryName,
}) async {
  final baseDir = destinationDirectory ?? await getDefaultDestinationDirectory();
  return Directory(path.join(baseDir, monthDirectoryName ?? _monthDirectoryName(DateTime.now()), _chatClipboardImageDir));
}

Future<Directory> _legacyClipboardImageDirectory() async {
  final baseDir = await getTemporaryDirectory();
  return Directory(path.join(baseDir.path, _chatClipboardCacheDir, _chatClipboardImageDir));
}

bool _isMonthlyManagedClipboardPath(String filePath) {
  final fileName = path.basename(filePath);
  if (!fileName.startsWith('clipboard_')) {
    return false;
  }

  final parent = path.basename(path.dirname(filePath));
  if (parent != _chatClipboardImageDir) {
    return false;
  }

  final monthDirectoryName = path.basename(path.dirname(path.dirname(filePath)));
  return _chatClipboardMonthDirPattern.hasMatch(monthDirectoryName);
}

String _monthDirectoryName(DateTime timestamp) {
  return '${timestamp.year}${timestamp.month.twoDigitString}';
}

Future<Uint8List?> _readClipboardImage() async {
  return await Pasteboard.image;
}

Future<String?> _readClipboardText() async {
  return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}

Future<CrossFile> _convertClipboardFilePath(String filePath) async {
  final file = XFile(filePath);
  if (!filePath.startsWith('content://')) {
    return await CrossFileConverters.convertXFile(file);
  }

  return CrossFile(
    name: file.name,
    fileType: file.name.guessFileType(),
    size: await _uriContent.getContentLength(Uri.parse(filePath)) ?? -1,
    path: filePath,
    thumbnail: null,
    asset: null,
    bytes: null,
    lastModified: null,
    lastAccessed: null,
  );
}

extension on int {
  String get twoDigitString => toString().padLeft(2, '0');
}
