import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/util/chat_attachment_save_path.dart';

void main() {
  test('prefixes chat attachment file names with year and month', () {
    final fileName = chatAttachmentTransferFileName(
      fileName: 'photo.png',
      timestamp: DateTime.utc(2026, 6, 22, 10, 30),
    );

    expect(fileName, '202606/photo.png');
  });

  test('keeps existing relative paths under the chat attachment month', () {
    final fileName = chatAttachmentTransferFileName(
      fileName: 'album/photo.png',
      timestamp: DateTime.utc(2026, 12, 1),
    );

    expect(fileName, '202612/album/photo.png');
  });
}
