// The RGPD data-export dialog of ProfilePage, in the state it is really used
// in: the user has tapped the email field, so the keyboard is up, and this
// user reads at a 200 % text scale.
//
// Geometry on the reference device (375x667): a Dialog pads itself by the
// view insets, so a 291 px keyboard leaves it 667 - 48 - 291 = 328 px, and at
// a 200 % text scale the title plus the body paragraph plus the email field
// measure more than that. An AlertDialog without `scrollable: true` puts its
// content in a plain Flexible: the Column overflows and the field is painted
// outside the box, where no gesture can reach it. With `scrollable: true` the
// SDK wraps title and content in a SingleChildScrollView, which is the only
// thing that makes the field reachable.
//
// The dialog is mounted alone (showExportRequestDialog) rather than reached
// through ProfilePage: at a 200 % text scale the page behind has row
// overflows of its own, and they would be reported instead of this geometry.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/profile/profile_page.dart';

import '../../helpers/keyboard.dart';

/// FR label of the email field, the locale this test pins.
const _emailLabel = 'Adresse email';
const _openKey = Key('open-export-dialog');

/// The inset and the text scale are injected through `MaterialApp.builder`,
/// i.e. ABOVE the Navigator, so the dialog route sees them too. A MediaQuery
/// wrapped around `home:` only would not reach it.
Widget _app(ValueNotifier<double> inset, double textScale) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => ValueListenableBuilder<double>(
    valueListenable: inset,
    builder: (context, insetValue, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        viewInsets: EdgeInsets.only(bottom: insetValue),
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          key: _openKey,
          onPressed: () => showExportRequestDialog(
            context: context,
            controller: TextEditingController(text: 'alice@test.com'),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the data-export dialog scrolls instead of clipping its email '
      'field when the keyboard is up at a 200 % text scale', (tester) async {
    useSurface(tester, kReferenceSurface);
    final inset = ValueNotifier<double>(0);
    await tester.pumpWidget(_app(inset, 2.0));
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    // Tapping the email field opens the keyboard.
    inset.value = kReferenceKeyboard;
    await tester.pumpAndSettle();

    final field = find.ancestor(
      of: find.text(_emailLabel),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);

    // The guard: `scrollable: true` is what puts a scroll view between the
    // field and the dialog. Without it there is none, and the Column that
    // holds the field overflows the dialog instead.
    final dialogScroll = find.ancestor(
      of: field,
      matching: find.byType(SingleChildScrollView),
    );
    expect(
      dialogScroll,
      findsOneWidget,
      reason: 'the export dialog has nothing to scroll its content with',
    );

    // `.first` skips the TextField's own editable scrollable, which is a
    // descendant too.
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: dialogScroll, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    // Space really is short here, so the geometry below is not vacuous.
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: 'the content fits, so this test proves nothing',
    );

    // A real gesture brings the field into the box, above the keyboard.
    // Dragged well past the extent (the scrollable eats kTouchSlop before it
    // moves); the clamping physics stop at the end of the content.
    await tester.drag(dialogScroll, Offset(0, -position.maxScrollExtent - 100));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));

    expectInsideBox(tester, field, dialogScroll);
    expectAboveKeyboard(tester, field, inset: kReferenceKeyboard);
  });
}
