import 'package:collection/collection.dart';
import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/provider/chat_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:refena_flutter/refena_flutter.dart';

class ChatTabVm {
  final List<ChatConversation> conversations;
  final List<Device> nearbyDevices;
  final String? selectedFingerprint;
  final Device? selectedDevice;
  final ChatConversation? selectedConversation;
  final List<ChatMessage> messages;
  final void Function(String fingerprint) onSelectConversation;
  final Future<void> Function(String text) onSendText;
  final Future<void> Function(BuildContext context) onSendFiles;

  const ChatTabVm({
    required this.conversations,
    required this.nearbyDevices,
    required this.selectedFingerprint,
    required this.selectedDevice,
    required this.selectedConversation,
    required this.messages,
    required this.onSelectConversation,
    required this.onSendText,
    required this.onSendFiles,
  });
}

final chatTabVmProvider = ViewProvider((ref) {
  final chat = ref.watch(chatProvider);
  final devices = _uniqueDevices(ref.watch(nearbyDevicesProvider).allDevices.values);
  final selectedFingerprint = chat.selectedFingerprint ?? chat.conversations.firstOrNull?.peerFingerprint ?? devices.firstOrNull?.fingerprint;
  final selectedDevice = selectedFingerprint == null ? null : devices.firstWhereOrNull((device) => device.fingerprint == selectedFingerprint);
  final selectedConversation = selectedFingerprint == null
      ? null
      : chat.conversations.firstWhereOrNull((conversation) => conversation.peerFingerprint == selectedFingerprint);
  final selectedTarget = selectedDevice ?? (selectedConversation == null ? null : _conversationToDevice(selectedConversation));
  final messages = selectedFingerprint == null
      ? <ChatMessage>[]
      : (chat.messages.where((message) => message.peerFingerprint == selectedFingerprint).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp)));

  return ChatTabVm(
    conversations: chat.conversations,
    nearbyDevices: devices,
    selectedFingerprint: selectedFingerprint,
    selectedDevice: selectedTarget,
    selectedConversation: selectedConversation,
    messages: messages,
    onSelectConversation: (fingerprint) {
      ref.redux(chatProvider).dispatch(SelectConversationAction(fingerprint));
    },
    onSendText: (text) async {
      if (selectedFingerprint == null) {
        return;
      }
      await ref
          .redux(chatProvider)
          .dispatchAsync(
            SendTextMessageAction(
              peerFingerprint: selectedFingerprint,
              text: text,
            ),
          );
    },
    onSendFiles: (context) async {
      if (selectedFingerprint == null) {
        return;
      }
      final target = selectedTarget;
      final previousSelection = List.of(ref.read(selectedSendingFilesProvider));
      ref.redux(selectedSendingFilesProvider).dispatch(SetSelectionAction(const []));
      try {
        await _pickChatAttachment(context, ref);
        final files = ref.read(selectedSendingFilesProvider);
        if (files.isEmpty) {
          return;
        }
        Object? sendError;
        if (target != null) {
          try {
            await ref.notifier(sendProvider).startSession(
                  target: target,
                  files: files,
                  background: false,
                );
          } catch (e) {
            sendError = e;
          }
        }
        for (final file in files) {
          await ref
              .redux(chatProvider)
              .dispatchAsync(
                AddOutgoingFileMessageAction(
                  peerFingerprint: selectedFingerprint,
                  fileName: file.name,
                  fileSize: file.size,
                  filePath: file.path,
                  errorMessage: sendError?.toString(),
                ),
              );
        }
      } finally {
        ref.redux(selectedSendingFilesProvider).dispatch(SetSelectionAction(previousSelection));
      }
    },
  );
});

Future<void> _pickChatAttachment(BuildContext context, Ref ref) async {
  final options = FilePickerOption.getOptionsForPlatform();
  final option = await showDialog<FilePickerOption>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Attach'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in options)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(option),
                icon: Icon(option.icon),
                label: Text(option.label),
              ),
          ],
        ),
      );
    },
  );
  if (option == null || !context.mounted) {
    return;
  }

  await ref.global.dispatchAsync(PickFileAction(option: option, context: context));
}

List<Device> _uniqueDevices(Iterable<Device> devices) {
  final byFingerprint = <String, Device>{};
  for (final device in devices) {
    if (device.fingerprint.isEmpty) {
      continue;
    }
    byFingerprint[device.fingerprint] = device;
  }
  return byFingerprint.values.toList()..sort((a, b) => a.alias.compareTo(b.alias));
}

Device? _conversationToDevice(ChatConversation conversation) {
  final ip = conversation.lastIp;
  final port = conversation.lastPort;
  if (ip == null || port == null) {
    return null;
  }
  return Device(
    signalingId: null,
    ip: ip,
    version: protocolVersion,
    port: port,
    https: conversation.https ?? true,
    fingerprint: conversation.peerFingerprint,
    alias: conversation.alias,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: {HttpDiscovery(ip: ip)},
  );
}
