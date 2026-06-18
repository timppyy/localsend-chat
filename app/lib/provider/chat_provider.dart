import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/api_route_builder.dart';
import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:common/model/dto/chat_message_dto.dart';
import 'package:common/model/dto/chat_peer_dto.dart';
import 'package:common/model/dto/chat_request_dto.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/model/persistence/chat_trusted_device.dart';
import 'package:localsend_app/model/state/chat_state.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _maxMessagesPerConversation = 500;

class ChatHttpResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const ChatHttpResponse({
    required this.statusCode,
    required this.body,
  });
}

typedef ChatPostJson = Future<ChatHttpResponse> Function({
  required Device target,
  required ApiRoute route,
  required Map<String, dynamic> body,
});
typedef ChatDeviceLookup = Device? Function(String fingerprint);
typedef ChatLocalDevice = Device Function();

final chatProvider = ReduxProvider<ChatService, ChatState>((ref) {
  return ChatService(
    persistence: ref.read(persistenceProvider),
    findDevice: (fingerprint) => _findDeviceByFingerprint(ref.read(nearbyDevicesProvider).allDevices.values, fingerprint),
    localDevice: () => ref.read(deviceFullInfoProvider),
  );
});

class ChatService extends ReduxNotifier<ChatState> {
  final PersistenceService _persistence;
  final ChatPostJson? _postJsonOverride;
  final ChatDeviceLookup _findDevice;
  final ChatLocalDevice? _localDevice;

  ChatService({
    required PersistenceService persistence,
    ChatPostJson? postJson,
    ChatDeviceLookup? findDevice,
    ChatLocalDevice? localDevice,
  }) : _persistence = persistence,
       _postJsonOverride = postJson,
       _findDevice = findDevice ?? ((_) => null),
       _localDevice = localDevice;

  @override
  ChatState init() {
    return ChatState(
      trustedDevices: _persistence.getChatTrustedDevices(),
      conversations: _persistence.getChatConversations(),
      messages: _persistence.getChatMessages(),
      selectedFingerprint: null,
    );
  }

  Future<ChatHttpResponse> postJson({
    required Device target,
    required ApiRoute route,
    required Map<String, dynamic> body,
  }) async {
    final override = _postJsonOverride;
    if (override != null) {
      return override(target: target, route: route, body: body);
    }

    final client = HttpClient()
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final request = await client.postUrl(Uri.parse(route.target(target)));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      final decoded = responseBody.isEmpty ? <String, dynamic>{} : jsonDecode(responseBody) as Map<String, dynamic>;
      return ChatHttpResponse(
        statusCode: response.statusCode,
        body: decoded,
      );
    } finally {
      client.close(force: true);
    }
  }

  Device? findDevice(String fingerprint) => _findDevice(fingerprint);

  Device localDevice() {
    final localDevice = _localDevice;
    if (localDevice == null) {
      throw StateError('Local device information is not available.');
    }
    return localDevice();
  }
}

class SelectConversationAction extends ReduxAction<ChatService, ChatState> {
  final String fingerprint;

  SelectConversationAction(this.fingerprint);

  @override
  ChatState reduce() {
    return state.copyWith(selectedFingerprint: fingerprint);
  }
}

class TrustChatDeviceAction extends AsyncReduxAction<ChatService, ChatState> {
  final ChatTrustedDevice trustedDevice;

  TrustChatDeviceAction(this.trustedDevice);

  @override
  Future<ChatState> reduce() async {
    final updated = [
      trustedDevice,
      ...state.trustedDevices.where((device) => device.fingerprint != trustedDevice.fingerprint),
    ];
    await notifier._persistence.setChatTrustedDevices(updated);
    return state.copyWith(trustedDevices: updated);
  }
}

class AddIncomingChatMessageAction extends AsyncReduxAction<ChatService, ChatState> {
  final ChatPeerDto peer;
  final String messageId;
  final String text;
  final DateTime timestamp;
  final String? ip;

  AddIncomingChatMessageAction({
    required this.peer,
    required this.messageId,
    required this.text,
    required this.timestamp,
    this.ip,
  });

  @override
  Future<ChatState> reduce() async {
    final message = ChatMessage(
      id: messageId,
      peerFingerprint: peer.fingerprint,
      direction: ChatMessageDirection.incoming,
      kind: ChatMessageKind.text,
      status: ChatMessageStatus.received,
      text: text,
      fileName: null,
      fileSize: null,
      filePath: null,
      errorMessage: null,
      timestamp: timestamp,
    );

    return await _persistMessageAndConversation(
      state: state,
      persistence: notifier._persistence,
      message: message,
      peerFingerprint: peer.fingerprint,
      alias: peer.alias,
      lastIp: ip,
      lastPort: peer.port,
      https: peer.protocol == ProtocolType.https,
      lastMessage: text,
    );
  }
}

class AddOutgoingFileMessageAction extends AsyncReduxAction<ChatService, ChatState> {
  final String peerFingerprint;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final String? errorMessage;

  AddOutgoingFileMessageAction({
    required this.peerFingerprint,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    this.errorMessage,
  });

  @override
  Future<ChatState> reduce() async {
    final device = notifier.findDevice(peerFingerprint) ?? _storedDeviceFor(state, peerFingerprint);
    final message = ChatMessage(
      id: _uuid.v4(),
      peerFingerprint: peerFingerprint,
      direction: ChatMessageDirection.outgoing,
      kind: ChatMessageKind.file,
      status: device == null || errorMessage != null ? ChatMessageStatus.failed : ChatMessageStatus.sent,
      text: null,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      errorMessage: errorMessage ?? (device == null ? 'Device is offline.' : null),
      timestamp: DateTime.now().toUtc(),
    );

    return await _persistMessageAndConversation(
      state: state,
      persistence: notifier._persistence,
      message: message,
      peerFingerprint: peerFingerprint,
      alias: device?.alias ?? peerFingerprint,
      lastIp: device?.ip,
      lastPort: device?.port,
      https: device?.https,
      lastMessage: fileName,
    );
  }
}

class AddIncomingFileMessageAction extends AsyncReduxAction<ChatService, ChatState> {
  final Device sender;
  final String fileId;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final DateTime timestamp;

  AddIncomingFileMessageAction({
    required this.sender,
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    required this.timestamp,
  });

  @override
  Future<ChatState> reduce() async {
    final hasConversation = state.conversations.any((conversation) => conversation.peerFingerprint == sender.fingerprint);
    final trusted = state.trustedDevices.any((device) => device.fingerprint == sender.fingerprint);
    if (!hasConversation && !trusted) {
      return state;
    }

    final message = ChatMessage(
      id: fileId,
      peerFingerprint: sender.fingerprint,
      direction: ChatMessageDirection.incoming,
      kind: ChatMessageKind.file,
      status: ChatMessageStatus.received,
      text: null,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      errorMessage: null,
      timestamp: timestamp,
    );

    return await _persistMessageAndConversation(
      state: state,
      persistence: notifier._persistence,
      message: message,
      peerFingerprint: sender.fingerprint,
      alias: sender.alias,
      lastIp: sender.ip,
      lastPort: sender.port,
      https: sender.https,
      lastMessage: fileName,
    );
  }
}

class SendTextMessageAction extends AsyncReduxAction<ChatService, ChatState> {
  final String peerFingerprint;
  final String text;

  SendTextMessageAction({
    required this.peerFingerprint,
    required this.text,
  });

  @override
  Future<ChatState> reduce() async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return state;
    }

    final device = notifier.findDevice(peerFingerprint) ?? _storedDeviceFor(state, peerFingerprint);
    final now = DateTime.now().toUtc();
    final message = ChatMessage(
      id: _uuid.v4(),
      peerFingerprint: peerFingerprint,
      direction: ChatMessageDirection.outgoing,
      kind: ChatMessageKind.text,
      status: ChatMessageStatus.sending,
      text: trimmed,
      fileName: null,
      fileSize: null,
      filePath: null,
      errorMessage: null,
      timestamp: now,
    );

    var nextState = await _persistMessageAndConversation(
      state: state,
      persistence: notifier._persistence,
      message: message,
      peerFingerprint: peerFingerprint,
      alias: device?.alias ?? peerFingerprint,
      lastIp: device?.ip,
      lastPort: device?.port,
      https: device?.https,
      lastMessage: trimmed,
    );

    if (device == null || device.ip == null) {
      return await _persistMessageStatus(
        state: nextState,
        persistence: notifier._persistence,
        messageId: message.id,
        status: ChatMessageStatus.failed,
        errorMessage: 'Device is offline.',
      );
    }

    final origin = notifier.localDevice();
    final sender = ChatPeerDto(
      alias: origin.alias,
      version: protocolVersion,
      deviceModel: origin.deviceModel,
      deviceType: origin.deviceType,
      fingerprint: origin.fingerprint,
      port: origin.port,
      protocol: origin.https ? ProtocolType.https : ProtocolType.http,
    );

    final trusted = nextState.trustedDevices.firstWhereOrNull((entry) => entry.fingerprint == peerFingerprint);
    ChatHttpResponse response;
    try {
      if (trusted != null) {
        response = await notifier.postJson(
          target: device,
          route: ApiRoute.chatMessage,
          body: ChatMessageDto(
            sender: sender,
            chatToken: trusted.token,
            messageId: message.id,
            text: trimmed,
            timestamp: now,
          ).toJson(),
        );

        if (response.statusCode == HttpStatus.unauthorized || response.statusCode == HttpStatus.forbidden) {
          response = await _sendChatRequest(device, sender, message.id, trimmed, now);
        }
      } else {
        response = await _sendChatRequest(device, sender, message.id, trimmed, now);
      }
    } catch (e) {
      return await _persistMessageStatus(
        state: nextState,
        persistence: notifier._persistence,
        messageId: message.id,
        status: ChatMessageStatus.failed,
        errorMessage: e.toString(),
      );
    }

    if (response.statusCode == HttpStatus.ok) {
      final token = response.body['chatToken'] as String?;
      if (token != null && token.isNotEmpty) {
        final trustedDevice = ChatTrustedDevice(
          fingerprint: device.fingerprint,
          alias: device.alias,
          token: token,
          lastIp: device.ip,
          lastPort: device.port,
          https: device.https,
          trustedAt: now,
          updatedAt: now,
        );
        final trustedDevices = [
          trustedDevice,
          ...nextState.trustedDevices.where((entry) => entry.fingerprint != device.fingerprint),
        ];
        await notifier._persistence.setChatTrustedDevices(trustedDevices);
        nextState = nextState.copyWith(trustedDevices: trustedDevices);
      }

      return await _persistMessageStatus(
        state: nextState,
        persistence: notifier._persistence,
        messageId: message.id,
        status: ChatMessageStatus.sent,
        errorMessage: null,
      );
    }

    return await _persistMessageStatus(
      state: nextState,
      persistence: notifier._persistence,
      messageId: message.id,
      status: response.statusCode == HttpStatus.forbidden ? ChatMessageStatus.declined : ChatMessageStatus.failed,
      errorMessage: response.body['message'] as String? ?? 'Message could not be sent.',
    );
  }

  Future<ChatHttpResponse> _sendChatRequest(Device device, ChatPeerDto sender, String messageId, String text, DateTime timestamp) {
    return notifier.postJson(
      target: device,
      route: ApiRoute.chatRequest,
      body: ChatRequestDto(
        sender: sender,
        messageId: messageId,
        text: text,
        timestamp: timestamp,
      ).toJson(),
    );
  }
}

Device? _findDeviceByFingerprint(Iterable<Device> devices, String fingerprint) {
  return devices.firstWhereOrNull((device) => device.fingerprint == fingerprint && device.ip != null);
}

Device? _storedDeviceFor(ChatState state, String fingerprint) {
  final trusted = state.trustedDevices.firstWhereOrNull((device) => device.fingerprint == fingerprint);
  final conversation = state.conversations.firstWhereOrNull((entry) => entry.peerFingerprint == fingerprint);
  final ip = trusted?.lastIp ?? conversation?.lastIp;
  final port = trusted?.lastPort ?? conversation?.lastPort;
  if (ip == null || port == null) {
    return null;
  }
  final https = trusted?.https ?? conversation?.https ?? true;
  return Device(
    signalingId: null,
    ip: ip,
    version: protocolVersion,
    port: port,
    https: https,
    fingerprint: fingerprint,
    alias: trusted?.alias ?? conversation?.alias ?? fingerprint,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: {HttpDiscovery(ip: ip)},
  );
}

Future<ChatState> _persistMessageAndConversation({
  required ChatState state,
  required PersistenceService persistence,
  required ChatMessage message,
  required String peerFingerprint,
  required String alias,
  required String? lastIp,
  required int? lastPort,
  required bool? https,
  required String lastMessage,
}) async {
  final messages = [
    message,
    ...state.messages.where((entry) => entry.id != message.id),
  ];
  final limitedMessages = _limitMessages(messages, peerFingerprint);
  await persistence.setChatMessages(limitedMessages);

  final conversation = ChatConversation(
    peerFingerprint: peerFingerprint,
    alias: alias,
    lastIp: lastIp,
    lastPort: lastPort,
    https: https,
    lastMessage: lastMessage,
    updatedAt: message.timestamp,
  );
  final conversations = [
    conversation,
    ...state.conversations.where((entry) => entry.peerFingerprint != peerFingerprint),
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  await persistence.setChatConversations(conversations);

  return state.copyWith(
    conversations: conversations,
    messages: limitedMessages,
  );
}

Future<ChatState> _persistMessageStatus({
  required ChatState state,
  required PersistenceService persistence,
  required String messageId,
  required ChatMessageStatus status,
  required String? errorMessage,
}) async {
  final messages = state.messages.map((message) {
    if (message.id != messageId) {
      return message;
    }
    return message.copyWith(
      status: status,
      errorMessage: errorMessage,
    );
  }).toList();
  await persistence.setChatMessages(messages);
  return state.copyWith(messages: messages);
}

List<ChatMessage> _limitMessages(List<ChatMessage> messages, String peerFingerprint) {
  final peerMessages = messages.where((message) => message.peerFingerprint == peerFingerprint).take(_maxMessagesPerConversation).toSet();
  return messages.where((message) => message.peerFingerprint != peerFingerprint || peerMessages.contains(message)).toList();
}
