import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/identity_trust_providers.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/provider_profile.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/provider/public_provider_profile_page.dart';

/// Regression for the yellow "BOTTOM OVERFLOWED" banner seen on the real app
/// on 2026-09-01. The header lived in a FlexibleSpaceBar under a fixed
/// expandedHeight of 200 and overflowed as soon as a provider's bio ran to
/// three lines.
///
/// This mounts the PAGE, not the header: the header alone never overflowed,
/// which is exactly why the previous lot's tests saw nothing.
///
/// The surface is set with setSurfaceSize, which takes LOGICAL pixels. Using
/// view.physicalSize instead would be a trap: the test devicePixelRatio is 3.0,
/// so 375 physical pixels is 125 logical ones, the header column would get a
/// negative width, and the test would be red for a reason that has nothing to
/// do with the defect, before and after the fix alike.
/// Proven RED on 2026-09-01 by restoring ONLY expandedHeight and
/// flexibleSpace, keeping the Expanded on _EmptySection and the Flexible on the
/// country row: "A RenderFlex overflowed by 274 pixels on the bottom", on all
/// three cases. The axis matters. Reverting the whole lot instead would have
/// surfaced a "right" error first, because viewport slivers paint last-to-first
/// and takeException() returns only the first error recorded.
void main() {
  const longBio =
      'Aide a domicile polyvalente a Dakar. Specialiste menage et preparation '
      'de repas senegalais. Disponible en semaine comme le week-end, avec dix '
      'ans de metier et des references verifiables sur demande.';

  Widget wrap({double textScale = 1.0, required RatingDisplay rating}) {
    return ProviderScope(
      overrides: [
        userByIdProvider('p1').overrideWith(
          (_) => Stream.value(
            AppUser(
              id: 'p1',
              displayName: 'Moussa Diallo',
              email: 'm@example.com',
              // A long country name: the row that carries it is the other
              // horizontal overflow this page had.
              country: 'AE',
              activeMode: ActiveMode.provider,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ),
        ),
        providerProfileByIdProvider('p1').overrideWith(
          (_) => Stream.value(
            ProviderProfile(
              uid: 'p1',
              bio: longBio,
              active: true,
              suspended: false,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ),
        ),
        providerRatingProvider('p1').overrideWith((_) => Stream.value(rating)),
        identityTrustProvider('p1').overrideWith((_) => Stream.value(null)),
        // Empty on purpose: the defect comes from the bio and the country row,
        // not from review tiles. It also renders _EmptySection twice, which is
        // the widget whose own horizontal overflow used to mask this one.
        reviewsForUserProvider('p1').overrideWith((_) => Stream.value([])),
        publicProviderServicesProvider(
          'p1',
        ).overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Through builder, never by wrapping MaterialApp in a MediaQuery: that
        // overrides the surface size to zero, RenderFlex.paint returns on
        // `size.isEmpty` before reporting anything, takeException() yields null
        // and the assertion below would be green by construction.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const PublicProviderProfilePage(providerId: 'p1'),
      ),
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('the profile does not overflow at text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(rating: ratingDisplay(sum: 8, count: 2)));
      await tester.pump();
      await tester.pump();

      final error = tester.takeException();
      expect(
        error,
        isNull,
        reason:
            'a long bio and a long country name must grow the header, '
            'not overflow it',
      );
    });
  }

  testWidgets('a rated provider does not overflow either', (tester) async {
    // The resolved branch renders a different row: stars plus the named basis.
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(textScale: 2.0, rating: ratingDisplay(sum: 13, count: 3)),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
