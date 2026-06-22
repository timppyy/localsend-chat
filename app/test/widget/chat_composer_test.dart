import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/pages/tabs/chat_composer.dart';

void main() {
  testWidgets('sends with Ctrl+Enter', (tester) async {
    var sendCount = 0;
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            attachments: const [],
            onAttach: () async {},
            onPasteFromClipboard: () async {},
            onSend: () async {
              sendCount++;
            },
            onRemoveAttachment: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(sendCount, 1);
  });

  testWidgets('pastes clipboard content with Ctrl+V', (tester) async {
    var pasteCount = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            attachments: const [],
            onAttach: () async {},
            onPasteFromClipboard: () async {
              pasteCount++;
            },
            onSend: () async {},
            onRemoveAttachment: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(pasteCount, 1);
  });
}
