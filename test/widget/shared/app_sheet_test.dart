// showAppSheet / KeyboardAwareSheet: a modal sheet stays above the keyboard.
//
// Root-route case: the sheet reads the real inset, the wrapper's padding
// lifts it. Shell-branch case (shellLike): the inset reads 0 inside the shell
// Scaffold's body, and the shrunk body is what bounds the sheet. Both must
// leave the content entirely above the keyboard.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/features/shared/app_sheet.dart';

import '../../helpers/keyboard.dart';

const _fieldKey = Key('sheet-field');
const _openKey = Key('open-sheet');

/// A page with a button that opens a sheet holding a text field followed by
/// tall content, the shape of every sheet with a field in the app.
class _Host extends StatelessWidget {
  const _Host({this.maxHeightFraction = 1.0, this.isScrollControlled = true});

  final double maxHeightFraction;
  final bool isScrollControlled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: _openKey,
          onPressed: () => showAppSheet<void>(
            context: context,
            isScrollControlled: isScrollControlled,
            maxHeightFraction: maxHeightFraction,
            builder: (_) => const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(key: _fieldKey),
                  SizedBox(height: 900),
                ],
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Widget _app(Widget home, ValueNotifier<double> inset) =>
    MaterialApp(builder: keyboardInsetBuilder(inset), home: home);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
}

void main() {
  group('sheetMaxHeight', () {
    test('is capped by the fraction of the screen when no keyboard', () {
      expect(
        sheetMaxHeight(screenHeight: 667, keyboardInset: 0, fraction: 0.85),
        closeTo(566.95, 0.01),
      );
    });

    test('is capped by the space above the keyboard when that is smaller', () {
      expect(
        sheetMaxHeight(screenHeight: 667, keyboardInset: 291, fraction: 0.85),
        376,
      );
    });

    test('never goes negative', () {
      expect(
        sheetMaxHeight(screenHeight: 300, keyboardInset: 400, fraction: 1.0),
        0,
      );
    });
  });

  group('showAppSheet on a root route', () {
    testWidgets('lifts the sheet and its field above the keyboard', (
      tester,
    ) async {
      useSurface(tester, kReferenceSurface);
      final inset = ValueNotifier<double>(0);
      await tester.pumpWidget(_app(const _Host(), inset));
      await _openSheet(tester);

      inset.value = kReferenceKeyboard;
      await tester.pumpAndSettle();

      expectAboveKeyboard(
        tester,
        find.byKey(_fieldKey),
        inset: kReferenceKeyboard,
      );
      expectAboveKeyboard(
        tester,
        find.byType(SingleChildScrollView),
        inset: kReferenceKeyboard,
      );
    });

    testWidgets('caps the sheet at maxHeightFraction when no keyboard', (
      tester,
    ) async {
      useSurface(tester, kReferenceSurface);
      final inset = ValueNotifier<double>(0);
      await tester.pumpWidget(_app(const _Host(maxHeightFraction: 0.5), inset));
      await _openSheet(tester);

      final rect = tester.getRect(find.byType(SingleChildScrollView));
      expect(rect.height, closeTo(667 * 0.5, 0.5));
      expect(rect.bottom, 667);
    });

    testWidgets(
      'with the defaults, a non scroll-controlled sheet has the SDK geometry',
      (tester) async {
        useSurface(tester, kReferenceSurface);
        final inset = ValueNotifier<double>(0);
        await tester.pumpWidget(
          _app(const _Host(isScrollControlled: false), inset),
        );
        await _openSheet(tester);

        // The SDK caps a non scroll-controlled sheet at 9/16 of the height.
        final rect = tester.getRect(find.byType(SingleChildScrollView));
        expect(rect.height, closeTo(667 * 9 / 16, 0.5));
        expect(rect.bottom, 667);
      },
    );
  });

  group('showAppSheet from a shell branch', () {
    testWidgets(
      'the shrunk shell body bounds the sheet, content stays above the keyboard',
      (tester) async {
        useSurface(tester, kReferenceSurface);
        final inset = ValueNotifier<double>(0);
        await tester.pumpWidget(_app(shellLike(const _Host()), inset));
        await _openSheet(tester);

        inset.value = kReferenceKeyboard;
        await tester.pumpAndSettle();

        // Inside the shell the sheet reads no inset at all...
        final sheetContext = tester.element(find.byKey(_fieldKey));
        expect(MediaQuery.viewInsetsOf(sheetContext).bottom, 0);
        // ...and is still entirely above the keyboard, with no overflow
        // (an overflow would have failed the test as an exception).
        expectAboveKeyboard(
          tester,
          find.byType(SingleChildScrollView),
          inset: kReferenceKeyboard,
        );
        expectAboveKeyboard(
          tester,
          find.byKey(_fieldKey),
          inset: kReferenceKeyboard,
        );
      },
    );
  });
}
