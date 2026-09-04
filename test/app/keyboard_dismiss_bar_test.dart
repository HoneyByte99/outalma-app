// Widget tests for KeyboardDismissBar: the one shared mechanism that shows a
// button to close the on-screen keyboard whenever a text field has focus,
// anywhere in the app.
//
// The motivating case is a keyboard with no usable return key (numeric,
// phone, multiline): the field never offers a way back, so the visibility
// contract (appears on focus, disappears on blur, the button actually drops
// focus) is proved directly here rather than trusted from a single field.

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
  group('KeyboardDismissBar, appears on focus, disappears on blur', () {
    testWidgets('bar is absent before any field has focus', (tester) async {
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

      expect(find.byKey(_barKey), findsNothing);
    });

    testWidgets('bar appears the moment a text field gains focus', (
      tester,
    ) async {
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

      expect(find.byKey(_barKey), findsOneWidget);
      expect(find.text('Fermer le clavier'), findsOneWidget);
    });

    testWidgets('bar disappears the moment that field loses focus', (
      tester,
    ) async {
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
            child: Scaffold(body: TextField(focusNode: focusNode)),
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
      'bar still renders, layered above the sheet content, when a field inside a modal bottom sheet has focus',
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
                      child: TextField(focusNode: focusNode),
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

  group('KeyboardDismissBar.isTextInputFocus, the guard', () {
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
