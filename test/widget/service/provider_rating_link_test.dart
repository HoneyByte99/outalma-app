import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/review/rating_summary.dart';
import 'package:outalma_app/src/features/service/service_detail_page.dart';

/// The rating on the service detail is a tap target of its own, opening the
/// reviews of THIS provider. Two claims live here and both are budget lines:
/// it must be reachable as a distinct target (A5) and at least 44 px (A2).
void main() {
  Widget wrap(RatingDisplay rating, {required List<GoRoute> extra}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: ProviderRatingLink(providerId: 'prov_1')),
        ),
        ...extra,
      ],
    );
    return ProviderScope(
      overrides: [
        providerRatingProvider(
          'prov_1',
        ).overrideWith((_) => Stream.value(rating)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('it shows the average and opens this provider reviews', (
    tester,
  ) async {
    String? landed;
    await tester.pumpWidget(
      wrap(
        ratingDisplay(sum: 12, count: 3),
        extra: [
          GoRoute(
            path: '/reviews/:uid',
            builder: (_, state) {
              landed = state.uri.toString();
              return const Scaffold(body: Text('reviews'));
            },
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('4.0'), findsOneWidget);

    await tester.tap(find.text('Voir les avis'));
    await tester.pumpAndSettle();
    expect(
      landed,
      '/reviews/prov_1?as=provider',
      reason: 'the link must carry WHICH reputation the page shows',
    );
  });

  testWidgets('the tap target is at least 44 high (A2)', (tester) async {
    await tester.pumpWidget(wrap(ratingDisplay(sum: 12, count: 3), extra: []));
    await tester.pump();
    await tester.pump();

    final size = tester.getSize(
      find.descendant(
        of: find.byType(ProviderRatingLink),
        matching: find.byType(InkWell),
      ),
    );
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a provider below the floor reads "Nouveau", not a number', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(ratingDisplay(sum: 10, count: 2), extra: []));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.textContaining('5.0'), findsNothing);
  });

  testWidgets('it says nothing at all while the read is in flight (U1)', (
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
          home: const Scaffold(body: ProviderRatingLink(providerId: 'prov_1')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nouveau'), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('the count is never capped for a provider', (tester) async {
    // "50+" belongs to the client window. Showing it here while the card and
    // the reviews page show "(60)" is the disagreement this lot closes.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRatingProvider('p60').overrideWith(
            (_) => Stream.value(ratingDisplay(sum: 240, count: 60)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RatingSummary(userId: 'p60', source: RatingSource.provider),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('50+'), findsNothing);
    expect(find.textContaining('60'), findsOneWidget);
  });
}
