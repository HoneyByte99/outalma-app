import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/public_profile_providers.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/domain/models/public_profile.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/review/rating_summary.dart';
import 'package:outalma_app/src/features/review/user_reviews_page.dart';
import 'package:outalma_app/src/features/shared/gender_icon.dart';

/// Chantier 2 (wave-ui-093814): the gender pictogram already shown on the
/// catalogue card, the service detail, the provider profile, the booking
/// detail and the chat page was missing on this screen's header. Only on the
/// PROVIDER reputation (`RatingSource.provider`): a client's own gender has no
/// place next to their name here, the same distinction the header truth test
/// beside this file makes for "avis de clients".
void main() {
  Widget wrap({required RatingSource source, required Gender? gender}) {
    return ProviderScope(
      overrides: [
        publicProfileByIdProvider('target').overrideWith(
          (_) => Stream.value(
            PublicProfile(
              id: 'target',
              displayName: 'Ibrahima Sow',
              country: 'SN',
              gender: gender,
            ),
          ),
        ),
        reviewsForUserProvider('target').overrideWith((_) => Stream.value([])),
        providerRatingProvider(
          'target',
        ).overrideWith((_) => Stream.value(ratingDisplay(sum: 0, count: 0))),
        clientReputationProvider(
          'target',
        ).overrideWith((_) => Stream.value(ratingDisplay(sum: 0, count: 0))),
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

  testWidgets('a declared-gender provider shows the pictogram', (tester) async {
    await tester.pumpWidget(
      wrap(source: RatingSource.provider, gender: Gender.female),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(GenderIcon), findsOneWidget);
  });

  testWidgets('a provider with no declared gender renders nothing extra', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(source: RatingSource.provider, gender: null));
    await tester.pump();
    await tester.pump();

    // GenderIcon is still mounted (it is unconditionally in the tree for
    // `source == provider`) but must render nothing itself: no glyph, no
    // tooltip. Scoped to its own subtree, since the page carries unrelated
    // icons elsewhere (the app bar, the star rating).
    expect(find.byType(GenderIcon), findsOneWidget);
    expect(
      find.descendant(of: find.byType(GenderIcon), matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(GenderIcon),
        matching: find.byType(Tooltip),
      ),
      findsNothing,
    );
  });

  testWidgets('a client reputation never shows the pictogram, gender or not', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(source: RatingSource.client, gender: Gender.male),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byType(GenderIcon),
      findsNothing,
      reason:
          'gender is a provider-facing attribute; a client reputation '
          'screen must not show it, declared or not',
    );
  });
}
