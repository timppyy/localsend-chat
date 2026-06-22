import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/model/state/chat_state.dart';
import 'package:localsend_app/util/chat_incoming_notification_tracker.dart';
import 'package:test/test.dart';

void main() {
  test('does not notify for messages already loaded on first check', () {
    final tracker = ChatIncomingNotificationTracker();
    final state = _state(messages: [_incoming('message-1')]);

    final event = tracker.nextEvent(
      state,
      isViewingChat: false,
      isAppForeground: true,
    );

    expect(event, isNull);
  });

  test('does not notify while viewing the selected conversation', () {
    final tracker = ChatIncomingNotificationTracker();
    tracker.nextEvent(_state(), isViewingChat: false, isAppForeground: true);
    final state = _state(
      selectedFingerprint: 'fp1',
      messages: [_incoming('message-1')],
    );

    final event = tracker.nextEvent(
      state,
      isViewingChat: true,
      isAppForeground: true,
    );

    expect(event, isNull);
  });

  test('notifies while viewing the selected conversation when the app is not foreground', () {
    final tracker = ChatIncomingNotificationTracker();
    tracker.nextEvent(_state(), isViewingChat: false, isAppForeground: true);
    final state = _state(
      selectedFingerprint: 'fp1',
      messages: [_incoming('message-1')],
    );

    final event = tracker.nextEvent(
      state,
      isViewingChat: true,
      isAppForeground: false,
    );

    expect(event, isNotNull);
    expect(event!.message.id, 'message-1');
  });

  test('notifies for a new incoming message outside the selected conversation', () {
    final tracker = ChatIncomingNotificationTracker();
    tracker.nextEvent(_state(), isViewingChat: false, isAppForeground: true);
    final state = _state(messages: [_incoming('message-1')]);

    final event = tracker.nextEvent(
      state,
      isViewingChat: false,
      isAppForeground: true,
    );

    expect(event, isNotNull);
    expect(event!.message.id, 'message-1');
    expect(event.alias, 'Office PC');
  });

  test('ignores outgoing messages', () {
    final tracker = ChatIncomingNotificationTracker();
    tracker.nextEvent(_state(), isViewingChat: false, isAppForeground: true);
    final state = _state(messages: [_outgoing('message-1')]);

    final event = tracker.nextEvent(
      state,
      isViewingChat: false,
      isAppForeground: true,
    );

    expect(event, isNull);
  });
}

ChatState _state({
  List<ChatMessage> messages = const [],
  String? selectedFingerprint,
}) {
  return ChatState(
    trustedDevices: const [],
    conversations: [
      ChatConversation(
        peerFingerprint: 'fp1',
        alias: 'Office PC',
        lastIp: '192.168.1.42',
        lastPort: 53317,
        https: false,
        lastMessage: 'hello',
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      ),
    ],
    messages: messages,
    selectedFingerprint: selectedFingerprint,
  );
}

ChatMessage _incoming(String id) {
  return _message(
    id: id,
    direction: ChatMessageDirection.incoming,
  );
}

ChatMessage _outgoing(String id) {
  return _message(
    id: id,
    direction: ChatMessageDirection.outgoing,
  );
}

ChatMessage _message({
  required String id,
  required ChatMessageDirection direction,
}) {
  return ChatMessage(
    id: id,
    peerFingerprint: 'fp1',
    direction: direction,
    kind: ChatMessageKind.text,
    status: ChatMessageStatus.received,
    text: 'hello',
    fileName: null,
    fileSize: null,
    filePath: null,
    errorMessage: null,
    timestamp: DateTime.utc(2026, 6, 22, 10),
  );
}
