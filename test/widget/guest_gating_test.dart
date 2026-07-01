// Lot 5: login-gated actions on guest-reachable surfaces.
//
// A signed-out guest can browse, but the two engagement actions - booking a
// service and switching to provider mode - must nudge to sign-in instead of
// proceeding. Both use context.push, so these tests wire a minimal GoRouter
// with a /sign-in destination.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/public_profile_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/features/booking/booking_request_sheet.dart';
import 'package:outalma_app/src/features/service/service_detail_page.dart';
import 'package:outalma_app/src/features/shared/mode_badge.dart';

class _GuestAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

const _signInMarker = 'SIGN-IN-SCREEN';

Widget _harness(Widget home, List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (_, __) => home),
      GoRoute(
        // Matches AppRoutes.signIn.
        path: '/sign-in',
        builder: (_, __) => const Scaffold(body: Text(_signInMarker)),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

final _service = Service(
  id: 'svc_test',
  providerId: 'prov_1',
  categoryId: CategoryId.menage,
  title: 'Menage a domicile',
  photos: const [],
  priceType: PriceType.fixed,
  price: 5000,
  published: true,
  serviceZones: const [],
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

void main() {
  group('booking is login-gated for guests', () {
    Widget build() => _harness(const ServiceDetailPage(serviceId: 'svc_test'), [
      authNotifierProvider.overrideWith(() => _GuestAuthNotifier()),
      activeModeProvider.overrideWith((_) => ActiveMode.client),
      serviceDetailProvider(
        'svc_test',
      ).overrideWith((_) => Stream.value(_service)),
      publicProfileByIdProvider(
        'prov_1',
      ).overrideWith((_) => Stream.value(null)),
      reviewsForUserProvider('prov_1').overrideWith((_) => Stream.value([])),
    ]);

    testWidgets('tapping Book opens the auth prompt, not the booking sheet', (
      tester,
    ) async {
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Request this service'),
      );
      await tester.pumpAndSettle(); // auth prompt sheet slides up

      // The auth prompt (reason + sign-in action) shows; booking sheet does not.
      expect(find.text('Sign in to book this service.'), findsOneWidget);
      expect(find.byType(BookingRequestSheet), findsNothing);

      // Choosing "Sign in" routes to sign-in (with the return path).
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text(_signInMarker), findsOneWidget);
    });
  });

  group('provider-mode switch is login-gated for guests', () {
    Widget build() => _harness(
      const Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: ModeBadge(),
        ),
      ),
      [
        authNotifierProvider.overrideWith(() => _GuestAuthNotifier()),
        activeModeProvider.overrideWith((_) => ActiveMode.client),
      ],
    );

    testWidgets('tapping the mode badge opens the auth prompt', (tester) async {
      await tester.pumpWidget(build());
      await tester.pump();

      await tester.tap(find.byType(ModeBadge));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to offer your services.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text(_signInMarker), findsOneWidget);
    });
  });
}
