import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/persistence/chat_conversation.dart';
import 'package:localsend_app/model/persistence/chat_message.dart';
import 'package:localsend_app/pages/tabs/chat_tab_vm.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';

class ChatTab extends StatefulWidget {
  const ChatTab();

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _controller = TextEditingController();

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
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
            ...vm.nearbyDevices
                .where((device) => vm.conversations.every((conversation) => conversation.peerFingerprint != device.fingerprint))
                .map((device) {
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

  const _ChatDetail({
    required this.vm,
    required this.controller,
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
        ),
        Expanded(
          child: vm.messages.isEmpty
              ? const Center(child: Text('No messages yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: vm.messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(message: vm.messages[index]);
                  },
                ),
        ),
        _Composer(
          controller: controller,
          onAttach: () async => await vm.onSendFiles(context),
          onSend: () async {
            final text = controller.text;
            controller.clear();
            await vm.onSendText(text);
          },
        ),
      ],
    );
  }

  String _title(ChatConversation? conversation, Device? device) {
    return conversation?.alias ?? device?.alias ?? 'Chat';
  }
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final Device? device;

  const _ChatHeader({
    required this.title,
    required this.device,
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
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

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
                Text(message.kind == ChatMessageKind.file ? message.fileName ?? 'File' : message.text ?? ''),
                if (message.kind == ChatMessageKind.file && message.fileSize != null)
                  Text('${message.fileSize} bytes', style: Theme.of(context).textTheme.bodySmall),
                if (message.status == ChatMessageStatus.failed || message.status == ChatMessageStatus.declined)
                  Text(message.errorMessage ?? message.status.name, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() onAttach;
  final Future<void> Function() onSend;

  const _Composer({
    required this.controller,
    required this.onAttach,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attach file',
            onPressed: () async {
              await onAttach();
            },
            icon: const Icon(Icons.attach_file),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) async {
                await onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: () async {
              await onSend();
            },
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
