// Widget tests for DismissKeyboardOnTap: replaces the floating "Done" bar
// with an invisible gesture. A tap that lands on empty space drops focus
// (closing the on-screen keyboard); a tap that lands on an interactive
// descendant (a button) must still reach that descendant on the first
// touch, never absorbed by this ancestor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/dismiss_keyboard_on_tap.dart';

void main() {
  group('DismissKeyboardOnTap, tap outside drops focus', () {
    testWidgets('tapping empty space unfocuses the field', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: DismissKeyboardOnTap(
            child: Scaffold(
              body: Column(
                children: [
                  TextField(focusNode: focusNode),
                  const SizedBox(
                    height: 400,
                    child: ColoredBox(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap the empty space below the field, not the field itself.
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    });
  });

  group('DismissKeyboardOnTap, does not swallow a button underneath', () {
    testWidgets(
      'a button placed under the gesture stays clickable on the first tap',
      (tester) async {
        var pressed = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: DismissKeyboardOnTap(
              child: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => pressed++,
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();

        expect(pressed, 1);
      },
    );

    testWidgets('tapping the button does not also fire the outer unfocus on an '
        'unrelated field', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var pressed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DismissKeyboardOnTap(
            child: Scaffold(
              body: Column(
                children: [
                  TextField(focusNode: focusNode),
                  ElevatedButton(
                    onPressed: () => pressed++,
                    child: const Text('go'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(pressed, 1, reason: 'the button must still fire on first tap');
    });
  });
}
