// Proves the other half of the invisible-dismiss pair: dragging a
// scrollable view that carries `ScrollViewKeyboardDismissBehavior.onDrag`
// closes the on-screen keyboard, the same way every production form
// wrapped by this behavior does (sign_in_page, service_form_page, etc).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'dragging a ListView with keyboardDismissBehavior.onDrag unfocuses the field above it',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: List.generate(
                      40,
                      (i) => ListTile(title: Text('item $i')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    },
  );

  testWidgets(
    'without keyboardDismissBehavior, dragging the same ListView leaves the field focused',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                Expanded(
                  child: ListView(
                    children: List.generate(
                      40,
                      (i) => ListTile(title: Text('item $i')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
    },
  );
}
