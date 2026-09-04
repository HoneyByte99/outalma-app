// Widget tests for KeyboardDismissBar: the one shared mechanism that shows a
// button to close the on-screen keyboard, but only for a field that cannot
// close it itself.
//
// Most fields already have a usable native return key once they declare a
// TextInputAction, so the bar would be a redundant, "moche" button
// competing with the system for them. It only earns its place for the two
// families that genuinely have no way out: a numeric/phone keyboard, which
// has no return key at all on iOS, and a multiline field, whose return key
// inserts a line break instead of submitting. That decision (appears on
// focus, disappears on blur, the button actually drops focus) is proved
// directly here rather than trusted from a single field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/app/keyboard_dismiss_bar.dart';

const _barKey = Key('keyboardDismissBar');
const _buttonKey = Key('keyboardDismissButton');

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// A focus change is applied by [FocusManager] and its listeners are
/// notified via a post-frame callback; [KeyboardDismissBar] itself defers its
/// own `setState` by one more frame to avoid rebuilding mid-frame. Two pumps
/// are needed to observe the settled result.
Future<void> _settleFocus(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  group('KeyboardDismissBar.needsDismissBar, the three families', () {
    testWidgets(
      'false for a single-line text field with no declared textInputAction '
      '(resolves to done)',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          _wrap(Scaffold(body: TextField(focusNode: focusNode))),
        );
        focusNode.requestFocus();
        await tester.pump();

        expect(KeyboardDismissBar.needsDismissBar(focusNode), isFalse);
      },
    );

    testWidgets(
      'false for a single-line text field with an explicit next action',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: TextField(
                focusNode: focusNode,
                textInputAction: TextInputAction.next,
              ),
            ),
          ),
        );
        focusNode.requestFocus();
        await tester.pump();

        expect(KeyboardDismissBar.needsDismissBar(focusNode), isFalse);
      },
    );

    testWidgets('true for a numeric field, even with an explicit done action '
        '(no return key on iOS regardless of the declared action)', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: TextField(
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      expect(KeyboardDismissBar.needsDismissBar(focusNode), isTrue);
    });

    testWidgets('true for a phone field', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: TextField(
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      expect(KeyboardDismissBar.needsDismissBar(focusNode), isTrue);
    });

    testWidgets('true for a multiline field with no declared textInputAction '
        '(resolves to newline)', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(Scaffold(body: TextField(focusNode: focusNode, maxLines: 4))),
      );
      focusNode.requestFocus();
      await tester.pump();

      expect(KeyboardDismissBar.needsDismissBar(focusNode), isTrue);
    });

    testWidgets('true for a multiline field with an explicit newline action', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: TextField(
              focusNode: focusNode,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      expect(KeyboardDismissBar.needsDismissBar(focusNode), isTrue);
    });

    test('false for a null node (nothing focused)', () {
      expect(KeyboardDismissBar.needsDismissBar(null), isFalse);
    });

    testWidgets('false for a focus node attached to a non-text widget', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: Focus(focusNode: focusNode, child: const SizedBox()),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      expect(KeyboardDismissBar.needsDismissBar(focusNode), isFalse);
    });
  });

  group('KeyboardDismissBar, appears only for a field that cannot dismiss '
      'its own keyboard', () {
    testWidgets('bar is absent before any field has focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          KeyboardDismissBar(
            child: Scaffold(
              body: TextField(
                focusNode: focusNode,
                keyboardType: TextInputType.number,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(_barKey), findsNothing);
    });

    testWidgets(
      'bar appears the moment a field that cannot self-dismiss gains focus',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            KeyboardDismissBar(
              child: Scaffold(
                body: TextField(
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        focusNode.requestFocus();
        await _settleFocus(tester);

        expect(find.byKey(_barKey), findsOneWidget);
        expect(find.text('Terminé'), findsOneWidget);
      },
    );

    testWidgets('bar disappears the moment that field loses focus', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          KeyboardDismissBar(
            child: Scaffold(
              body: TextField(
                focusNode: focusNode,
                keyboardType: TextInputType.number,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      focusNode.requestFocus();
      await _settleFocus(tester);
      expect(find.byKey(_barKey), findsOneWidget);

      focusNode.unfocus();
      await _settleFocus(tester);

      expect(find.byKey(_barKey), findsNothing);
    });

    testWidgets(
      'bar does not appear for a non-text-input focus (e.g. a button)',
      (tester) async {
        final focusNode = FocusNode(debugLabel: 'plain-focusable');
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            KeyboardDismissBar(
              child: Scaffold(
                body: Focus(
                  focusNode: focusNode,
                  child: const SizedBox(width: 10, height: 10),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        focusNode.requestFocus();
        await _settleFocus(tester);

        expect(find.byKey(_barKey), findsNothing);
      },
    );

    testWidgets(
      'bar does NOT appear for a single-line text field, which can close '
      'its own keyboard via its return key',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            KeyboardDismissBar(
              child: Scaffold(body: TextField(focusNode: focusNode)),
            ),
          ),
        );
        await tester.pump();

        focusNode.requestFocus();
        await _settleFocus(tester);

        expect(find.byKey(_barKey), findsNothing);
      },
    );
  });

  group('KeyboardDismissBar, the button drops focus', () {
    testWidgets('tapping the dismiss button removes focus from the field', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          KeyboardDismissBar(
            child: Scaffold(
              body: TextField(
                focusNode: focusNode,
                keyboardType: TextInputType.number,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      focusNode.requestFocus();
      await _settleFocus(tester);
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.byKey(_buttonKey));
      await _settleFocus(tester);

      expect(focusNode.hasFocus, isFalse);
      expect(find.byKey(_barKey), findsNothing);
    });
  });

  group('KeyboardDismissBar, the motivating case: no usable return key', () {
    testWidgets(
      'bar appears for a numeric field, which has no return key to fall back on',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            KeyboardDismissBar(
              child: Scaffold(
                body: TextField(
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        focusNode.requestFocus();
        await _settleFocus(tester);

        expect(find.byKey(_barKey), findsOneWidget);

        // And the same button still drops focus on this field.
        await tester.tap(find.byKey(_buttonKey));
        await _settleFocus(tester);
        expect(focusNode.hasFocus, isFalse);
      },
    );

    testWidgets(
      'bar appears for a multiline field, whose return key inserts a newline instead of submitting',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            KeyboardDismissBar(
              child: Scaffold(
                body: TextField(
                  focusNode: focusNode,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        focusNode.requestFocus();
        await _settleFocus(tester);

        expect(find.byKey(_barKey), findsOneWidget);
      },
    );
  });

  group('KeyboardDismissBar, above a modal bottom sheet', () {
    testWidgets(
      'bar still renders, layered above the sheet content, when a field '
      'that cannot self-dismiss inside a modal bottom sheet has focus',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        // Mirrors the production wiring: MaterialApp.builder wraps the built
        // Navigator (the `child` argument), so a modal bottom sheet pushed
        // onto that Navigator ends up NESTED INSIDE KeyboardDismissBar's own
        // child, while the dismiss bar itself stays a sibling painted after
        // it, same structure as app.dart's builder + ConnectivityBanner.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => KeyboardDismissBar(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => SizedBox(
                      height: 200,
                      child: TextField(
                        focusNode: focusNode,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  child: const Text('open sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();

        focusNode.requestFocus();
        await _settleFocus(tester);

        expect(find.byKey(_barKey), findsOneWidget);

        // Structural proof of paint order: KeyboardDismissBar's Stack always
        // paints the dismiss bar as its LAST child when visible, so it is
        // the topmost layer regardless of what the routed content (here, the
        // sheet) draws underneath it.
        final stack = tester.widget<Stack>(
          find.byKey(const Key('keyboardDismissStack')),
        );
        expect(stack.children.last, isA<Positioned>());
      },
    );
  });

  group('KeyboardDismissBar.isTextInputFocus, the ancestor walk', () {
    testWidgets('true for a focus node attached to a text field', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(Scaffold(body: TextField(focusNode: focusNode))),
      );
      focusNode.requestFocus();
      await tester.pump();

      expect(KeyboardDismissBar.isTextInputFocus(focusNode), isTrue);
    });

    testWidgets('false for a focus node attached to a non-text widget', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: Focus(focusNode: focusNode, child: const SizedBox()),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      expect(KeyboardDismissBar.isTextInputFocus(focusNode), isFalse);
    });

    test('false for a node never attached to any widget context', () {
      final focusNode = FocusNode();
      expect(KeyboardDismissBar.isTextInputFocus(focusNode), isFalse);
      focusNode.dispose();
    });

    test('false for a null node (nothing focused)', () {
      expect(KeyboardDismissBar.isTextInputFocus(null), isFalse);
    });
  });
}
