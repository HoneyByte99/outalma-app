// The location line on a REAL service card, in a REAL grid.
//
// The pure rule is tested in test/features/shared/service_location_label_test.
// What is tested HERE is the thing that rule cannot see: the card height is
// FIXED by childAspectRatio and the image above the info block is Expanded, so
// a line added to the info block is paid for in pixels somewhere. At 375 px on
// two columns, with a 200 percent text scale, that is where an overflow lands.
//
// These assertions render HomePage rather than a replica of the card. A replica
// would keep passing after the real card changed, which is the failure mode
// this file exists to prevent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/home/location_providers.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/features/home/home_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

const _plateau = ServiceZone(
  label: 'Dakar Plateau',
  latitude: 14.6693,
  longitude: -17.4381,
  radiusKm: 10,
);
const _rufisque = ServiceZone(
  label: 'Rufisque',
  latitude: 14.7167,
  longitude: -17.2667,
  radiusKm: 15,
);

/// The longest zone label a Senegalese or French provider plausibly types.
/// Chosen deliberately: a short "Dakar" would fit anything and prove nothing.
const _longLabel = ServiceZone(
  label: 'Sacre-Coeur 3 Extension VDN',
  latitude: 14.7,
  longitude: -17.46,
  radiusKm: 12,
);

Service _service(
  String title, {
  List<ServiceZone> zones = const [_plateau],
  PriceType priceType = PriceType.monthly,
  int price = 500000,
  int? priceMax = 900000,
}) => Service(
  id: 's-$title',
  providerId: 'p1',
  categoryId: CategoryId.menage,
  title: title,
  photos: const [],
  priceType: priceType,
  price: price,
  priceMax: priceMax,
  published: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  serviceZones: zones,
);

Widget _wrap({
  required List<Service> services,
  LocationFilter? filter,
  double textScale = 1.0,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.client),
    serviceListProvider.overrideWith((_) => Stream.value(services)),
    locationFilterProvider.overrideWith((_) => filter),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const HomePage(),
  ),
);

/// A filter sitting on Dakar Plateau, wide enough to keep every fixture in.
const _plateauFilter = LocationFilter(
  label: 'Dakar Plateau',
  lat: 14.6693,
  lng: -17.4381,
  radiusKm: 50,
);

void main() {
  /// 375 x 812 at a device pixel ratio of 1: the narrow end of the matrix
  /// (budget line C1), which is where two columns leave about 139 px of usable
  /// card width.
  Future<void> pumpAt375(
    WidgetTester tester,
    Widget widget, {
    double height = 812,
  }) async {
    tester.view.physicalSize = Size(375, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump();
  }

  group('the card says where the service is', () {
    testWidgets('with NO filter: the zone alone, no distance', (tester) async {
      await pumpAt375(tester, _wrap(services: [_service('Menage')]));

      expect(find.text('Dakar Plateau'), findsOneWidget);
      expect(
        find.textContaining('km'),
        findsNothing,
        reason: 'no reference point, so no number can be honest',
      );
      // The pin, for a client who does not read the label.
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('with a filter: the zone AND the distance', (tester) async {
      await pumpAt375(
        tester,
        _wrap(services: [_service('Menage')], filter: _plateauFilter),
      );

      expect(find.text('Dakar Plateau · 0.0 km'), findsOneWidget);
    });

    testWidgets('multi-zone with a filter: the CLOSEST zone is the one shown', (
      tester,
    ) async {
      // Rufisque is listed first, the filter sits on Dakar Plateau.
      await pumpAt375(
        tester,
        _wrap(
          services: [
            _service('Menage', zones: [_rufisque, _plateau]),
          ],
          filter: _plateauFilter,
        ),
      );

      expect(find.textContaining('Dakar Plateau ·'), findsOneWidget);
      expect(find.textContaining('Rufisque'), findsNothing);
    });

    testWidgets('multi-zone with NO filter: the first zone plus the count', (
      tester,
    ) async {
      await pumpAt375(
        tester,
        _wrap(
          services: [
            _service('Menage', zones: [_rufisque, _plateau]),
          ],
        ),
      );

      expect(find.text('Rufisque +1'), findsOneWidget);
    });

    testWidgets('a service with no zone renders no location line at all', (
      tester,
    ) async {
      await pumpAt375(
        tester,
        _wrap(services: [_service('Menage', zones: const [])]),
      );

      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });
  });

  // Any RenderFlex overflow throws during pump and fails these tests on its
  // own. The explicit assertion that the label is FOUND is what stops the test
  // from passing because the line silently stopped rendering.
  group('no overflow at the hard end of the matrix', () {
    testWidgets('375 px, 100 percent text scale, worst-case content', (
      tester,
    ) async {
      await pumpAt375(
        tester,
        _wrap(
          // The widest price label the app can build, the longest plausible
          // zone label, and a title that needs both its lines.
          services: [
            _service(
              'Menage complet appartement 3 pieces',
              zones: [_longLabel, _rufisque],
            ),
            _service('Repassage', zones: [_plateau]),
          ],
          filter: _plateauFilter,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.place_outlined), findsNWidgets(2));
    });

    testWidgets('375 px, 200 percent text scale, worst-case content', (
      tester,
    ) async {
      // A6 is a CIBLE line: the label ellipsises here rather than pushing the
      // card, exactly like the price above it. What must NOT happen is an
      // overflow, and that is what this asserts.
      await pumpAt375(
        tester,
        _wrap(
          services: [
            _service(
              'Menage complet appartement 3 pieces',
              zones: [_longLabel, _rufisque],
            ),
            _service('Repassage', zones: [_plateau]),
          ],
          filter: _plateauFilter,
          textScale: 2.0,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byIcon(Icons.place_outlined),
        findsNWidgets(2),
        reason: 'the line must still render at 200 percent, not be dropped',
      );
    });

    testWidgets('200 percent text scale with NO filter, zone label only', (
      tester,
    ) async {
      await pumpAt375(
        tester,
        _wrap(
          services: [
            _service('Menage complet', zones: [_longLabel]),
          ],
          textScale: 2.0,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('three columns above 700 px stay clean too', (tester) async {
      // The grid switches to three columns over 700 px, which makes each card
      // NARROWER in absolute terms than the two-column 375 px case is not, but
      // the aspect ratio changes with it: worth one pass.
      tester.view.physicalSize = const Size(760, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          services: [
            _service('Menage complet appartement', zones: [_longLabel]),
            _service('Repassage', zones: [_plateau, _rufisque]),
            _service('Jardinage', zones: [_rufisque]),
          ],
          filter: _plateauFilter,
          textScale: 2.0,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.place_outlined), findsNWidgets(3));
    });
  });
}
