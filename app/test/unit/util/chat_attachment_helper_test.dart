import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/util/chat_attachment_helper.dart';
import 'package:test/test.dart';

void main() {
  test('detects previewable image attachments', () {
    final message = _fileMessage(
      fileName: 'photo.JPG',
      filePath: r'C:\Users\admin\Downloads\photo.JPG',
    );

    expect(chatAttachmentName(message), 'photo.JPG');
    expect(chatAttachmentType(message), FileType.image);
    expect(canPreviewChatImage(message), isTrue);
  });

  test('keeps unsupported image formats as non-previewable attachments', () {
    final message = _fileMessage(
      fileName: 'vector.svg',
      filePath: r'C:\Users\admin\Downloads\vector.svg',
    );

    expect(chatAttachmentType(message), FileType.image);
    expect(canPreviewChatImage(message), isFalse);
  });

  test('detects ordinary file attachments', () {
    final message = _fileMessage(
      fileName: 'notes.txt',
      filePath: r'C:\Users\admin\Downloads\notes.txt',
    );

    expect(chatAttachmentName(message), 'notes.txt');
    expect(chatAttachmentType(message), FileType.text);
    expect(canPreviewChatImage(message), isFalse);
  });
}

ChatMessage _fileMessage({
  required String fileName,
  required String filePath,
}) {
  return ChatMessage(
    id: 'message-1',
    peerFingerprint: 'fp1',
    direction: ChatMessageDirection.incoming,
    kind: ChatMessageKind.file,
    status: ChatMessageStatus.received,
    text: null,
    fileName: fileName,
    fileSize: 1024,
    filePath: filePath,
    errorMessage: null,
    timestamp: DateTime.utc(2026, 6, 19),
  );
}
