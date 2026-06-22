import 'package:collection/collection.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/model/state/chat_state.dart';

class ChatIncomingNotificationEvent {
  final ChatMessage message;
  final String alias;

  const ChatIncomingNotificationEvent({
    required this.message,
    required this.alias,
  });
}

class ChatIncomingNotificationTracker {
  final Set<String> _knownMessageIds = {};
  bool _initialized = false;

  ChatIncomingNotificationEvent? nextEvent(
    ChatState state, {
    required bool isViewingChat,
    required bool isAppForeground,
  }) {
    if (!_initialized) {
      _knownMessageIds.addAll(state.messages.map((message) => message.id));
      _initialized = true;
      return null;
    }

    final newIncomingMessages = state.messages
        .where((message) => !_knownMessageIds.contains(message.id))
        .where((message) => message.direction == ChatMessageDirection.incoming)
        .sorted((a, b) => a.timestamp.compareTo(b.timestamp));
    _knownMessageIds.addAll(state.messages.map((message) => message.id));

    for (final message in newIncomingMessages) {
      if (isAppForeground && isViewingChat && state.selectedFingerprint == message.peerFingerprint) {
        continue;
      }
      final conversation = state.conversations.firstWhereOrNull((entry) => entry.peerFingerprint == message.peerFingerprint);
      return ChatIncomingNotificationEvent(
        message: message,
        alias: conversation?.alias ?? message.peerFingerprint,
      );
    }

    return null;
  }
}
