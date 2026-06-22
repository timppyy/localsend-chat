import 'dart:async';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/chat_notification_mode.dart';
import 'package:localsend_app/pages/chat_incoming_prompt_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/chat_tab.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/provider/chat_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/chat_incoming_notification_tracker.dart';
import 'package:localsend_app/util/chat_system_notification_service.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/tray_helper.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:window_manager/window_manager.dart';

enum HomeTab {
  receive(Icons.wifi),
  chat(Icons.chat),
  send(Icons.send),
  settings(Icons.settings);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.chat:
        return 'Chat';
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener, Refena {
  bool _dragAndDropIndicator = false;
  final _chatNotificationTracker = ChatIncomingNotificationTracker();
  late final ChatSystemNotificationService _chatSystemNotificationService;
  bool _chatNotificationVisible = false;
  bool _isChatWindowForeground = true;

  @override
  void initState() {
    super.initState();
    _chatSystemNotificationService = ChatSystemNotificationService(
      onSelected: _openChatConversation,
    );
    if (checkPlatformIsDesktop()) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshChatWindowForeground());
      });
    }

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  void dispose() {
    if (checkPlatformIsDesktop()) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);
    final chatState = context.watch(chatProvider);
    final notificationMode = context.watch(settingsProvider.select((settings) => settings.chatNotificationMode));
    _scheduleIncomingChatNotification(
      context,
      event: _chatNotificationTracker.nextEvent(
        chatState,
        isViewingChat: vm.currentTab == HomeTab.chat,
        isAppForeground: _isChatWindowForeground,
      ),
      mode: notificationMode,
    );

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        if (event.files.length == 1 && Directory(event.files.first.path).existsSync()) {
          // user dropped a directory
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(event.files.first.path));
        } else {
          // user dropped one or more files
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: event.files,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.send);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          return Scaffold(
            body: Row(
              children: [
                if (!sizingInformation.isMobile)
                  Stack(
                    children: [
                      NavigationRail(
                        selectedIndex: vm.currentTab.index,
                        onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                        extended: sizingInformation.isDesktop,
                        backgroundColor: Theme.of(context).cardColorWithElevation,
                        leading: sizingInformation.isDesktop
                            ? Column(
                                children: [
                                  checkPlatform([TargetPlatform.macOS])
                                      ? // considered adding some extra space so it looks more natural
                                        SizedBox(height: 40)
                                      : SizedBox(height: 20),
                                  const Text(
                                    'LocalSend',
                                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 20),
                                ],
                              )
                            : checkPlatform([TargetPlatform.macOS])
                            ? SizedBox(
                                height: 20,
                              )
                            : null,
                        destinations: HomeTab.values.map((tab) {
                          return NavigationRailDestination(
                            icon: Icon(tab.icon),
                            label: Text(tab.label),
                          );
                        }).toList(),
                      ),
                      // makes the top draggable
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: MoveWindow(),
                      ),
                    ],
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      PageView(
                        controller: vm.controller,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          SafeArea(child: ReceiveTab()),
                          SafeArea(child: ChatTab()),
                          SafeArea(child: SendTab()),
                          SettingsTab(),
                        ],
                      ),
                      if (_dragAndDropIndicator)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.file_download, size: 128),
                              const SizedBox(height: 30),
                              Text(t.sendTab.placeItems, style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: sizingInformation.isMobile
                ? NavigationBar(
                    selectedIndex: vm.currentTab.index,
                    onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                    destinations: HomeTab.values.map((tab) {
                      return NavigationDestination(icon: Icon(tab.icon), label: tab.label);
                    }).toList(),
                  )
                : null,
          );
        },
      ),
    );
  }

  void _scheduleIncomingChatNotification(
    BuildContext context, {
    required ChatIncomingNotificationEvent? event,
    required ChatNotificationMode mode,
  }) {
    if (event == null || _chatNotificationVisible) {
      return;
    }

    _chatNotificationVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!context.mounted) {
          return;
        }
        if (mode == ChatNotificationMode.system) {
          final shown = await _chatSystemNotificationService.showNewMessage(
            peerFingerprint: event.message.peerFingerprint,
            alias: event.alias,
          );
          if (shown) {
            return;
          }
        }
        if (!context.mounted) {
          return;
        }

        await _showChatPopupFromBackground();
        if (!context.mounted) {
          return;
        }
        final bool? view = await Routerino.context.push(
          () => ChatIncomingPromptPage(alias: event.alias),
        );
        if (view == true) {
          await _openChatConversation(event.message.peerFingerprint);
        }
      } finally {
        _chatNotificationVisible = false;
      }
    });
  }

  Future<void> _openChatConversation(String peerFingerprint) async {
    await showFromTray();
    ref.redux(chatProvider).dispatch(SelectConversationAction(peerFingerprint));
    ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.chat));
  }

  Future<void> _showChatPopupFromBackground() async {
    if (!checkPlatformHasTray()) {
      return;
    }

    if (await windowManager.isMinimized() || !(await windowManager.isVisible()) || !(await windowManager.isFocused())) {
      await showFromTray();
    }
  }

  @override
  void onWindowFocus() {
    _setChatWindowForeground(true);
  }

  @override
  void onWindowBlur() {
    _setChatWindowForeground(false);
  }

  @override
  void onWindowMinimize() {
    _setChatWindowForeground(false);
  }

  @override
  void onWindowRestore() {
    unawaited(_refreshChatWindowForeground());
  }

  Future<void> _refreshChatWindowForeground() async {
    if (!checkPlatformIsDesktop()) {
      return;
    }
    final isForeground = !(await windowManager.isMinimized()) && await windowManager.isVisible() && await windowManager.isFocused();
    _setChatWindowForeground(isForeground);
  }

  void _setChatWindowForeground(bool isForeground) {
    if (!mounted || _isChatWindowForeground == isForeground) {
      return;
    }
    setState(() {
      _isChatWindowForeground = isForeground;
    });
  }
}
