import 'dart:async';
import 'dart:io';

import 'package:common/model/file_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/file_type_ext.dart';

class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final List<CrossFile> attachments;
  final Future<void> Function() onAttach;
  final Future<void> Function() onPasteFromClipboard;
  final Future<void> Function() onSend;
  final void Function(int index) onRemoveAttachment;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.attachments,
    required this.onAttach,
    required this.onPasteFromClipboard,
    required this.onSend,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSend = value.text.trim().isNotEmpty || attachments.isNotEmpty;
        return CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.enter, control: true): () {
              if (canSend) {
                unawaited(onSend());
              }
            },
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachments.isNotEmpty) ...[
                  _AttachmentDraftStrip(
                    attachments: attachments,
                    onRemoveAttachment: onRemoveAttachment,
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Attach file',
                      onPressed: () async {
                        await onAttach();
                      },
                      icon: const Icon(Icons.attach_file),
                    ),
                    IconButton(
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        await onPasteFromClipboard();
                      },
                      icon: const Icon(Icons.content_paste),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: canSend
                          ? () async {
                              await onSend();
                            }
                          : null,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttachmentDraftStrip extends StatelessWidget {
  final List<CrossFile> attachments;
  final void Function(int index) onRemoveAttachment;

  const _AttachmentDraftStrip({
    required this.attachments,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _AttachmentDraftCard(
            file: attachments[index],
            onRemove: () => onRemoveAttachment(index),
          );
        },
      ),
    );
  }
}

class _AttachmentDraftCard extends StatelessWidget {
  final CrossFile file;
  final VoidCallback onRemove;

  const _AttachmentDraftCard({
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _AttachmentDraftPreview(file: file),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      file.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.size.asReadableFileSize,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentDraftPreview extends StatelessWidget {
  final CrossFile file;

  const _AttachmentDraftPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    final thumbnail = file.thumbnail;
    final path = file.path;
    if (file.fileType == FileType.image && thumbnail != null) {
      return _PreviewFrame(
        child: Image.memory(thumbnail, fit: BoxFit.cover),
      );
    }
    if (file.fileType == FileType.image && path != null && !path.startsWith('content://') && File(path).existsSync()) {
      return _PreviewFrame(
        child: Image.file(File(path), fit: BoxFit.cover),
      );
    }

    return _PreviewFrame(
      child: Icon(file.fileType.icon, size: 28),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  final Widget child;

  const _PreviewFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 56,
        height: 56,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(child: child),
        ),
      ),
    );
  }
}
