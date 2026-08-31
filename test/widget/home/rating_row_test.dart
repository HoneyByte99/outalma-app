import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/home/home_page.dart';

/// The rating on a listing card. It has about forty pixels to live in, next to
/// a provider name that has no more, so what it does NOT print matters as much
/// as what it does.
void main() {
  Widget wrap(Stream<RatingDisplay> stream) => ProviderScope(
    overrides: [providerRatingProvider('p1').overrideWith((_) => stream)],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: RatingRow(providerId: 'p1')),
    ),
  );

  testWidgets('three reviews show the average WITHOUT its count', (
    tester,
  ) async {
    // The count lives on the detail and on the reviews page. Every character
    // it took here was taken from the provider's name.
    await tester.pumpWidget(
      wrap(Stream.value(ratingDisplay(sum: 12, count: 3))),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('4.0'), findsOneWidget);
    expect(find.textContaining('(3)'), findsNothing);
  });

  testWidgets('below the floor it says "Nouveau"', (tester) async {
    await tester.pumpWidget(
      wrap(Stream.value(ratingDisplay(sum: 10, count: 2))),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.text('5.0'), findsNothing);
  });

  testWidgets('an unresolved read claims nothing at all (U1)', (tester) async {
    // Rendering "Nouveau" while the read is in flight would flash a false
    // statement about a provider rated 4.8, on every scroll of the grid.
    await tester.pumpWidget(wrap(const Stream.empty()));
    await tester.pump();

    expect(find.text('Nouveau'), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('it fits the width a card can spare', (tester) async {
    await tester.pumpWidget(
      wrap(Stream.value(ratingDisplay(sum: 48, count: 12))),
    );
    await tester.pump();
    await tester.pump();

    final size = tester.getSize(find.byType(RatingRow));
    expect(
      size.width,
      lessThan(60),
      reason: 'the provider name has about forty pixels next to this',
    );
  });
}
