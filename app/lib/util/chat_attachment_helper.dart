import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/util/file_path_helper.dart';

const _previewableImageExtensions = {
  'bmp',
  'gif',
  'jpg',
  'jpeg',
  'png',
  'webp',
};

String chatAttachmentName(ChatMessage message) {
  return message.fileName ?? message.filePath?.fileName ?? 'File';
}

FileType chatAttachmentType(ChatMessage message) {
  final name = message.fileName ?? message.filePath;
  return name == null ? FileType.other : name.guessFileType();
}

bool canPreviewChatImage(ChatMessage message) {
  if (message.kind != ChatMessageKind.file || message.filePath == null) {
    return false;
  }
  final name = message.fileName ?? message.filePath!;
  return _previewableImageExtensions.contains(name.extension);
}
