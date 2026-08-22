// The consent gate (AC-C03): the first photo is unreachable until the box is
// ticked. Here that means the "Commencer" button does not fire onStart until
// consent, which is the only path from the guide into the capture journey.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/provider/identity/identity_guide_page.dart';

Widget _wrap({required VoidCallback onStart, VoidCallback? onOpenTerms}) {
  return MaterialApp(
    locale: const Locale('fr'),
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: IdentityGuidePage(onStart: onStart, onOpenTerms: onOpenTerms),
  );
}

void main() {
  testWidgets('the start button is disabled until consent is given', (
    tester,
  ) async {
    var started = false;
    await tester.pumpWidget(_wrap(onStart: () => started = true));
    await tester.pumpAndSettle();

    // Helper line is shown, and the button does nothing when tapped.
    expect(find.text('Cochez la case pour continuer'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(started, isFalse);
  });

  testWidgets('ticking the box enables start and fires onStart (AC-C03)', (
    tester,
  ) async {
    var started = false;
    await tester.pumpWidget(_wrap(onStart: () => started = true));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // The helper line is gone and the button is now live.
    expect(find.text('Cochez la case pour continuer'), findsNothing);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Commencer'));
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(started, isTrue);
  });

  testWidgets('the six mandatory mentions are all present (AC-C02)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(onStart: () {}));
    await tester.pumpAndSettle();

    // A representative fragment of each of the six mentions (draft text).
    expect(find.textContaining('recto et du verso'), findsOneWidget);
    expect(find.textContaining('uniquement'), findsOneWidget);
    expect(find.textContaining('personnes habilitées'), findsOneWidget);
    expect(find.textContaining('suppression de votre compte'), findsOneWidget);
    expect(find.textContaining('supprimer votre compte'), findsOneWidget);
    expect(find.textContaining('48 heures'), findsWidgets);
  });

  testWidgets('the terms link fires onOpenTerms', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _wrap(onStart: () {}, onOpenTerms: () => opened = true),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lire les conditions d\'utilisation'));
    await tester.tap(find.text('Lire les conditions d\'utilisation'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });
}
