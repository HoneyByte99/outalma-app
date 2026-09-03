// Tests for evaluateServiceZoneCoverage (CADRAGE booking-ux point 2): the
// client-side mirror of the server's zone-coverage gate in createBooking.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/utils/service_zone_check.dart';

const _dakar = ServiceZone(
  label: 'Dakar',
  latitude: 14.69,
  longitude: -17.44,
  radiusKm: 10,
);

void main() {
  group('evaluateServiceZoneCoverage', () {
    test('ok when no zones are declared (provider discretion)', () {
      final result = evaluateServiceZoneCoverage(
        zones: const [],
        lat: 48.85,
        lng: 2.35,
      );
      expect(result, ServiceZoneCoverage.ok);
    });

    test('ok when coordinates are unknown (nothing to judge by)', () {
      final result = evaluateServiceZoneCoverage(
        zones: const [_dakar],
        lat: null,
        lng: null,
      );
      expect(result, ServiceZoneCoverage.ok);
    });

    test('ok when only lat is known', () {
      final result = evaluateServiceZoneCoverage(
        zones: const [_dakar],
        lat: 14.69,
        lng: null,
      );
      expect(result, ServiceZoneCoverage.ok);
    });

    test('ok inside a declared zone', () {
      final result = evaluateServiceZoneCoverage(
        zones: const [_dakar],
        lat: 14.70, // ~1.5km from the zone centre
        lng: -17.45,
      );
      expect(result, ServiceZoneCoverage.ok);
    });

    test('ok exactly on the radius boundary (mirrors the server <=)', () {
      // A zone with radiusKm 0, evaluated at its own centre: the distance is
      // exactly 0.0 (haversine of a point against itself), so this only
      // reads `ok` if the comparison is `<=`. A mutation to `<` turns this
      // red, which is the point: an int radiusKm makes a non-degenerate
      // boundary (distance == 10.0) unreachable to construct exactly.
      const pointZone = ServiceZone(
        label: 'Exact',
        latitude: 14.69,
        longitude: -17.44,
        radiusKm: 0,
      );
      final result = evaluateServiceZoneCoverage(
        zones: const [pointZone],
        lat: 14.69,
        lng: -17.44,
      );
      expect(result, ServiceZoneCoverage.ok);
    });

    test('outside every declared zone', () {
      // Saint-Louis, Senegal: far from the Dakar zone (>150km).
      final result = evaluateServiceZoneCoverage(
        zones: const [_dakar],
        lat: 16.02,
        lng: -16.49,
      );
      expect(result, ServiceZoneCoverage.outside);
    });

    test('ok when inside the second of several zones', () {
      const zones = [
        _dakar,
        ServiceZone(
          label: 'Saint-Louis',
          latitude: 16.02,
          longitude: -16.49,
          radiusKm: 15,
        ),
      ];
      final result = evaluateServiceZoneCoverage(
        zones: zones,
        lat: 16.03,
        lng: -16.50,
      );
      expect(result, ServiceZoneCoverage.ok);
    });

    test('outside when beyond every zone in a multi-zone service', () {
      const zones = [
        _dakar,
        ServiceZone(
          label: 'Saint-Louis',
          latitude: 16.02,
          longitude: -16.49,
          radiusKm: 15,
        ),
      ];
      final result = evaluateServiceZoneCoverage(
        zones: zones,
        // Kaolack, Senegal: outside both zones.
        lat: 14.15,
        lng: -16.07,
      );
      expect(result, ServiceZoneCoverage.outside);
    });
  });
}
