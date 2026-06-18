import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/model/persistence/chat_trusted_device.dart';

const _unchanged = Object();

class ChatState {
  final List<ChatTrustedDevice> trustedDevices;
  final List<ChatConversation> conversations;
  final List<ChatMessage> messages;
  final String? selectedFingerprint;

  const ChatState({
    required this.trustedDevices,
    required this.conversations,
    required this.messages,
    required this.selectedFingerprint,
  });

  ChatState copyWith({
    List<ChatTrustedDevice>? trustedDevices,
    List<ChatConversation>? conversations,
    List<ChatMessage>? messages,
    Object? selectedFingerprint = _unchanged,
  }) {
    return ChatState(
      trustedDevices: trustedDevices ?? this.trustedDevices,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      selectedFingerprint: identical(selectedFingerprint, _unchanged) ? this.selectedFingerprint : selectedFingerprint as String?,
    );
  }
}
