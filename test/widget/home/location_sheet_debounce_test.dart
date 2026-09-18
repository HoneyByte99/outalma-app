// The home location sheet must query Places ONCE per typed address, when the
// user stops typing, and must never reopen the suggestion list on top of a
// choice the user already made.
//
// Every sequence below is deliberate. A pending Timer schedules no frame, so
// `pumpAndSettle` never reaches it; and a test that lets the delay elapse
// BEFORE the choice has nothing left to cancel, so it would pass with or
// without the guard it claims to cover.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/core/utils/debouncer.dart';
import 'package:outalma_app/src/data/services/geocoding_service.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/keyboard.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

class _MockGeocodingService extends Mock implements GeocodingService {}

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({required this.position});
  final Position position;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Future.value(position);
}

Position _positionFixture() => Position(
  latitude: 14.6928,
  longitude: -17.4467,
  timestamp: DateTime(2026, 1, 1),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

const _suggestions = [
  PlaceSuggestion(placeId: 'p1', description: 'Dakar, Senegal'),
  PlaceSuggestion(placeId: 'p2', description: 'Dakar Plateau, Senegal'),
  PlaceSuggestion(placeId: 'p3', description: 'Dakar Medina, Senegal'),
  PlaceSuggestion(placeId: 'p4', description: 'Dakar Almadies, Senegal'),
  PlaceSuggestion(placeId: 'p5', description: 'Dakar Yoff, Senegal'),
];

/// The second entry, always built by the ListView. The last one needs a
/// scrollUntilVisible, so asserting its absence would stay true even when the
/// list HAS reopened, and the guard would survive its own mutation.
const _otherSuggestion = 'Dakar Plateau, Senegal';

Widget _wrap({
  required GeocodingService geocoding,
  required ValueNotifier<double> keyboard,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.client),
    serviceListProvider.overrideWith((_) => Stream.value(const [])),
    geocodingServiceProvider.overrideWithValue(geocoding),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fr'),
    builder: keyboardInsetBuilder(keyboard),
    home: shellLike(const HomePage()),
  ),
);

/// Crosses the debounce delay. `pump()` and `pumpAndSettle()` cannot: a
/// pending Timer schedules no frame.
Future<void> _settleDebounce(WidgetTester tester) async {
  await tester.pump(kAddressSearchDebounce + const Duration(milliseconds: 50));
  await tester.pump();
}

/// Opens the sheet and returns its address field.
Future<Finder> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Tout le Sénégal'));
  await tester.pumpAndSettle();
  // Home search bar + sheet field: the sheet's one is the last.
  return find.byType(TextField).last;
}

_MockGeocodingService _stubbedGeocoding() {
  final geocoding = _MockGeocodingService();
  when(
    () => geocoding.autocomplete(any()),
  ).thenAnswer((_) async => _suggestions);
  when(
    () => geocoding.getPlaceLatLng(any()),
  ).thenAnswer((_) async => (lat: 14.69, lng: -17.44, countryCode: 'SN'));
  return geocoding;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a burst of keystrokes queries Places once, with the last text', (
    tester,
  ) async {
    useSurface(tester, kReferenceSurface);
    final geocoding = _stubbedGeocoding();
    await tester.pumpWidget(
      _wrap(geocoding: geocoding, keyboard: ValueNotifier<double>(0)),
    );
    await tester.pump();
    final field = await _openSheet(tester);

    // Cumulative: enterText REPLACES the content, so a literal 'D','a','k'
    // would never exceed the minimum length and nothing would ever fire.
    for (final text in ['D', 'Da', 'Dak', 'Daka', 'Dakar']) {
      await tester.enterText(field, text);
    }
    await _settleDebounce(tester);

    // Captured, not verified against a literal: `verify(autocomplete('Dakar'))`
    // only counts the invocations that MATCH, so it stays green when the four
    // intermediate calls also go out, which is exactly the bug being guarded.
    final captured = verify(
      () => geocoding.autocomplete(captureAny()),
    ).captured;
    expect(captured, ['Dakar']);
  });

  testWidgets('nothing is queried before the user stops typing', (
    tester,
  ) async {
    useSurface(tester, kReferenceSurface);
    final geocoding = _stubbedGeocoding();
    await tester.pumpWidget(
      _wrap(geocoding: geocoding, keyboard: ValueNotifier<double>(0)),
    );
    await tester.pump();
    final field = await _openSheet(tester);

    await tester.enterText(field, 'Dakar');
    // Half the delay: the user is still typing.
    await tester.pump(const Duration(milliseconds: 175));

    verifyNever(() => geocoding.autocomplete(any()));
  });

  testWidgets('picking a suggestion does not let the list reopen on top of it', (
    tester,
  ) async {
    useSurface(tester, kReferenceSurface);
    final geocoding = _stubbedGeocoding();
    await tester.pumpWidget(
      _wrap(geocoding: geocoding, keyboard: ValueNotifier<double>(0)),
    );
    await tester.pump();
    final field = await _openSheet(tester);

    await tester.enterText(field, 'Dakar');
    await _settleDebounce(tester);
    expect(find.text(_otherSuggestion), findsOneWidget);

    // One more keystroke RE-ARMS the timer while the previous list is still on
    // screen. Without this the delay would already have elapsed at tap time,
    // there would be nothing left to cancel, and this test would pass with the
    // guard removed.
    await tester.enterText(field, 'Dakar P');
    await tester.tap(find.text('Dakar, Senegal'));
    await tester.pump();

    await _settleDebounce(tester);

    expect(
      find.text(_otherSuggestion),
      findsNothing,
      reason: 'the in-flight query was cancelled when the user chose',
    );
  });

  testWidgets('using the current position does not let the list reopen', (
    tester,
  ) async {
    useSurface(tester, kReferenceSurface);
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      position: _positionFixture(),
    );
    final geocoding = _stubbedGeocoding();
    when(
      () => geocoding.reverseGeocode(any(), any()),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(
      _wrap(geocoding: geocoding, keyboard: ValueNotifier<double>(0)),
    );
    await tester.pump();
    final field = await _openSheet(tester);

    await tester.enterText(field, 'Dakar');
    await _settleDebounce(tester);
    expect(find.text(_otherSuggestion), findsOneWidget);

    // Re-arm, then take the shortcut instead of a suggestion.
    await tester.enterText(field, 'Dakar P');
    await tester.tap(find.text('Utiliser ma position'));
    await tester.pumpAndSettle();

    await _settleDebounce(tester);

    expect(
      find.text(_otherSuggestion),
      findsNothing,
      reason: 'the shortcut is a choice too: the pending query must be dropped',
    );
  });

  testWidgets('closing the sheet drops the pending query', (tester) async {
    useSurface(tester, kReferenceSurface);
    final geocoding = _stubbedGeocoding();
    await tester.pumpWidget(
      _wrap(geocoding: geocoding, keyboard: ValueNotifier<double>(0)),
    );
    await tester.pump();
    final field = await _openSheet(tester);

    await tester.enterText(field, 'Dakar');
    // Tear the tree down BEFORE the delay elapses, then let it elapse: the
    // order is the whole point, a dispose() that does not cancel would fire on
    // an unmounted State.
    await tester.pumpWidget(const SizedBox.shrink());
    await _settleDebounce(tester);

    verifyNever(() => geocoding.autocomplete(any()));
  });
}
