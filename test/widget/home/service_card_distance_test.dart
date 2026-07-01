// Widget tests for the service card distance line on HomePage.
//
// The location filter already computes distance to decide which services
// match; these tests lock in that the distance is now surfaced on the card
// (strong line, next to price) when a filter is active, and hidden otherwise.
//
// Overrides: authNotifierProvider (unauthenticated guest), activeModeProvider
// (client), serviceListProvider (one Paris service), userByIdProvider and
// reviewsForUserProvider (avoid Firestore), locationFilterProvider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/home/location_providers.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/features/home/home_page.dart';

import '../../helpers/factories.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

const _parisZone = ServiceZone(
  label: 'Paris',
  latitude: 48.8566,
  longitude: 2.3522,
  radiusKm: 20,
);

Widget _wrap({LocationFilter? filter}) {
  final service = makeTestService(
    title: 'Ménage Paris',
  ).copyWith(serviceZones: const [_parisZone]);

  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
      activeModeProvider.overrideWith((_) => ActiveMode.client),
      serviceListProvider.overrideWith((_) => Stream.value([service])),
      userByIdProvider.overrideWith(
        (ref, uid) => Stream.value(makeTestUser(displayName: 'Awa')),
      ),
      reviewsForUserProvider.overrideWith((ref, id) => Stream.value(const [])),
      locationFilterProvider.overrideWith((_) => filter),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    ),
  );
}

void main() {
  group('service card distance', () {
    testWidgets('shows a distance when a location filter is active', (
      tester,
    ) async {
      // Filter centred right on the service's Paris zone -> "0 m".
      await tester.pumpWidget(
        _wrap(
          filter: const LocationFilter(
            label: 'Paris',
            lat: 48.8566,
            lng: 2.3522,
            radiusKm: 20,
          ),
        ),
      );
      await tester.pump();

      // A metre/kilometre suffixed label is present on the card.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              (w.data!.endsWith(' m') || w.data!.endsWith(' km')),
        ),
        findsWidgets,
      );
    });

    testWidgets('hides the distance when no location filter is set', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(filter: null));
      await tester.pump();

      // The service still renders...
      expect(find.text('Ménage Paris'), findsOneWidget);
      // ...but no distance suffix is shown.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              (w.data!.endsWith(' m') || w.data!.endsWith(' km')),
        ),
        findsNothing,
      );
    });
  });
}
