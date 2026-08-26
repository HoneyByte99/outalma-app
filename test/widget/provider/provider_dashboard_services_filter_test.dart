// Widget test for the MVP defensive filter on the provider dashboard's
// "Mes services" list: only services whose category is visible in the MVP
// client filter (menage, cuisine, gardeEnfants, repassage) must be shown.
// Legacy/off-MVP services must not leak into the provider's own view.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/identity/identity_trust_providers.dart';
import 'package:outalma_app/src/application/notification/notification_providers.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/provider_profile.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/features/provider/provider_dashboard_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'prov_1',
      displayName: 'Provider User',
      email: 'prov@test.com',
      country: 'SN',
      activeMode: ActiveMode.provider,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

Service _service(String id, String title, CategoryId category) => Service(
  id: id,
  providerId: 'prov_1',
  categoryId: category,
  title: title,
  photos: const [],
  priceType: PriceType.hourly,
  price: 2000,
  published: true,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Widget _wrap(List<Service> services) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.provider),
    currentProviderProfileProvider.overrideWith(
      (_) => Stream.value(
        ProviderProfile(
          uid: 'prov_1',
          active: true,
          suspended: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      ),
    ),
    providerServicesProvider.overrideWith((_) => Stream.value(services)),
    providerStatsProvider.overrideWithValue(
      const ProviderStats(
        bookingsThisMonth: 0,
        acceptanceRate: null,
        upcomingThisWeek: 0,
      ),
    ),
    ratingSummaryProvider(
      'prov_1',
    ).overrideWith((_) => Stream.value((average: 0.0, count: 0))),
    identityTrustProvider('prov_1').overrideWith((_) => Stream.value(null)),
    unreadNotificationsCountProvider.overrideWithValue(0),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ProviderDashboardPage(),
  ),
);

void main() {
  group('ProviderDashboardPage MVP services filter', () {
    // Tall surface so the lazily-built SliverList lays out every visible tile
    // (otherwise a below-the-fold tile is never built and can't be found).
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    testWidgets('hides off-MVP services, keeps MVP ones', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap([
          _service('s1', 'Menage complet', CategoryId.menage),
          _service('s2', 'Plomberie urgente', CategoryId.plomberie),
          _service('s3', 'Repassage hebdo', CategoryId.repassage),
          _service('s4', 'Jardinage', CategoryId.jardinage),
        ]),
      );
      await tester.pump();
      await tester.pump();

      // MVP categories are shown.
      expect(find.text('Menage complet'), findsOneWidget);
      expect(find.text('Repassage hebdo'), findsOneWidget);
      // Off-MVP categories are filtered out of the provider's own view.
      expect(find.text('Plomberie urgente'), findsNothing);
      expect(find.text('Jardinage'), findsNothing);
    });

    testWidgets('only off-MVP services falls back to the empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([
          _service('s1', 'Plomberie urgente', CategoryId.plomberie),
          _service('s2', 'Electricite', CategoryId.electricite),
        ]),
      );
      await tester.pump();
      await tester.pump();

      // No visible service -> nothing off-MVP leaks, empty CTA drives creation.
      expect(find.text('Plomberie urgente'), findsNothing);
      expect(find.text('Electricite'), findsNothing);
      // The "create first service" empty state is shown instead.
      expect(find.byIcon(Icons.add_box_outlined), findsOneWidget);
    });
  });
}
