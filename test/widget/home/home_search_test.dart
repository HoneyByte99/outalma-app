// Harness widget tests for HomePage.
// Overrides: authNotifierProvider (unauthenticated), serviceListProvider
// (empty list → renders empty state), activeModeProvider.
// The search TextField is rendered unconditionally in _SearchBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/features/home/home_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

Widget _wrap({List<Service> services = const []}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.client),
    serviceListProvider.overrideWith((_) => Stream.value(services)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HomePage(),
  ),
);

void main() {
  group('HomePage : search', () {
    testWidgets('smoke : renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('search TextField is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('empty state renders when service list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(services: []));
      // Allow stream to emit
      await tester.pump();
      await tester.pump();
      // Empty state shows a search-off icon
      expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
    });
  });

  // On a phone keyboard in Senegal, typing without accents is the common case.
  // TWO cases, deliberately mirrored: with only the first, folding the title
  // alone passes and the mutation "fold removed on the query side" survives.
  group('HomePage: accent-insensitive search', () {
    testWidgets('an UNACCENTED query finds an ACCENTED title', (tester) async {
      await tester.pumpWidget(_wrap(services: [_service('Ménage complet')]));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'menage');
      // The search bar debounces by 150 ms: without advancing the clock the
      // query never reaches the provider, the filter never runs, and the two
      // mirror assertions below pass whether the fold works or not.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(
        find.text('Ménage complet'),
        findsOneWidget,
        reason: 'the fold must apply to the TITLE side',
      );
    });

    testWidgets('an ACCENTED query finds an UNACCENTED title', (tester) async {
      await tester.pumpWidget(_wrap(services: [_service('Menage express')]));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Ménage');
      // The search bar debounces by 150 ms: without advancing the clock the
      // query never reaches the provider, the filter never runs, and the two
      // mirror assertions below pass whether the fold works or not.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(
        find.text('Menage express'),
        findsOneWidget,
        reason: 'the fold must apply to the QUERY side too',
      );
    });

    testWidgets('a query that matches nothing still filters everything out', (
      tester,
    ) async {
      // Guards the other direction: the fold must not turn the filter into a
      // pass-through that matches everything.
      await tester.pumpWidget(_wrap(services: [_service('Ménage complet')]));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'plomberie');
      // The search bar debounces by 150 ms: without advancing the clock the
      // query never reaches the provider, the filter never runs, and the two
      // mirror assertions below pass whether the fold works or not.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Ménage complet'), findsNothing);
    });
  });
}

Service _service(String title) => Service(
  id: 'svc_${title.hashCode}',
  providerId: 'prov_1',
  categoryId: CategoryId.menage,
  title: title,
  photos: const [],
  priceType: PriceType.hourly,
  price: 2500,
  published: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);
