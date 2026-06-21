import 'dart:typed_data';

import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/chat_clipboard_helper.dart';
import 'package:test/test.dart';

void main() {
  test('reads clipboard image before clipboard text', () async {
    final result = await readChatClipboard(
      readImage: () async => Uint8List.fromList([1, 2, 3]),
      readFiles: () async => const [],
      readText: () async => 'text fallback',
      detectImageType: (_) => 'png',
      now: () => DateTime(2026, 6, 21, 23, 39),
    );

    expect(result.text, isNull);
    expect(result.files, hasLength(1));
    expect(result.files.single.name, 'clipboard_2026-06-21_23-39.png');
    expect(result.files.single.fileType, FileType.image);
    expect(result.files.single.thumbnail, isNotNull);
  });

  test('reads clipboard files before clipboard text', () async {
    final result = await readChatClipboard(
      readImage: () async => null,
      readFiles: () async => const [r'C:\Users\admin\Pictures\photo.png'],
      readText: () async => 'text fallback',
      convertFilePath: (path) async => CrossFile(
        name: 'photo.png',
        fileType: FileType.image,
        size: 42,
        thumbnail: null,
        asset: null,
        path: path,
        bytes: null,
        lastModified: null,
        lastAccessed: null,
      ),
    );

    expect(result.text, isNull);
    expect(result.files.single.path, r'C:\Users\admin\Pictures\photo.png');
  });

  test('falls back to clipboard text when no image or files exist', () async {
    final result = await readChatClipboard(
      readImage: () async => null,
      readFiles: () async => const [],
      readText: () async => 'hello',
    );

    expect(result.text, 'hello');
    expect(result.files, isEmpty);
  });
}
