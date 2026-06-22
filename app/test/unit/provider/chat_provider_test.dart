import 'package:common/api_route_builder.dart';
import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:common/model/dto/chat_peer_dto.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/model/persistence/chat_trusted_device.dart';
import 'package:localsend_app/provider/chat_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:test/test.dart';

import '../../mocks.mocks.dart';

void main() {
  late MockPersistenceService persistenceService;

  setUp(() {
    persistenceService = MockPersistenceService();
    when(persistenceService.getChatTrustedDevices()).thenReturn([]);
    when(persistenceService.getChatConversations()).thenReturn([]);
    when(persistenceService.getChatMessages()).thenReturn([]);
  });

  test('trusts a device and persists it', () async {
    final service = ReduxNotifier.test(
      redux: ChatService(persistence: persistenceService),
    );
    final trusted = _trustedDevice('fp1', token: 'token1');

    await service.dispatchAsync(TrustChatDeviceAction(trusted));

    expect(service.state.trustedDevices, [trusted]);
    verify(persistenceService.setChatTrustedDevices([trusted]));
  });

  test('stores incoming text and creates a conversation', () async {
    final service = ReduxNotifier.test(
      redux: ChatService(persistence: persistenceService),
    );
    final timestamp = DateTime.utc(2026, 6, 18, 11, 30);

    await service.dispatchAsync(
      AddIncomingChatMessageAction(
        peer: const ChatPeerDto(
          alias: 'Office PC',
          version: '2.1',
          deviceModel: 'Windows',
          deviceType: DeviceType.desktop,
          fingerprint: 'fp1',
          port: 53317,
          protocol: ProtocolType.http,
        ),
        messageId: 'message-1',
        text: 'hello',
        timestamp: timestamp,
      ),
    );

    expect(service.state.conversations.single.peerFingerprint, 'fp1');
    expect(service.state.conversations.single.alias, 'Office PC');
    expect(service.state.conversations.single.lastMessage, 'hello');
    expect(service.state.messages.single.id, 'message-1');
    expect(service.state.messages.single.text, 'hello');
    expect(service.state.messages.single.status, ChatMessageStatus.received);
    verify(persistenceService.setChatMessages(service.state.messages));
    verify(persistenceService.setChatConversations(service.state.conversations));
  });

  test('deduplicates incoming text by message id', () async {
    final service = ReduxNotifier.test(
      redux: ChatService(persistence: persistenceService),
    );
    final timestamp = DateTime.utc(2026, 6, 18, 11, 30);
    const peer = ChatPeerDto(
      alias: 'Office PC',
      version: '2.1',
      deviceModel: 'Windows',
      deviceType: DeviceType.desktop,
      fingerprint: 'fp1',
      port: 53317,
      protocol: ProtocolType.http,
    );

    await service.dispatchAsync(
      AddIncomingChatMessageAction(
        peer: peer,
        messageId: 'message-1',
        text: 'hello',
        timestamp: timestamp,
      ),
    );
    await service.dispatchAsync(
      AddIncomingChatMessageAction(
        peer: peer,
        messageId: 'message-1',
        text: 'hello again',
        timestamp: timestamp.add(const Duration(seconds: 1)),
      ),
    );

    expect(service.state.messages, hasLength(1));
    expect(service.state.messages.single.text, 'hello again');
  });

  test('offline text message is stored as failed', () async {
    final service = ReduxNotifier.test(
      redux: ChatService(persistence: persistenceService),
    );

    await service.dispatchAsync(
      SendTextMessageAction(
        peerFingerprint: 'fp1',
        text: 'hello',
      ),
    );

    expect(service.state.messages.single.text, 'hello');
    expect(service.state.messages.single.status, ChatMessageStatus.failed);
    expect(service.state.messages.single.errorMessage, 'Device is offline.');
  });

  test('first text request stores returned chat token', () async {
    final target = _device(fingerprint: 'fp1');
    final local = _device(fingerprint: 'self', alias: 'Me');
    final calls = <ApiRoute>[];
    final service = ReduxNotifier.test(
      redux: ChatService(
        persistence: persistenceService,
        findDevice: (_) => target,
        localDevice: () => local,
        postJson: ({required target, required route, required body}) async {
          calls.add(route);
          expect(body['sender']['fingerprint'], 'self');
          return const ChatHttpResponse(
            statusCode: 200,
            body: {'chatToken': 'token1'},
          );
        },
      ),
    );

    await service.dispatchAsync(
      SendTextMessageAction(
        peerFingerprint: 'fp1',
        text: 'hello',
      ),
    );

    expect(calls, [ApiRoute.chatRequest]);
    expect(service.state.messages.single.status, ChatMessageStatus.sent);
    expect(service.state.trustedDevices.single.token, 'token1');
    verify(persistenceService.setChatTrustedDevices(service.state.trustedDevices));
  });

  test('trusted text message uses chat message endpoint', () async {
    final trusted = _trustedDevice('fp1', token: 'token1');
    when(persistenceService.getChatTrustedDevices()).thenReturn([trusted]);
    final calls = <ApiRoute>[];
    final service = ReduxNotifier.test(
      redux: ChatService(
        persistence: persistenceService,
        findDevice: (_) => _device(fingerprint: 'fp1'),
        localDevice: () => _device(fingerprint: 'self', alias: 'Me'),
        postJson: ({required target, required route, required body}) async {
          calls.add(route);
          expect(body['chatToken'], 'token1');
          return const ChatHttpResponse(statusCode: 200, body: {});
        },
      ),
    );

    await service.dispatchAsync(
      SendTextMessageAction(
        peerFingerprint: 'fp1',
        text: 'hello',
      ),
    );

    expect(calls, [ApiRoute.chatMessage]);
    expect(service.state.messages.single.status, ChatMessageStatus.sent);
  });

  test('trusted text message falls back to stored address', () async {
    final trusted = _trustedDevice('fp1', token: 'token1');
    when(persistenceService.getChatTrustedDevices()).thenReturn([trusted]);
    Device? targetDevice;
    final service = ReduxNotifier.test(
      redux: ChatService(
        persistence: persistenceService,
        localDevice: () => _device(fingerprint: 'self', alias: 'Me'),
        postJson: ({required target, required route, required body}) async {
          targetDevice = target;
          return const ChatHttpResponse(statusCode: 200, body: {});
        },
      ),
    );

    await service.dispatchAsync(
      SendTextMessageAction(
        peerFingerprint: 'fp1',
        text: 'hello',
      ),
    );

    expect(targetDevice?.ip, '192.168.1.42');
    expect(targetDevice?.port, 53317);
    expect(service.state.messages.single.status, ChatMessageStatus.sent);
  });

  test('invalid trusted token falls back to chat request and stores new token', () async {
    final trusted = _trustedDevice('fp1', token: 'old-token');
    when(persistenceService.getChatTrustedDevices()).thenReturn([trusted]);
    final calls = <ApiRoute>[];
    final service = ReduxNotifier.test(
      redux: ChatService(
        persistence: persistenceService,
        findDevice: (_) => _device(fingerprint: 'fp1'),
        localDevice: () => _device(fingerprint: 'self', alias: 'Me'),
        postJson: ({required target, required route, required body}) async {
          calls.add(route);
          if (route == ApiRoute.chatMessage) {
            return const ChatHttpResponse(statusCode: 401, body: {'message': 'Invalid chat token'});
          }
          return const ChatHttpResponse(statusCode: 200, body: {'chatToken': 'new-token'});
        },
      ),
    );

    await service.dispatchAsync(
      SendTextMessageAction(
        peerFingerprint: 'fp1',
        text: 'hello',
      ),
    );

    expect(calls, [ApiRoute.chatMessage, ApiRoute.chatRequest]);
    expect(service.state.messages.single.status, ChatMessageStatus.sent);
    expect(service.state.trustedDevices.single.token, 'new-token');
  });

  test('declined chat request marks message as declined', () async {
    final service = ReduxNotifier.test(
      redux: ChatService(
        persistence: persistenceService,
        findDevice: (_) => _device(fingerprint: 'fp1'),
        localDevice: () => _device(fingerprint: 'self', alias: 'Me'),
        postJson: ({required target, required route, required body}) async {
          return const ChatHttpResponse(
            statusCode: 403,
            body: {'message': 'Chat request declined by recipient'},
          );
        },
      ),
    );

    await service.dispatchAsync(
      SendTextMessageAction(
        peerFingerprint: 'fp1',
        text: 'hello',
      ),
    );

    expect(service.state.messages.single.status, ChatMessageStatus.declined);
    expect(service.state.messages.single.errorMessage, 'Chat request declined by recipient');
  });

  test('non-json send error is stored as a readable chat error', () async {
    final service = ReduxNotifier.test(
      redux: ChatService(
        persistence: persistenceService,
        findDevice: (_) => _device(fingerprint: 'fp1'),
        localDevice: () => _device(fingerprint: 'self', alias: 'Me'),
        postJson: ({required target, required route, required body}) async {
          throw const FormatException('Unexpected character', 'Not found', 0);
        },
      ),
    );

    await service.dispatchAsync(
      SendTextMessageAction(
        peerFingerprint: 'fp1',
        text: 'hello',
      ),
    );

    expect(service.state.messages.single.status, ChatMessageStatus.failed);
    expect(service.state.messages.single.errorMessage, isNot(contains('FormatException')));
    expect(service.state.messages.single.errorMessage, 'Chat is not available on this device.');
  });

  test('deletes a local chat message and refreshes conversation summary', () async {
    final older = _message(
      id: 'message-1',
      text: 'first',
      timestamp: DateTime.utc(2026, 6, 18, 11),
    );
    final newer = _message(
      id: 'message-2',
      text: 'second',
      timestamp: DateTime.utc(2026, 6, 18, 12),
    );
    when(persistenceService.getChatMessages()).thenReturn([older, newer]);
    when(persistenceService.getChatConversations()).thenReturn([
      ChatConversation(
        peerFingerprint: 'fp1',
        alias: 'Office PC',
        lastIp: '192.168.1.42',
        lastPort: 53317,
        https: false,
        lastMessage: 'second',
        updatedAt: newer.timestamp,
      ),
    ]);
    final service = ReduxNotifier.test(
      redux: ChatService(persistence: persistenceService),
    );

    await service.dispatchAsync(DeleteChatMessageAction('message-2'));

    expect(service.state.messages, [older]);
    expect(service.state.conversations.single.lastMessage, 'first');
    expect(service.state.conversations.single.updatedAt, older.timestamp);
    verify(persistenceService.setChatMessages([older]));
    verify(persistenceService.setChatConversations(service.state.conversations));
  });

  test('clears a local conversation and all of its messages', () async {
    final firstPeerMessage = _message(
      id: 'message-1',
      text: 'first',
      timestamp: DateTime.utc(2026, 6, 18, 11),
    );
    final secondPeerMessage = _message(
      id: 'message-2',
      text: 'second',
      timestamp: DateTime.utc(2026, 6, 18, 12),
    );
    final otherPeerMessage = _message(
      id: 'message-3',
      text: 'keep me',
      timestamp: DateTime.utc(2026, 6, 18, 13),
      peerFingerprint: 'fp2',
    );
    when(persistenceService.getChatMessages()).thenReturn([firstPeerMessage, secondPeerMessage, otherPeerMessage]);
    when(persistenceService.getChatConversations()).thenReturn([
      ChatConversation(
        peerFingerprint: 'fp1',
        alias: 'Office PC',
        lastIp: '192.168.1.42',
        lastPort: 53317,
        https: false,
        lastMessage: 'second',
        updatedAt: secondPeerMessage.timestamp,
      ),
      ChatConversation(
        peerFingerprint: 'fp2',
        alias: 'Laptop',
        lastIp: '192.168.1.43',
        lastPort: 53317,
        https: false,
        lastMessage: 'keep me',
        updatedAt: otherPeerMessage.timestamp,
      ),
    ]);
    final service = ReduxNotifier.test(
      redux: ChatService(persistence: persistenceService),
    );

    await service.dispatchAsync(ClearChatConversationAction('fp1'));

    expect(service.state.messages, [otherPeerMessage]);
    expect(service.state.conversations.map((entry) => entry.peerFingerprint), ['fp2']);
    verify(persistenceService.setChatMessages([otherPeerMessage]));
    verify(persistenceService.setChatConversations(service.state.conversations));
  });
}

ChatTrustedDevice _trustedDevice(String fingerprint, {required String token}) {
  final now = DateTime.utc(2026, 6, 18, 11);
  return ChatTrustedDevice(
    fingerprint: fingerprint,
    alias: 'Office PC',
    token: token,
    lastIp: '192.168.1.42',
    lastPort: 53317,
    https: false,
    trustedAt: now,
    updatedAt: now,
  );
}

Device _device({
  required String fingerprint,
  String alias = 'Office PC',
}) {
  return Device(
    signalingId: null,
    ip: '192.168.1.42',
    version: protocolVersion,
    port: 53317,
    https: false,
    fingerprint: fingerprint,
    alias: alias,
    deviceModel: 'Windows',
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: {HttpDiscovery(ip: '192.168.1.42')},
  );
}

ChatMessage _message({
  required String id,
  required String text,
  required DateTime timestamp,
  String peerFingerprint = 'fp1',
}) {
  return ChatMessage(
    id: id,
    peerFingerprint: peerFingerprint,
    direction: ChatMessageDirection.outgoing,
    kind: ChatMessageKind.text,
    status: ChatMessageStatus.sent,
    text: text,
    fileName: null,
    fileSize: null,
    filePath: null,
    errorMessage: null,
    timestamp: timestamp,
  );
}
