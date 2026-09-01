import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/review/rating_summary.dart';
import 'package:outalma_app/src/features/review/user_reviews_page.dart';

/// Regression for the defect the 2026-09-01 smoke found on the real app: the
/// header reads the server aggregate (3) while the list below shows every
/// review received (6), and nothing on screen says the two count different
/// things. A reader falsifies the header by counting the tiles.
///
/// This test mounts the PAGE, not the header. That is the whole lesson of the
/// previous lot: its tests mounted the header alone and saw none of this.
void main() {
  Review review(String id, int rating) => Review(
    id: id,
    bookingId: 'b_$id',
    reviewerId: 'reviewer_$id',
    revieweeId: 'target',
    reviewerRole: ReviewerRole.client,
    rating: rating,
    createdAt: DateTime.utc(2026, 8, int.parse(id)),
  );

  // Six reviews received, three of which count toward the public rating.
  final sixReviews = [for (var i = 1; i <= 6; i++) review('$i', 4)];

  Widget wrap({
    required RatingSource source,
    required List<Review> reviews,
    required RatingDisplay rating,
  }) {
    return ProviderScope(
      overrides: [
        userByIdProvider('target').overrideWith(
          (_) => Stream.value(
            AppUser(
              id: 'target',
              displayName: 'Ibrahima Sow',
              email: 'x@example.com',
              country: 'SN',
              activeMode: ActiveMode.client,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ),
        ),
        // _ReviewTile re-watches userByIdProvider per review, and that provider
        // reaches the real firestoreProvider, so it throws unless every
        // reviewerId is overridden too.
        for (final r in reviews)
          userByIdProvider(r.reviewerId).overrideWith(
            (_) => Stream.value(
              AppUser(
                id: r.reviewerId,
                displayName: 'Client ${r.reviewerId}',
                email: 'c@example.com',
                country: 'SN',
                activeMode: ActiveMode.client,
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            ),
          ),
        reviewsForUserProvider(
          'target',
        ).overrideWith((_) => Stream.value(reviews)),
        providerRatingProvider(
          'target',
        ).overrideWith((_) => Stream.value(rating)),
        clientReputationProvider(
          'target',
        ).overrideWith((_) => Stream.value(rating)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UserReviewsPage(userId: 'target', source: source),
      ),
    );
  }

  testWidgets('a header counting 3 above a list of 6 names what it counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        source: RatingSource.provider,
        reviews: sixReviews,
        rating: ratingDisplay(sum: 13, count: 3),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The exact situation seen on the app.
    expect(find.byType(Card), findsNothing); // tiles are Containers, not Cards
    expect(find.textContaining('Client reviewer_'), findsNWidgets(6));

    expect(find.text('4.3'), findsOneWidget);
    expect(
      find.textContaining('3 avis de clients'),
      findsOneWidget,
      reason: 'the header must say WHAT it counted, not just how many',
    );
    expect(
      find.text('Tous les avis reçus'),
      findsOneWidget,
      reason: 'and the list must say that it counts something else',
    );
  });

  testWidgets('"Nouveau" above a non-empty list is explained', (tester) async {
    // The worst case from the register: on the real app this read "Nouveau"
    // directly above five four- and five-star reviews.
    await tester.pumpWidget(
      wrap(
        source: RatingSource.provider,
        reviews: sixReviews,
        rating: ratingDisplay(sum: 8, count: 2),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.textContaining('moins de 3 avis de clients'), findsOneWidget);
    expect(find.text('Tous les avis reçus'), findsOneWidget);
  });

  testWidgets('the list title is absent when there is nothing to list', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        source: RatingSource.provider,
        reviews: const [],
        rating: ratingDisplay(sum: 0, count: 0),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Tous les avis reçus'), findsNothing);
    expect(find.text('Aucun avis reçu pour le moment'), findsOneWidget);
  });

  testWidgets('opened for a CLIENT, the basis drops "de clients"', (
    tester,
  ) async {
    // A client's reputation derives from every review received, which is
    // exactly the list below. Naming it "avis de clients" would be false.
    await tester.pumpWidget(
      wrap(
        source: RatingSource.client,
        reviews: sixReviews.take(2).toList(),
        rating: ratingDisplay(sum: 8, count: 2),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.textContaining('moins de 3 avis'), findsOneWidget);
    expect(find.textContaining('de clients'), findsNothing);
  });
}
