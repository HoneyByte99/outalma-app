// ReportPage under the keyboard.
//
// Before the fix the body was a non-scrollable column with a Flexible list
// of reasons: once a reason was picked and the details field focused, the
// keyboard squeezed the reasons to zero height and the submit button fell
// ~86 px off the bottom of a 375x667 phone. The button now lives in a footer
// inside the body, which the Scaffold shrinks with the keyboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/report/report_page.dart';

import '../../helpers/keyboard.dart';

Widget _wrap(ValueNotifier<double> keyboard) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fr'),
    builder: keyboardInsetBuilder(keyboard),
    home: const ReportPage(targetType: 'user', targetId: 'u1'),
  ),
);

void main() {
  testWidgets('the submit button is disabled until a reason is picked', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(ValueNotifier<double>(0)));
    await tester.pump();

    final button = find.byType(ElevatedButton);
    expect(button, findsOneWidget);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Comportement inapproprié'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'with a reason picked and the keyboard open, the details field and the '
    'submit button stay above the keyboard',
    (tester) async {
      useSurface(tester, kReferenceSurface);
      final keyboard = ValueNotifier<double>(0);
      await tester.pumpWidget(_wrap(keyboard));
      await tester.pump();

      await tester.tap(find.text('Comportement inapproprié'));
      await tester.pump();

      keyboard.value = kReferenceKeyboard;
      await tester.pumpAndSettle();
      // The field sits below six reasons: scroll it into view inside the
      // shrunk body, as the user (or the caret on a device) would.
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // No overflow was thrown (it would have failed the test).
      expectAboveKeyboard(
        tester,
        find.byType(ElevatedButton),
        inset: kReferenceKeyboard,
      );
      expectAboveKeyboard(
        tester,
        find.byType(TextField),
        inset: kReferenceKeyboard,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    },
  );
}
