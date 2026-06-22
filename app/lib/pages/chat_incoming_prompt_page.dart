import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

class ChatIncomingPromptPage extends StatelessWidget {
  final String alias;

  const ChatIncomingPromptPage({
    super.key,
    required this.alias,
  });

  @override
  Widget build(BuildContext context) {
    final smallUi = MediaQuery.of(context).size.height < 600;
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: smallUi ? 20 : 30),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!smallUi) ...[
                            const Icon(Icons.chat_bubble_outline, size: 64),
                            const SizedBox(height: 16),
                          ],
                          FittedBox(
                            child: Text(
                              alias,
                              style: TextStyle(fontSize: smallUi ? 32 : 48),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            '$alias \u7ed9\u4f60\u53d1\u9001\u4e86\u4e00\u6761\u65b0\u6d88\u606f\u3002\u662f\u5426\u67e5\u770b\uff1f',
                            style: smallUi ? null : Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: () => context.pop(false),
                          icon: const Icon(Icons.close),
                          label: const Text('Later'),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () => context.pop(true),
                          icon: const Icon(Icons.chat),
                          label: const Text('View'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
