import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/identity/identity_trust_providers.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/provider/public_provider_profile_page.dart';

/// The public profile is the screen a client opens to decide. It used to
/// compute its own average with no floor, so a provider with two five-star
/// reviews read "Nouveau" on the card and "5.0 (2)" here, and it kept counting
/// reviews a moderator had hidden.
void main() {
  Widget wrap(int sum, int count) => ProviderScope(
    overrides: [
      userByIdProvider('p1').overrideWith((_) => Stream.value(null)),
      providerProfileByIdProvider('p1').overrideWith((_) => Stream.value(null)),
      providerRatingProvider('p1').overrideWith(
        (_) => Stream.value(ratingDisplay(sum: sum, count: count)),
      ),
      identityTrustProvider('p1').overrideWith((_) => Stream.value(null)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ProfileHeader(providerId: 'p1')),
    ),
  );

  testWidgets('it shows the same average as the card, from the aggregate', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(48, 12));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('4.0'), findsOneWidget);
  });

  testWidgets('two five-star reviews do NOT become "5.0 (2)" here', (
    tester,
  ) async {
    // The exact disagreement this increment closes: below the floor, this
    // screen must say what the card says.
    await tester.pumpWidget(wrap(10, 2));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('5.0'), findsNothing);
    expect(
      find.text('Nouveau'),
      findsOneWidget,
      reason: 'the four surfaces must say the same thing for the same uid',
    );
  });

  testWidgets('the header names its basis and drops the negative sentence', (
    tester,
  ) async {
    // Two things at once, because they land on the same line of the header:
    // the rating now says what it counted, and the full pill with its
    // "Identite non verifiee" sentence is gone, replaced by a badge.
    await tester.pumpWidget(wrap(13, 3));
    await tester.pump();
    await tester.pump();

    expect(find.text('4.3'), findsOneWidget);
    expect(find.textContaining('3 avis de clients'), findsOneWidget);
    expect(
      find.text('Identité non vérifiée'),
      findsNothing,
      reason: 'the sentence taught every client that nobody is trustworthy',
    );
    expect(
      find.bySemanticsLabel('Identité non vérifiée'),
      findsOneWidget,
      reason: 'a screen reader still gets the full state (A5)',
    );
  });

  testWidgets('below the floor the header explains itself', (tester) async {
    await tester.pumpWidget(wrap(8, 2));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.textContaining('moins de 3 avis de clients'), findsOneWidget);
  });
}
