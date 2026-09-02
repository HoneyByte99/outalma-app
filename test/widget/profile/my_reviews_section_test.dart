import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';
import 'package:outalma_app/src/features/profile/profile_page.dart';

/// "Mes avis" prints a big average above the user's own reviews.
///
/// A round-1 fix once made it print a literal 0.0 with five empty stars,
/// directly above two five-star reviews, because it kept the average with
/// `?? 0.0` and threw away the "Nouveau" verdict. This mounts the section so
/// that regression cannot come back unnoticed.
Review _review(String id, int rating) => Review(
  id: id,
  bookingId: 'b_$id',
  reviewerId: 'someone',
  revieweeId: 'me',
  reviewerRole: ReviewerRole.client,
  rating: rating,
  comment: '',
  createdAt: DateTime.utc(2026, 8, 20),
);

Widget wrap(List<Review> reviews) => ProviderScope(
  overrides: [
    reviewsForUserProvider('me').overrideWith((_) => Stream.value(reviews)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: MyReviewsSection(uid: 'me')),
  ),
);

void main() {
  testWidgets('two five-star reviews never become a rating of zero', (
    tester,
  ) async {
    await tester.pumpWidget(wrap([_review('a', 5), _review('b', 5)]));
    await tester.pump();
    await tester.pump();

    expect(find.text('0.0'), findsNothing, reason: 'the round-1 regression');
    expect(find.text('Nouveau'), findsOneWidget);
    expect(
      find.byIcon(Icons.star_outline_rounded),
      findsNothing,
      reason: 'five empty stars read as a rating of zero',
    );
  });

  testWidgets('three reviews do earn a number and its stars', (tester) async {
    await tester.pumpWidget(
      wrap([_review('a', 4), _review('b', 4), _review('c', 4)]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('4.0'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });
}
