import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/model/persistence/chat_trusted_device.dart';
import 'package:test/test.dart';

void main() {
  test('chat trusted device serializes to json', () {
    final trusted = ChatTrustedDevice(
      fingerprint: 'fp1',
      alias: 'Office PC',
      token: 'token1',
      lastIp: '192.168.1.42',
      lastPort: 53317,
      https: false,
      trustedAt: DateTime.utc(2026, 6, 18, 11),
      updatedAt: DateTime.utc(2026, 6, 18, 12),
    );

    expect(ChatTrustedDevice.fromJson(trusted.toJson()), trusted);
  });

  test('chat conversation serializes to json', () {
    final conversation = ChatConversation(
      peerFingerprint: 'fp1',
      alias: 'Office PC',
      lastIp: '192.168.1.42',
      lastPort: 53317,
      https: false,
      lastMessage: 'hello',
      updatedAt: DateTime.utc(2026, 6, 18, 12),
    );

    expect(ChatConversation.fromJson(conversation.toJson()), conversation);
  });

  test('chat message serializes to json', () {
    final message = ChatMessage(
      id: 'message-1',
      peerFingerprint: 'fp1',
      direction: ChatMessageDirection.incoming,
      kind: ChatMessageKind.text,
      status: ChatMessageStatus.received,
      text: 'hello',
      fileName: null,
      fileSize: null,
      filePath: null,
      errorMessage: null,
      timestamp: DateTime.utc(2026, 6, 18, 12),
    );

    expect(ChatMessage.fromJson(message.toJson()), message);
  });

  test('chat message copyWith can clear an error', () {
    final message = ChatMessage(
      id: 'message-1',
      peerFingerprint: 'fp1',
      direction: ChatMessageDirection.outgoing,
      kind: ChatMessageKind.text,
      status: ChatMessageStatus.failed,
      text: 'hello',
      fileName: null,
      fileSize: null,
      filePath: null,
      errorMessage: 'offline',
      timestamp: DateTime.utc(2026, 6, 18, 12),
    );

    final updated = message.copyWith(
      status: ChatMessageStatus.sent,
      errorMessage: null,
    );

    expect(updated.status, ChatMessageStatus.sent);
    expect(updated.errorMessage, isNull);
  });
}
