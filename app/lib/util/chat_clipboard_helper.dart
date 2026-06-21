import 'package:common/model/file_type.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/determine_image_type.dart';
import 'package:localsend_app/util/file_path_helper.dart';
import 'package:localsend_app/util/image_converter.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:pasteboard/pasteboard.dart';
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

Future<ChatClipboardPayload> readChatClipboard({
  ChatClipboardImageReader? readImage,
  ChatClipboardFileReader readFiles = Pasteboard.files,
  ChatClipboardTextReader? readText,
  ChatImageTypeDetector detectImageType = determineImageType,
  ChatBmpConverter convertBmp = convertBmpToPng,
  ChatClipboardFileConverter convertFilePath = _convertClipboardFilePath,
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
    final fileName =
        'clipboard_${timestamp.year}-${timestamp.month.twoDigitString}-${timestamp.day.twoDigitString}_${timestamp.hour.twoDigitString}-${timestamp.minute.twoDigitString}.$imageType';
    return ChatClipboardPayload(
      text: null,
      files: [
        CrossFile(
          name: fileName,
          fileType: FileType.image,
          size: imageBytes.length,
          thumbnail: imageBytes,
          asset: null,
          path: null,
          bytes: imageBytes,
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
