import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/public_profile_providers.dart';
import 'package:outalma_app/src/domain/models/review.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/review/rating_summary.dart';
import 'package:outalma_app/src/features/review/user_reviews_page.dart';

/// This one screen is opened for a CLIENT from a booking and for a PROVIDER
/// from a service listing. It cannot tell them apart, so the route tells it,
/// and reading the wrong source shows "Nouveau" for every client for ever on
/// one side or a floorless average on the other.
void main() {
  Widget wrap(RatingSource source) => ProviderScope(
    overrides: [
      publicProfileByIdProvider('u1').overrideWith((_) => Stream.value(null)),
      reviewsForUserProvider(
        'u1',
      ).overrideWith((_) => Stream.value(<Review>[])),
      providerRatingProvider(
        'u1',
      ).overrideWith((_) => Stream.value(ratingDisplay(sum: 48, count: 12))),
      clientReputationProvider(
        'u1',
      ).overrideWith((_) => Stream.value(ratingDisplay(sum: 9, count: 3))),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UserReviewsPage(userId: 'u1', source: source),
    ),
  );

  testWidgets('opened as a provider, it shows the server aggregate', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(RatingSource.provider));
    await tester.pump();
    await tester.pump();
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('3.0'), findsNothing);
  });

  testWidgets('opened as a client, it shows the review-derived reputation', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(RatingSource.client));
    await tester.pump();
    await tester.pump();
    expect(find.text('3.0'), findsOneWidget);
    expect(
      find.text('4.0'),
      findsNothing,
      reason: 'no aggregate is ever written for a client',
    );
  });
}
