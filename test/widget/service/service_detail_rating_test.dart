import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/review/rating_summary.dart';

/// The rating rule has to be the SAME on every surface, otherwise a client
/// reads "Nouveau" on a listing, taps through, and reads "4.5" two screens
/// later. That is the defect this increment exists to close, not to move.
Widget _wrap({required RatingSource source, required String uid}) {
  return ProviderScope(
    overrides: [
      providerRatingProvider(
        'prov_1',
      ).overrideWith((_) => Stream.value(ratingDisplay(sum: 12, count: 3))),
      clientReputationProvider(
        'client_1',
      ).overrideWith((_) => Stream.value(ratingDisplay(sum: 2, count: 1))),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (_) => RatingSummary(userId: uid, source: source),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a provider with three reviews shows the average', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(source: RatingSource.provider, uid: 'prov_1'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('4.0'), findsOneWidget);
  });

  testWidgets('a client with one review stays "Nouveau"', (tester) async {
    // The floor applies to the client reputation too: one review is not a
    // verdict, whichever side of the marketplace is being judged.
    await tester.pumpWidget(
      _wrap(source: RatingSource.client, uid: 'client_1'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Nouveau'), findsOneWidget);
  });

  testWidgets('a client reputation NEVER reads the provider aggregate', (
    tester,
  ) async {
    // No provider_ratings document is ever written for a client. Reading the
    // aggregate here would show "Nouveau" for every client, for ever, on the
    // screen where a provider decides whether to accept.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Deliberately loud: if the widget read this, the test would show 5.0
          providerRatingProvider(
            'client_1',
          ).overrideWith((_) => Stream.value(ratingDisplay(sum: 25, count: 5))),
          clientReputationProvider(
            'client_1',
          ).overrideWith((_) => Stream.value(ratingDisplay(sum: 9, count: 3))),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RatingSummary(
              userId: 'client_1',
              source: RatingSource.client,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('3.0'), findsOneWidget);
    expect(find.text('5.0'), findsNothing);
  });

  testWidgets('an unresolved read shows nothing, it does not claim "Nouveau"', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRatingProvider(
            'prov_1',
          ).overrideWith((_) => const Stream.empty()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RatingSummary(
              userId: 'prov_1',
              source: RatingSource.provider,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Nouveau'), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });
}
