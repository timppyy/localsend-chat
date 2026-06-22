import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:localsend_app/gen/assets.gen.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ChatSystemNotification');

typedef ChatNotificationSelected = void Function(String peerFingerprint);

class ChatSystemNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final ChatNotificationSelected _onSelected;
  bool _initialized = false;

  ChatSystemNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    required ChatNotificationSelected onSelected,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _onSelected = onSelected;

  Future<bool> showNewMessage({
    required String peerFingerprint,
    required String alias,
  }) async {
    if (!checkPlatform([TargetPlatform.windows])) {
      return false;
    }

    final initialized = await _ensureInitialized();
    if (!initialized) {
      return false;
    }

    try {
      await _plugin.show(
        id: peerFingerprint.hashCode & 0x7fffffff,
        title: 'LocalSend Chat',
        body: '$alias \u7ed9\u4f60\u53d1\u9001\u4e86\u4e00\u6761\u65b0\u6d88\u606f\u3002\u662f\u5426\u67e5\u770b\uff1f',
        notificationDetails: const NotificationDetails(
          windows: WindowsNotificationDetails(
            duration: WindowsNotificationDuration.short,
            actions: [
              WindowsAction(
                content: 'View',
                arguments: 'view',
              ),
            ],
          ),
        ),
        payload: peerFingerprint,
      );
      return true;
    } catch (e, stackTrace) {
      _logger.warning('Failed to show chat system notification', e, stackTrace);
      return false;
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) {
      return true;
    }

    try {
      final result = await _plugin.initialize(
        settings: InitializationSettings(
          windows: WindowsInitializationSettings(
            appName: 'LocalSend Chat',
            appUserModelId: 'org.localsend.localsendChat',
            guid: '64C60A36-6777-4FE3-9C31-4B2D79D7F1D0',
            iconPath: Assets.img.logo,
          ),
        ),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      _initialized = result == true;
      return _initialized;
    } catch (e, stackTrace) {
      _logger.warning('Failed to initialize chat system notifications', e, stackTrace);
      return false;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final peerFingerprint = response.payload;
    if (peerFingerprint == null || peerFingerprint.isEmpty) {
      return;
    }
    scheduleMicrotask(() => _onSelected(peerFingerprint));
  }
}
