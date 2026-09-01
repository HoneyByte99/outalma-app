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
  _basisTests();

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

// explainBasis says what the number is computed FROM. The screens that carry a
// list underneath contradict themselves without it: "3 avis" above six tiles,
// or "Nouveau" above five four- and five-star reviews.
Widget _wrapBasis({
  required RatingSource source,
  required String uid,
  required int sum,
  required int count,
  bool explainBasis = true,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      providerRatingProvider(uid).overrideWith(
        (_) => Stream.value(ratingDisplay(sum: sum, count: count)),
      ),
      clientReputationProvider(uid).overrideWith(
        (_) => Stream.value(ratingDisplay(sum: sum, count: count)),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The scale is applied through builder, not by wrapping MaterialApp: a
      // MediaQuery above it overrides the surface size to zero, RenderFlex
      // returns before reporting anything, and an overflow assertion would be
      // green by construction.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 227, // the header column of the public profile at 375 px
          child: RatingSummary(
            userId: uid,
            source: source,
            explainBasis: explainBasis,
          ),
        ),
      ),
    ),
  );
}

void _basisTests() {
  group('explainBasis', () {
    testWidgets('a rated PROVIDER names its basis', (tester) async {
      await tester.pumpWidget(
        _wrapBasis(source: RatingSource.provider, uid: 'p', sum: 13, count: 3),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('4.3'), findsOneWidget, reason: 'standalone Text');
      expect(find.textContaining('3 avis de clients'), findsOneWidget);
    });

    testWidgets('a PROVIDER below the floor names its basis too', (
      tester,
    ) async {
      // The majority case: 13 of the 15 rated providers sit here, and this is
      // the branch that sits above a list of five visible reviews.
      await tester.pumpWidget(
        _wrapBasis(source: RatingSource.provider, uid: 'p', sum: 10, count: 2),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nouveau'), findsOneWidget, reason: 'standalone Text');
      expect(find.textContaining('moins de 3 avis de clients'), findsOneWidget);
    });

    testWidgets(
      'a CLIENT below the floor gets the basis WITHOUT "de clients"',
      (tester) async {
        // A client's reputation is derived from every review received, which is
        // exactly what the list below shows. Saying "de clients" here would be
        // false.
        await tester.pumpWidget(
          _wrapBasis(source: RatingSource.client, uid: 'c', sum: 8, count: 2),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Nouveau'), findsOneWidget);
        expect(find.textContaining('moins de 3 avis'), findsOneWidget);
        expect(
          find.textContaining('de clients'),
          findsNothing,
          reason:
              'the client basis is every review received, not client reviews',
        );
      },
    );

    testWidgets('a rated CLIENT is unchanged: plain count, no basis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapBasis(source: RatingSource.client, uid: 'c', sum: 12, count: 3),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('3 avis'), findsOneWidget);
      expect(find.textContaining('de clients'), findsNothing);
    });

    testWidgets('explainBasis OFF keeps the short form', (tester) async {
      await tester.pumpWidget(
        _wrapBasis(
          source: RatingSource.provider,
          uid: 'p',
          sum: 13,
          count: 3,
          explainBasis: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('4.3'), findsOneWidget);
      expect(find.text('3 avis'), findsOneWidget);
      expect(find.textContaining('de clients'), findsNothing);
    });

    // Found by the smoke on the real app at a 200 per cent text scale: the
    // basis wraps to three lines, and with the star centered against that block
    // the screen read "moins de / Nouveau 3 avis de / clients". No overflow, so
    // no exception, and no test would have caught it. This one does: the star
    // must sit level with the FIRST line of the wrapped basis, not halfway down.
    testWidgets('at scale 2.0 the star stays level with the first line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapBasis(
          source: RatingSource.provider,
          uid: 'p',
          sum: 10,
          count: 2,
          textScale: 2.0,
        ),
      );
      await tester.pump();
      await tester.pump();

      final starTop = tester
          .getTopLeft(find.byIcon(Icons.star_border_rounded))
          .dy;
      final basisTop = tester
          .getTopLeft(find.textContaining('moins de 3 avis de clients'))
          .dy;
      final basisHeight = tester
          .getSize(find.textContaining('moins de 3 avis de clients'))
          .height;

      expect(
        basisHeight,
        greaterThan(40),
        reason: 'the basis must actually be wrapping, or this proves nothing',
      );
      expect(
        (starTop - basisTop).abs(),
        lessThan(12),
        reason: 'top aligned: a centered star would sit a whole line lower',
      );
    });

    // Both branches must wrap rather than overflow. A Row child that is not
    // flexible gets maxWidth: infinity and runs off to the RIGHT.
    for (final scale in [1.0, 2.0]) {
      testWidgets('rated basis does not overflow 227 px at scale $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapBasis(
            source: RatingSource.provider,
            uid: 'p',
            sum: 13,
            count: 3,
            textScale: scale,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('floor basis does not overflow 227 px at scale $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapBasis(
            source: RatingSource.provider,
            uid: 'p',
            sum: 10,
            count: 2,
            textScale: scale,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
