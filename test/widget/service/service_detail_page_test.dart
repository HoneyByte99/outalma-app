// Harness widget tests for ServiceDetailPage.
// Overrides serviceDetailProvider to emit a fake Service; overrides
// authNotifierProvider so the page does not crash on Firebase init.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/features/service/service_detail_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

final _fakeService = Service(
  id: 'svc_test',
  providerId: 'prov_1',
  categoryId: CategoryId.menage,
  title: 'Ménage à domicile',
  photos: [],
  priceType: PriceType.fixed,
  price: 5000, // 50.00€ in cents
  published: true,
  serviceZones: [],
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Widget _wrap() => ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        activeModeProvider.overrideWith((_) => ActiveMode.client),
        serviceDetailProvider('svc_test')
            .overrideWith((_) => Stream.value(_fakeService)),
        userByIdProvider('prov_1').overrideWith((_) => const Stream.empty()),
        reviewsForUserProvider('prov_1')
            .overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ServiceDetailPage(serviceId: 'svc_test'),
      ),
    );

void main() {
  group('ServiceDetailPage', () {
    testWidgets('smoke — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      expect(find.byType(ServiceDetailPage), findsOneWidget);
    });

    testWidgets('service title is visible', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      expect(find.text('Ménage à domicile'), findsWidgets);
    });

    testWidgets('book CTA (ElevatedButton) is present for non-owner',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      expect(find.byType(ElevatedButton), findsWidgets);
    });
  });
}
