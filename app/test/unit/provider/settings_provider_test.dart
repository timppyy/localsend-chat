import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/chat_notification_mode.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:test/test.dart';

import '../../mocks.mocks.dart';

void main() {
  late MockPersistenceService persistenceService;

  setUp(() {
    persistenceService = MockPersistenceService();
    when(persistenceService.getShowToken()).thenReturn('token');
    when(persistenceService.getAlias()).thenReturn('Me');
    when(persistenceService.getTheme()).thenReturn(ThemeMode.system);
    when(persistenceService.getColorMode()).thenReturn(ColorMode.localsend);
    when(persistenceService.getLocale()).thenReturn(null);
    when(persistenceService.getPort()).thenReturn(53317);
    when(persistenceService.getNetworkWhitelist()).thenReturn(null);
    when(persistenceService.getNetworkBlacklist()).thenReturn(null);
    when(persistenceService.getMulticastGroup()).thenReturn('224.0.0.167');
    when(persistenceService.getDestination()).thenReturn(null);
    when(persistenceService.isSaveToGallery()).thenReturn(true);
    when(persistenceService.isSaveToHistory()).thenReturn(true);
    when(persistenceService.isQuickSave()).thenReturn(false);
    when(persistenceService.isQuickSaveFromFavorites()).thenReturn(false);
    when(persistenceService.getReceivePin()).thenReturn(null);
    when(persistenceService.isAutoFinish()).thenReturn(false);
    when(persistenceService.isMinimizeToTray()).thenReturn(true);
    when(persistenceService.isHttps()).thenReturn(true);
    when(persistenceService.getSendMode()).thenReturn(SendMode.single);
    when(persistenceService.getSaveWindowPlacement()).thenReturn(true);
    when(persistenceService.getEnableAnimations()).thenReturn(true);
    when(persistenceService.getDeviceType()).thenReturn(DeviceType.desktop);
    when(persistenceService.getDeviceModel()).thenReturn(null);
    when(persistenceService.getShareViaLinkAutoAccept()).thenReturn(false);
    when(persistenceService.getDiscoveryTimeout()).thenReturn(2000);
    when(persistenceService.getAdvancedSettingsEnabled()).thenReturn(false);
    when(persistenceService.getChatNotificationMode()).thenReturn(ChatNotificationMode.dialog);
  });

  test('defaults settings to the chat desktop profile and persists notification mode changes', () async {
    final service = Notifier.test(
      notifier: SettingsService(persistenceService),
    );

    expect(service.state.minimizeToTray, true);
    expect(service.state.enableAnimations, true);
    expect(service.state.chatNotificationMode, ChatNotificationMode.dialog);

    await service.notifier.setChatNotificationMode(ChatNotificationMode.system);

    expect(service.state.chatNotificationMode, ChatNotificationMode.system);
    verify(persistenceService.setChatNotificationMode(ChatNotificationMode.system));
  });
}
