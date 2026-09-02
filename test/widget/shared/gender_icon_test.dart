// The gender pictogram. The owner asked for the icon ALONE, with no word beside
// it, so two properties carry the whole feature and both are asserted here:
//
//  - unknown renders NOTHING, not a neutral glyph. Every one of the 50 accounts
//    in production predates the field, and a default pictogram would assert a
//    gender next to a real person's name on a page a visitor can read.
//  - the word still exists for a screen reader and for a long press, even
//    though it is never painted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/features/shared/gender_icon.dart';

void main() {
  Widget wrap(Gender? gender) => MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: GenderIcon(gender: gender)),
    ),
  );

  testWidgets('an unknown gender renders no icon at all', (tester) async {
    await tester.pumpWidget(wrap(null));
    await tester.pump();

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    // And no width reserved: the line it sits on has about forty pixels to
    // spare for the provider's name.
    expect(tester.getSize(find.byType(GenderIcon)), Size.zero);
  });

  testWidgets('male renders the man pictogram and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(Gender.male));
    await tester.pump();

    expect(find.byIcon(Icons.man), findsOneWidget);
    expect(find.byIcon(Icons.woman), findsNothing);
  });

  testWidgets('female renders the woman pictogram and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(Gender.female));
    await tester.pump();

    expect(find.byIcon(Icons.woman), findsOneWidget);
    expect(find.byIcon(Icons.man), findsNothing);
  });

  testWidgets('the word is never painted, on either value', (tester) async {
    // The owner's decision: the pictogram alone on the catalogue card and on
    // the service detail. A label rendered here would eat the provider's name.
    for (final gender in Gender.values) {
      await tester.pumpWidget(wrap(gender));
      await tester.pump();
      expect(find.byType(Text), findsNothing, reason: '$gender');
    }
  });

  testWidgets('a screen reader still hears the word in full', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(Gender.male));
    await tester.pump();
    expect(find.bySemanticsLabel('Homme'), findsOneWidget);

    await tester.pumpWidget(wrap(Gender.female));
    await tester.pump();
    expect(find.bySemanticsLabel('Femme'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('a long press prints the word as a tooltip', (tester) async {
    await tester.pumpWidget(wrap(Gender.female));
    await tester.pump();

    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'Femme',
      reason: 'the long-press affordance is where the icon says its own name',
    );
  });
}
