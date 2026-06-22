import 'package:path/path.dart' as path;

String chatAttachmentTransferFileName({
  required String fileName,
  required DateTime timestamp,
}) {
  final month = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}';
  return path.posix.join(month, fileName.replaceAll('\\', '/'));
}
