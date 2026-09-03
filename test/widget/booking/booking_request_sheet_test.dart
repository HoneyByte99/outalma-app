// Harness widget tests for BookingRequestSheet.
// The sheet depends on createBookingUseCaseProvider and geocodingServiceProvider
// (accessed only on submit/address-search), and providerBookingsForDateProvider
// (accessed only when a date is chosen). For a smoke render at step 0 (message),
// no provider overrides are required beyond a stub for createBookingUseCase.
//
// NOTE: record / audio plugin calls happen only on user interaction, not on
// initial render, so they do not crash the smoke test.

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/booking/booking_providers.dart';
import 'package:outalma_app/src/application/booking/create_booking_use_case.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/data/services/geocoding_service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/features/booking/booking_request_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCreateBookingUseCase extends Mock implements CreateBookingUseCase {}

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

Position _positionFixture({required double lat, required double lng}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026, 1, 1),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

const _dakarZone = ServiceZone(
  label: 'Dakar',
  latitude: 14.69,
  longitude: -17.44,
  radiusKm: 10,
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required List<Override> overrides,
  List<ServiceZone> serviceZones = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BookingRequestSheet(
            serviceId: 'svc_1',
            providerId: 'prov_1',
            serviceTitle: 'Test Service',
            serviceZones: serviceZones,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Base overrides every test past step 0 needs: a stubbed provider profile
/// (never paused) so `_canAdvance` never touches Firestore.
List<Override> _baseOverrides({
  required CreateBookingUseCase useCase,
  GeocodingService? geocoding,
}) => [
  createBookingUseCaseProvider.overrideWithValue(useCase),
  if (geocoding != null) geocodingServiceProvider.overrideWithValue(geocoding),
  providerProfileByIdProvider(
    'prov_1',
  ).overrideWith((ref) => Stream.value(null)),
];

Future<void> _goToAddressStep(WidgetTester tester) async {
  await tester.tap(find.text('Continuer')); // step 0 -> 1
  await tester.pump();
  await tester.tap(find.text('Continuer')); // step 1 -> 2
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(Uri.parse('https://example.test'));
  });

  group('BookingRequestSheet', () {
    testWidgets('smoke - sheet renders without throwing', (tester) async {
      await _pumpSheet(
        tester,
        overrides: [
          createBookingUseCaseProvider.overrideWithValue(
            _MockCreateBookingUseCase(),
          ),
        ],
      );
      expect(find.byType(BookingRequestSheet), findsOneWidget);
    });

    testWidgets('step indicator is present (3 dots)', (tester) async {
      await _pumpSheet(
        tester,
        overrides: [
          createBookingUseCaseProvider.overrideWithValue(
            _MockCreateBookingUseCase(),
          ),
        ],
      );
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('service title is visible in sheet header', (tester) async {
      await _pumpSheet(
        tester,
        overrides: [
          createBookingUseCaseProvider.overrideWithValue(
            _MockCreateBookingUseCase(),
          ),
        ],
      );
      expect(find.text('Test Service'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // Point 1: every error path renders an in-sheet banner, never a SnackBar
  // hidden below the modal sheet, and it stays up without closing the sheet.
  // ---------------------------------------------------------------------
  group('error banner (point 1)', () {
    testWidgets(
      'a submit refusal is visible in the sheet, without closing it',
      (tester) async {
        final useCase = _MockCreateBookingUseCase();
        final geocoding = _MockGeocodingService();
        when(() => geocoding.autocomplete(any())).thenAnswer(
          (_) async => const [
            PlaceSuggestion(placeId: 'p1', description: 'Saint-Louis, Senegal'),
          ],
        );
        when(
          () => geocoding.getPlaceLatLng('p1'),
        ).thenAnswer((_) async => (lat: 16.02, lng: -16.49, countryCode: 'SN'));

        await _pumpSheet(
          tester,
          overrides: _baseOverrides(useCase: useCase, geocoding: geocoding),
          serviceZones: const [_dakarZone],
        );
        await _goToAddressStep(tester);

        await tester.enterText(
          find.byKey(const Key('bookingAddressField')),
          'Saint-Louis',
        );
        await tester.pump();
        await tester.tap(find.text('Saint-Louis, Senegal'));
        await tester.pump();

        await tester.tap(find.text('Envoyer la demande'));
        await tester.pump();

        // The banner is up...
        expect(find.byKey(const Key('bookingErrorBanner')), findsOneWidget);
        // ...and the sheet, with its address step still on screen, was never
        // closed to show it: the whole point of point 1 is that the message
        // sits where the user can act on it, not behind a dismissed sheet.
        expect(find.byType(BookingRequestSheet), findsOneWidget);
        expect(find.text("Adresse d'intervention"), findsOneWidget);
        verifyZeroInteractions(useCase);
      },
    );

    testWidgets('dismissing the banner clears it without affecting the step', (
      tester,
    ) async {
      final useCase = _MockCreateBookingUseCase();
      final geocoding = _MockGeocodingService();
      when(() => geocoding.autocomplete(any())).thenAnswer(
        (_) async => const [
          PlaceSuggestion(placeId: 'p1', description: 'Saint-Louis, Senegal'),
        ],
      );
      when(
        () => geocoding.getPlaceLatLng('p1'),
      ).thenAnswer((_) async => (lat: 16.02, lng: -16.49, countryCode: 'SN'));
      when(
        () => useCase.call(
          providerId: any(named: 'providerId'),
          serviceId: any(named: 'serviceId'),
          requestMessage: any(named: 'requestMessage'),
          scheduledAt: any(named: 'scheduledAt'),
          schedule: any(named: 'schedule'),
          address: any(named: 'address'),
          addressLat: any(named: 'addressLat'),
          addressLng: any(named: 'addressLng'),
          addressCountryCode: any(named: 'addressCountryCode'),
          audioMessageUrl: any(named: 'audioMessageUrl'),
        ),
      ).thenThrow(Exception('boom'));

      await _pumpSheet(
        tester,
        overrides: _baseOverrides(useCase: useCase, geocoding: geocoding),
        serviceZones: const [_dakarZone],
      );
      await _goToAddressStep(tester);
      // An address is now mandatory (booking-ux wave 3): pick a suggestion so
      // it resolves, exactly like a real user would before the submit button
      // (gated on a non-empty address) is even enabled.
      await tester.enterText(
        find.byKey(const Key('bookingAddressField')),
        'Saint-Louis',
      );
      await tester.pump();
      await tester.tap(find.text('Saint-Louis, Senegal'));
      await tester.pump();

      await tester.tap(find.text('Envoyer la demande'));
      await tester.pump();
      expect(find.byKey(const Key('bookingErrorBanner')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.byKey(const Key('bookingErrorBanner')), findsNothing);
      // Still on the address step: dismissing the banner is not navigation.
      expect(find.text("Adresse d'intervention"), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // Point 2: client-side zone-coverage gate, checked before any network call.
  // ---------------------------------------------------------------------
  group('zone coverage gate (point 2)', () {
    testWidgets(
      'refuses an address outside the declared zones before calling createBooking',
      (tester) async {
        final useCase = _MockCreateBookingUseCase();
        final geocoding = _MockGeocodingService();
        when(() => geocoding.autocomplete(any())).thenAnswer(
          (_) async => const [
            PlaceSuggestion(placeId: 'p1', description: 'Saint-Louis, Senegal'),
          ],
        );
        when(
          () => geocoding.getPlaceLatLng('p1'),
        ).thenAnswer((_) async => (lat: 16.02, lng: -16.49, countryCode: 'SN'));

        await _pumpSheet(
          tester,
          overrides: _baseOverrides(useCase: useCase, geocoding: geocoding),
          serviceZones: const [_dakarZone],
        );
        await _goToAddressStep(tester);
        await tester.enterText(
          find.byKey(const Key('bookingAddressField')),
          'Saint-Louis',
        );
        await tester.pump();
        await tester.tap(find.text('Saint-Louis, Senegal'));
        await tester.pump();

        await tester.tap(find.text('Envoyer la demande'));
        await tester.pump();

        expect(
          find.textContaining('Zones couvertes : Dakar'),
          findsOneWidget,
          reason: 'the refusal names the zones the provider DOES cover',
        );
        verifyZeroInteractions(useCase);
      },
    );

    testWidgets('accepts an address inside a declared zone', (tester) async {
      final useCase = _MockCreateBookingUseCase();
      final geocoding = _MockGeocodingService();
      when(() => geocoding.autocomplete(any())).thenAnswer(
        (_) async => const [
          PlaceSuggestion(placeId: 'p1', description: 'Plateau, Dakar'),
        ],
      );
      when(
        () => geocoding.getPlaceLatLng('p1'),
      ).thenAnswer((_) async => (lat: 14.70, lng: -17.45, countryCode: 'SN'));
      when(
        () => useCase.call(
          providerId: any(named: 'providerId'),
          serviceId: any(named: 'serviceId'),
          requestMessage: any(named: 'requestMessage'),
          scheduledAt: any(named: 'scheduledAt'),
          schedule: any(named: 'schedule'),
          address: any(named: 'address'),
          addressLat: any(named: 'addressLat'),
          addressLng: any(named: 'addressLng'),
          addressCountryCode: any(named: 'addressCountryCode'),
          audioMessageUrl: any(named: 'audioMessageUrl'),
        ),
      ).thenAnswer((_) async => 'booking_1');

      await _pumpSheet(
        tester,
        overrides: _baseOverrides(useCase: useCase, geocoding: geocoding),
        serviceZones: const [_dakarZone],
      );
      await _goToAddressStep(tester);
      await tester.enterText(
        find.byKey(const Key('bookingAddressField')),
        'Plateau',
      );
      await tester.pump();
      await tester.tap(find.text('Plateau, Dakar'));
      await tester.pump();

      await tester.tap(find.text('Envoyer la demande'));
      await tester.pump();

      verify(
        () => useCase.call(
          providerId: any(named: 'providerId'),
          serviceId: any(named: 'serviceId'),
          requestMessage: any(named: 'requestMessage'),
          scheduledAt: any(named: 'scheduledAt'),
          schedule: any(named: 'schedule'),
          address: any(named: 'address'),
          addressLat: any(named: 'addressLat'),
          addressLng: any(named: 'addressLng'),
          addressCountryCode: any(named: 'addressCountryCode'),
          audioMessageUrl: any(named: 'audioMessageUrl'),
        ),
      ).called(1);
    });
  });

  // ---------------------------------------------------------------------
  // Point 3: a server-side zone refusal is localized from `details.code`.
  // ---------------------------------------------------------------------
  group('server refusal classification (point 3)', () {
    testWidgets('shows the localized zone message for a details.code refusal', (
      tester,
    ) async {
      final useCase = _MockCreateBookingUseCase();
      final geocoding = _MockGeocodingService();
      when(() => geocoding.autocomplete(any())).thenAnswer(
        (_) async => const [
          PlaceSuggestion(placeId: 'p1', description: '12 Rue Test, Senegal'),
        ],
      );
      when(
        () => geocoding.getPlaceLatLng('p1'),
      ).thenAnswer((_) async => (lat: 14.70, lng: -17.45, countryCode: 'SN'));
      when(
        () => useCase.call(
          providerId: any(named: 'providerId'),
          serviceId: any(named: 'serviceId'),
          requestMessage: any(named: 'requestMessage'),
          scheduledAt: any(named: 'scheduledAt'),
          schedule: any(named: 'schedule'),
          address: any(named: 'address'),
          addressLat: any(named: 'addressLat'),
          addressLng: any(named: 'addressLng'),
          addressCountryCode: any(named: 'addressCountryCode'),
          audioMessageUrl: any(named: 'audioMessageUrl'),
        ),
      ).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Booking address is outside the service intervention zones.',
          details: const {'code': 'BOOKING_OUTSIDE_ZONES'},
        ),
      );

      await _pumpSheet(
        tester,
        overrides: _baseOverrides(useCase: useCase, geocoding: geocoding),
      );
      await _goToAddressStep(tester);
      // A hand-typed address with no picked suggestion: the client resolves
      // it itself at submit time (booking-ux wave 3, address must be
      // exploitable), no declared zone here lets the resolved coordinates
      // through client-side, and the refusal comes from the server, exactly
      // the race this classification exists for.
      await tester.enterText(
        find.byKey(const Key('bookingAddressField')),
        '12 Rue Test',
      );
      await tester.pump();

      await tester.tap(find.text('Envoyer la demande'));
      await tester.pump();

      expect(
        find.textContaining("n'intervient pas à cette adresse"),
        findsOneWidget,
        reason: 'the English server prose must never reach the user',
      );
      expect(find.textContaining('outside the service'), findsNothing);
    });

    testWidgets('an unrelated refusal falls back to the server message', (
      tester,
    ) async {
      final useCase = _MockCreateBookingUseCase();
      final geocoding = _MockGeocodingService();
      when(() => geocoding.autocomplete(any())).thenAnswer(
        (_) async => const [
          PlaceSuggestion(placeId: 'p1', description: 'Plateau, Dakar'),
        ],
      );
      when(
        () => geocoding.getPlaceLatLng('p1'),
      ).thenAnswer((_) async => (lat: 14.70, lng: -17.45, countryCode: 'SN'));
      when(
        () => useCase.call(
          providerId: any(named: 'providerId'),
          serviceId: any(named: 'serviceId'),
          requestMessage: any(named: 'requestMessage'),
          scheduledAt: any(named: 'scheduledAt'),
          schedule: any(named: 'schedule'),
          address: any(named: 'address'),
          addressLat: any(named: 'addressLat'),
          addressLng: any(named: 'addressLng'),
          addressCountryCode: any(named: 'addressCountryCode'),
          audioMessageUrl: any(named: 'audioMessageUrl'),
        ),
      ).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Un blocage existe entre vous et ce prestataire.',
        ),
      );

      await _pumpSheet(
        tester,
        overrides: _baseOverrides(useCase: useCase, geocoding: geocoding),
      );
      await _goToAddressStep(tester);
      // Address is now mandatory: fill it in before the send button, gated on
      // a non-empty address, is even enabled.
      await tester.enterText(
        find.byKey(const Key('bookingAddressField')),
        'Plateau',
      );
      await tester.pump();
      await tester.tap(find.text('Plateau, Dakar'));
      await tester.pump();

      await tester.tap(find.text('Envoyer la demande'));
      await tester.pump();

      expect(
        find.text('Un blocage existe entre vous et ce prestataire.'),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------
  // Point 4: "use my location" and saved addresses at step 3.
  // ---------------------------------------------------------------------
  group('location shortcuts at step 3 (point 4)', () {
    testWidgets('use my location fills the address from a reverse geocode', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        position: _positionFixture(lat: 14.6928, lng: -17.4467),
      );
      final geocoding = _MockGeocodingService();
      when(
        () => geocoding.reverseGeocode(14.6928, -17.4467),
      ).thenAnswer((_) async => 'Plateau, Dakar, Senegal');

      await _pumpSheet(
        tester,
        overrides: _baseOverrides(
          useCase: _MockCreateBookingUseCase(),
          geocoding: geocoding,
        ),
      );
      await _goToAddressStep(tester);

      await tester.tap(find.text('Utiliser ma position'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Plateau, Dakar, Senegal'), findsOneWidget);
      // Coordinates are known now: the save-this-address action appears.
      expect(find.byTooltip('Enregistrer cette adresse'), findsOneWidget);
    });

    testWidgets(
      'tapping a saved address fills the field with no network call',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'saved_locations': jsonEncode([
            {
              'label': 'Maison',
              'address': 'Ouakam, Dakar',
              'lat': 14.73,
              'lng': -17.49,
              'radiusKm': 30.0,
            },
          ]),
        });

        await _pumpSheet(
          tester,
          overrides: _baseOverrides(useCase: _MockCreateBookingUseCase()),
        );
        await _goToAddressStep(tester);
        // Let the NotifierProvider's async _load() settle.
        await tester.pump();

        expect(find.text('Maison'), findsOneWidget);
        await tester.tap(find.text('Maison'));
        await tester.pump();

        expect(find.text('Ouakam, Dakar'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------
  // Booking-ux wave 3: the address is mandatory (the provider always
  // travels to the client, CADRAGE) and must be exploitable (geocoded), not
  // merely non-empty, because the zone/Senegal gates need coordinates to run.
  // ---------------------------------------------------------------------
  group('address required and exploitable (booking-ux wave 3)', () {
    testWidgets(
      'the send button stays disabled with an empty address, and re-enables '
      'once text is entered',
      (tester) async {
        await _pumpSheet(
          tester,
          overrides: _baseOverrides(useCase: _MockCreateBookingUseCase()),
        );
        await _goToAddressStep(tester);

        ElevatedButton sendButton() => tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Envoyer la demande'),
        );

        expect(
          sendButton().onPressed,
          isNull,
          reason: 'no address yet: the request cannot be planned',
        );

        await tester.enterText(
          find.byKey(const Key('bookingAddressField')),
          'Plateau',
        );
        await tester.pump();

        expect(sendButton().onPressed, isNotNull);
      },
    );

    testWidgets(
      'a disabled send button tells the user the address is missing, not '
      'just a dead control',
      (tester) async {
        await _pumpSheet(
          tester,
          overrides: _baseOverrides(useCase: _MockCreateBookingUseCase()),
        );
        await _goToAddressStep(tester);

        // Empty field: the reason the button is dead is spelled out on
        // screen, the exact defect Amath flagged and the previous wave fixed
        // for the error banner (point 1) must not come back here.
        expect(
          find.byKey(const Key('bookingAddressRequiredHint')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('bookingAddressField')),
          'Plateau',
        );
        await tester.pump();

        expect(
          find.byKey(const Key('bookingAddressRequiredHint')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a hand-typed address that cannot be geocoded blocks submission with '
      'an explanation, and never reaches createBooking',
      (tester) async {
        final useCase = _MockCreateBookingUseCase();
        final geocoding = _MockGeocodingService();
        // Autocomplete finds nothing for this text: geocoding at submit time
        // (the same fallback _selectSuggestion's path feeds) has nothing to
        // resolve, so the address stays unexploitable.
        when(
          () => geocoding.autocomplete(any()),
        ).thenAnswer((_) async => const []);

        await _pumpSheet(
          tester,
          overrides: _baseOverrides(useCase: useCase, geocoding: geocoding),
        );
        await _goToAddressStep(tester);
        await tester.enterText(
          find.byKey(const Key('bookingAddressField')),
          'Zzqxvw Unfindable Street',
        );
        await tester.pump();

        await tester.tap(find.text('Envoyer la demande'));
        await tester.pump();

        expect(
          find.text(
            'Adresse introuvable. Choisissez une suggestion dans la liste '
            'ou utilisez votre position.',
          ),
          findsOneWidget,
        );
        verifyZeroInteractions(useCase);
      },
    );
  });
}
