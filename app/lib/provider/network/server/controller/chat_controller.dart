import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/api_route_builder.dart';
import 'package:common/model/dto/chat_message_dto.dart';
import 'package:common/model/dto/chat_peer_dto.dart';
import 'package:common/model/dto/chat_request_dto.dart';
import 'package:common/model/dto/chat_request_response_dto.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/persistence/chat_trusted_device.dart';
import 'package:localsend_app/provider/chat_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/server/server_utils.dart';
import 'package:localsend_app/util/simple_server.dart';
import 'package:routerino/routerino.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ChatController {
  final ServerUtils server;

  ChatController(this.server);

  void installRoutes({
    required SimpleServerRouteBuilder router,
    required String fingerprint,
  }) {
    router.post(ApiRoute.chatRequest.v2, (HttpRequest request) async {
      return await _chatRequestHandler(request: request, fingerprint: fingerprint);
    });

    router.post(ApiRoute.chatMessage.v2, (HttpRequest request) async {
      return await _chatMessageHandler(request: request, fingerprint: fingerprint);
    });
  }

  Future<void> _chatRequestHandler({
    required HttpRequest request,
    required String fingerprint,
  }) async {
    final ChatRequestDto payload;
    try {
      payload = ChatRequestDto.fromMap(jsonDecode(await request.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return await request.respondJson(400, message: 'Request body malformed');
    }

    final sender = payload.sender;
    if (sender.fingerprint == fingerprint) {
      return await request.respondJson(412, message: 'Self-discovered');
    }

    await server.ref.redux(nearbyDevicesProvider).dispatchAsync(RegisterDeviceAction(sender.toDevice(request.ip)));

    var trusted = server.ref.read(chatProvider).trustedDevices.firstWhereOrNull((device) => device.fingerprint == sender.fingerprint);
    if (trusted == null) {
      final accepted = await _showChatRequestDialog(sender.alias, payload.text);
      if (accepted != true) {
        return await request.respondJson(403, message: 'Chat request declined by recipient');
      }

      final now = DateTime.now().toUtc();
      trusted = ChatTrustedDevice(
        fingerprint: sender.fingerprint,
        alias: sender.alias,
        token: _uuid.v4(),
        lastIp: request.ip,
        lastPort: sender.port,
        https: sender.protocol == ProtocolType.https,
        trustedAt: now,
        updatedAt: now,
      );
      await server.ref.redux(chatProvider).dispatchAsync(TrustChatDeviceAction(trusted));
    } else {
      trusted = _updatedTrustedDevice(trusted, sender, request.ip);
      await server.ref.redux(chatProvider).dispatchAsync(TrustChatDeviceAction(trusted));
    }

    await server.ref
        .redux(chatProvider)
        .dispatchAsync(
          AddIncomingChatMessageAction(
            peer: sender,
            messageId: payload.messageId,
            text: payload.text,
            timestamp: payload.timestamp,
            ip: request.ip,
          ),
        );

    return await request.respondJson(
      200,
      body: ChatRequestResponseDto(chatToken: trusted.token).toJson(),
    );
  }

  Future<void> _chatMessageHandler({
    required HttpRequest request,
    required String fingerprint,
  }) async {
    final ChatMessageDto payload;
    try {
      payload = ChatMessageDto.fromMap(jsonDecode(await request.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return await request.respondJson(400, message: 'Request body malformed');
    }

    final sender = payload.sender;
    if (sender.fingerprint == fingerprint) {
      return await request.respondJson(412, message: 'Self-discovered');
    }

    final trusted = server.ref.read(chatProvider).trustedDevices.firstWhereOrNull((device) => device.fingerprint == sender.fingerprint);
    if (trusted == null || trusted.token != payload.chatToken) {
      return await request.respondJson(401, message: 'Invalid chat token');
    }

    await server.ref.redux(nearbyDevicesProvider).dispatchAsync(RegisterDeviceAction(sender.toDevice(request.ip)));
    await server.ref.redux(chatProvider).dispatchAsync(TrustChatDeviceAction(_updatedTrustedDevice(trusted, sender, request.ip)));
    await server.ref
        .redux(chatProvider)
        .dispatchAsync(
          AddIncomingChatMessageAction(
            peer: sender,
            messageId: payload.messageId,
            text: payload.text,
            timestamp: payload.timestamp,
            ip: request.ip,
          ),
        );

    return await request.respondJson(200);
  }

  Future<bool?> _showChatRequestDialog(String alias, String preview) async {
    return await showDialog<bool>(
      context: Routerino.context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Allow chat?'),
          content: Text('$alias wants to send you chat messages.\n\n$preview'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }
}

ChatTrustedDevice _updatedTrustedDevice(ChatTrustedDevice trusted, ChatPeerDto sender, String ip) {
  return trusted.copyWith(
    alias: sender.alias,
    lastIp: ip,
    lastPort: sender.port,
    https: sender.protocol == ProtocolType.https,
    updatedAt: DateTime.now().toUtc(),
  );
}
