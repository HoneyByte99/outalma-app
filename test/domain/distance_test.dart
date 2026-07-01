import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/utils/distance.dart';

void main() {
  group('haversineKm', () {
    test('returns 0 for identical points', () {
      expect(haversineKm(48.8566, 2.3522, 48.8566, 2.3522), closeTo(0, 1e-6));
    });

    test('Paris → Lyon is roughly 392 km', () {
      // Paris (Notre-Dame) ≈ 48.8530, 2.3499
      // Lyon (Bellecour)   ≈ 45.7578, 4.8320
      final km = haversineKm(48.8530, 2.3499, 45.7578, 4.8320);
      expect(km, closeTo(392, 5));
    });

    test('symmetric in argument order', () {
      final ab = haversineKm(48.85, 2.35, 45.75, 4.83);
      final ba = haversineKm(45.75, 4.83, 48.85, 2.35);
      expect(ab, closeTo(ba, 1e-9));
    });
  });

  group('closestZoneKm', () {
    test('returns null when zones list is empty', () {
      expect(closestZoneKm(const [], 48.85, 2.35), isNull);
    });

    test('picks the geographically closest zone', () {
      const paris = ServiceZone(
        label: 'Paris',
        latitude: 48.8566,
        longitude: 2.3522,
        radiusKm: 10,
      );
      const lyon = ServiceZone(
        label: 'Lyon',
        latitude: 45.7578,
        longitude: 4.8320,
        radiusKm: 10,
      );
      const marseille = ServiceZone(
        label: 'Marseille',
        latitude: 43.2965,
        longitude: 5.3698,
        radiusKm: 10,
      );

      // Target near Lyon - should pick Lyon.
      final result = closestZoneKm([paris, lyon, marseille], 45.76, 4.84);
      expect(result, isNotNull);
      expect(result!.zone.label, 'Lyon');
      expect(result.km, lessThan(5));
    });
  });

  group('closestRealZoneKm', () {
    const paris = ServiceZone(
      label: 'Paris',
      latitude: 48.8566,
      longitude: 2.3522,
      radiusKm: 10,
    );
    const unset = ServiceZone(
      label: 'Unset',
      latitude: 0,
      longitude: 0,
      radiusKm: 10,
    );

    test('ignores unset (0,0) placeholder zones', () {
      final result = closestRealZoneKm([unset, paris], 48.8566, 2.3522);
      expect(result, isNotNull);
      expect(result!.zone.label, 'Paris');
      expect(result.km, closeTo(0, 1));
    });

    test('returns null when every zone is unset', () {
      expect(closestRealZoneKm(const [unset], 48.85, 2.35), isNull);
    });

    test('returns null when zones list is empty', () {
      expect(closestRealZoneKm(const [], 48.85, 2.35), isNull);
    });

    test('does not let a null-island target match an unset zone', () {
      // A target at (0,0) is 0 km from the unset zone; we must still skip it.
      expect(closestRealZoneKm(const [unset], 0, 0), isNull);
    });
  });
}
