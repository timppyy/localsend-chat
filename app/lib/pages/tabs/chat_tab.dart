import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/pages/tabs/chat_composer.dart';
import 'package:localsend_app/pages/tabs/chat_tab_vm.dart';
import 'package:localsend_app/util/chat_attachment_helper.dart';
import 'package:localsend_app/util/chat_clipboard_helper.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/file_type_ext.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';

class ChatTab extends StatefulWidget {
  const ChatTab();

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _controller = TextEditingController();
  final _draftAttachments = <CrossFile>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => chatTabVmProvider,
      builder: (context, vm) {
        return ResponsiveBuilder(
          builder: (sizing) {
            if (sizing.isMobile) {
              return _ChatDetail(
                vm: vm,
                controller: _controller,
                draftAttachments: _draftAttachments,
                onAddAttachments: _addDraftAttachments,
                onRemoveAttachment: _removeDraftAttachment,
                onClearAttachments: _clearDraftAttachments,
              );
            }

            return Row(
              children: [
                SizedBox(
                  width: 320,
                  child: _ConversationPane(vm: vm),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _ChatDetail(
                    vm: vm,
                    controller: _controller,
                    draftAttachments: _draftAttachments,
                    onAddAttachments: _addDraftAttachments,
                    onRemoveAttachment: _removeDraftAttachment,
                    onClearAttachments: _clearDraftAttachments,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addDraftAttachments(List<CrossFile> files) {
    if (files.isEmpty) {
      return;
    }
    setState(() {
      _draftAttachments.addAll(files);
    });
  }

  void _removeDraftAttachment(int index) {
    if (index < 0 || index >= _draftAttachments.length) {
      return;
    }
    setState(() {
      _draftAttachments.removeAt(index);
    });
  }

  void _clearDraftAttachments() {
    if (_draftAttachments.isEmpty) {
      return;
    }
    setState(_draftAttachments.clear);
  }
}

class _ConversationPane extends StatelessWidget {
  final ChatTabVm vm;

  const _ConversationPane({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Chats', style: Theme.of(context).textTheme.titleLarge),
          ),
          if (vm.conversations.isEmpty && vm.nearbyDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No nearby devices yet.'),
            ),
          ...vm.conversations.map((conversation) {
            return _ConversationTile(
              selected: vm.selectedFingerprint == conversation.peerFingerprint,
              title: conversation.alias,
              subtitle: conversation.lastMessage ?? 'No messages yet',
              onTap: () => vm.onSelectConversation(conversation.peerFingerprint),
            );
          }),
          if (vm.nearbyDevices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Nearby devices'),
            ),
            ...vm.nearbyDevices.where((device) => vm.conversations.every((conversation) => conversation.peerFingerprint != device.fingerprint)).map((
              device,
            ) {
              return _ConversationTile(
                selected: vm.selectedFingerprint == device.fingerprint,
                title: device.alias,
                subtitle: device.ip == null ? 'Offline' : 'Online · ${device.ip}',
                onTap: () => vm.onSelectConversation(device.fingerprint),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _ChatDetail extends StatelessWidget {
  final ChatTabVm vm;
  final TextEditingController controller;
  final List<CrossFile> draftAttachments;
  final void Function(List<CrossFile> files) onAddAttachments;
  final void Function(int index) onRemoveAttachment;
  final VoidCallback onClearAttachments;

  const _ChatDetail({
    required this.vm,
    required this.controller,
    required this.draftAttachments,
    required this.onAddAttachments,
    required this.onRemoveAttachment,
    required this.onClearAttachments,
  });

  @override
  Widget build(BuildContext context) {
    final title = _title(vm.selectedConversation, vm.selectedDevice);
    if (vm.selectedFingerprint == null) {
      return const Center(child: Text('Select a device to start chatting.'));
    }

    return Column(
      children: [
        _ChatHeader(
          title: title,
          device: vm.selectedDevice,
          onClearConversation: () async {
            final fingerprint = vm.selectedFingerprint;
            if (fingerprint == null) {
              return;
            }
            final confirmed = await _confirmClearConversation(context, title);
            if (confirmed == true) {
              await vm.onClearConversation(fingerprint);
            }
          },
        ),
        Expanded(
          child: vm.messages.isEmpty
              ? const Center(child: Text('No messages yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: vm.messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(
                      message: vm.messages[index],
                      onDelete: vm.onDeleteMessage,
                    );
                  },
                ),
        ),
        ChatComposer(
          controller: controller,
          attachments: draftAttachments,
          onAttach: () async {
            final files = await vm.onPickFiles(context);
            onAddAttachments(files);
          },
          onPasteFromClipboard: () async {
            final payload = await vm.onPasteFromClipboard();
            if (!context.mounted) {
              return;
            }
            _applyClipboardPayload(context, payload);
          },
          onSend: () async {
            final text = controller.text;
            final files = List<CrossFile>.of(draftAttachments);
            if (text.trim().isEmpty && files.isEmpty) {
              return;
            }
            controller.clear();
            onClearAttachments();
            await vm.onSendText(text);
            await vm.onSendFiles(files);
          },
          onRemoveAttachment: onRemoveAttachment,
        ),
      ],
    );
  }

  String _title(ChatConversation? conversation, Device? device) {
    return conversation?.alias ?? device?.alias ?? 'Chat';
  }

  void _applyClipboardPayload(BuildContext context, ChatClipboardPayload payload) {
    if (payload.files.isNotEmpty) {
      onAddAttachments(payload.files);
    }

    final text = payload.text;
    if (text != null && text.isNotEmpty) {
      final value = controller.value;
      final selection = value.selection;
      final start = selection.isValid ? selection.start.clamp(0, value.text.length).toInt() : value.text.length;
      final end = selection.isValid ? selection.end.clamp(0, value.text.length).toInt() : value.text.length;
      final replaceStart = start < end ? start : end;
      final replaceEnd = start < end ? end : start;
      final nextText = value.text.replaceRange(replaceStart, replaceEnd, text);
      controller.value = value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: replaceStart + text.length),
        composing: TextRange.empty,
      );
    }

    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No supported clipboard content.')),
      );
    }
  }
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final Device? device;
  final Future<void> Function() onClearConversation;

  const _ChatHeader({
    required this.title,
    required this.device,
    required this.onClearConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  device?.ip == null ? 'Offline' : 'Online · ${device!.ip}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear chat history',
            onPressed: () async {
              await onClearConversation();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmClearConversation(BuildContext context, String title) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Clear chat history?'),
        content: Text('Clear local chat history with $title? This will not delete anything on the other device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      );
    },
  );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(String messageId) onDelete;

  const _MessageBubble({
    required this.message,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final outgoing = message.direction == ChatMessageDirection.outgoing;
    final color = outgoing ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = outgoing ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DefaultTextStyle(
            style: TextStyle(color: textColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.kind == ChatMessageKind.file)
                  _AttachmentBubbleContent(
                    message: message,
                    textColor: textColor,
                    onDelete: onDelete,
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          _messageContent(message),
                          style: TextStyle(color: textColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _MessageActionMenu(
                        message: message,
                        onDelete: onDelete,
                      ),
                    ],
                  ),
                if (message.status == ChatMessageStatus.failed || message.status == ChatMessageStatus.declined)
                  SelectableText(
                    message.errorMessage ?? message.status.name,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _MessageAction {
  copy,
  open,
  showInFolder,
  delete,
}

class _MessageActionMenu extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(String messageId) onDelete;

  const _MessageActionMenu({
    required this.message,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MessageAction>(
      tooltip: 'Message actions',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) async {
        switch (action) {
          case _MessageAction.copy:
            await Clipboard.setData(ClipboardData(text: _messageContent(message)));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            }
          case _MessageAction.open:
            await _openAttachment(context, message);
          case _MessageAction.showInFolder:
            await _showAttachmentInFolder(context, message);
          case _MessageAction.delete:
            await onDelete(message.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message deleted')),
              );
            }
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: _MessageAction.copy,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.copy),
              title: Text('Copy'),
            ),
          ),
          if (message.kind == ChatMessageKind.file)
            const PopupMenuItem(
              value: _MessageAction.open,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.open_in_new),
                title: Text('Open'),
              ),
            ),
          if (message.kind == ChatMessageKind.file && _canShowInFolder(message))
            const PopupMenuItem(
              value: _MessageAction.showInFolder,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.folder_open),
                title: Text('Show in folder'),
              ),
            ),
          const PopupMenuItem(
            value: _MessageAction.delete,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline),
              title: Text('Delete'),
            ),
          ),
        ];
      },
    );
  }
}

class _AttachmentBubbleContent extends StatelessWidget {
  final ChatMessage message;
  final Color textColor;
  final Future<void> Function(String messageId) onDelete;

  const _AttachmentBubbleContent({
    required this.message,
    required this.textColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final canPreview = _hasPreviewableLocalImage(message);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canPreview ? null : () async => await _openAttachment(context, message),
      onDoubleTap: () async {
        if (canPreview) {
          await _showImagePreview(context, message);
        } else {
          await _openAttachment(context, message);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPreview) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(message.filePath!),
                width: 360,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _FileAttachmentRow(
                    message: message,
                    textColor: textColor,
                    onDelete: onDelete,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    chatAttachmentName(message),
                    style: TextStyle(color: textColor),
                  ),
                ),
                const SizedBox(width: 6),
                _MessageActionMenu(
                  message: message,
                  onDelete: onDelete,
                ),
              ],
            ),
            if (message.fileSize != null)
              Text(
                message.fileSize!.asReadableFileSize,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.78)),
              ),
          ] else
            _FileAttachmentRow(
              message: message,
              textColor: textColor,
              onDelete: onDelete,
            ),
        ],
      ),
    );
  }
}

class _FileAttachmentRow extends StatelessWidget {
  final ChatMessage message;
  final Color textColor;
  final Future<void> Function(String messageId) onDelete;

  const _FileAttachmentRow({
    required this.message,
    required this.textColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fileType = chatAttachmentType(message);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(fileType.icon, color: textColor, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                chatAttachmentName(message),
                style: TextStyle(color: textColor),
              ),
              if (message.fileSize != null)
                Text(
                  message.fileSize!.asReadableFileSize,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.78)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _MessageActionMenu(
          message: message,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

String _messageContent(ChatMessage message) {
  if (message.kind == ChatMessageKind.file) {
    return chatAttachmentName(message);
  }
  return message.text ?? '';
}

bool _hasPreviewableLocalImage(ChatMessage message) {
  final filePath = message.filePath;
  return canPreviewChatImage(message) && filePath != null && !filePath.startsWith('content://') && File(filePath).existsSync();
}

bool _canShowInFolder(ChatMessage message) {
  final filePath = message.filePath;
  return filePath != null && !filePath.startsWith('content://') && filePath.trim().isNotEmpty;
}

Future<void> _openAttachment(BuildContext context, ChatMessage message) async {
  final filePath = message.filePath;
  if (filePath == null || filePath.trim().isEmpty) {
    _showAttachmentSnackBar(context, 'File path is not available.');
    return;
  }
  if (!filePath.startsWith('content://') && !File(filePath).existsSync()) {
    _showAttachmentSnackBar(context, 'File not found.');
    return;
  }

  await openFile(context, chatAttachmentType(message), filePath);
}

Future<void> _showAttachmentInFolder(BuildContext context, ChatMessage message) async {
  final filePath = message.filePath;
  if (filePath == null || filePath.trim().isEmpty) {
    _showAttachmentSnackBar(context, 'File path is not available.');
    return;
  }
  final file = File(filePath);
  if (!file.existsSync()) {
    _showAttachmentSnackBar(context, 'File not found.');
    return;
  }

  await openFolder(
    folderPath: file.parent.path,
    fileName: path.basename(filePath),
  );
}

Future<void> _showImagePreview(BuildContext context, ChatMessage message) async {
  final filePath = message.filePath;
  if (filePath == null || !File(filePath).existsSync()) {
    _showAttachmentSnackBar(context, 'File not found.');
    return;
  }

  await showDialog(
    context: context,
    builder: (context) {
      final size = MediaQuery.of(context).size;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size.width * 0.86,
          height: size.height * 0.86,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 5,
                    child: Center(
                      child: Image.file(
                        File(filePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showAttachmentSnackBar(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
