import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/models/provider_profile.dart';

ProviderProfile _base() => ProviderProfile(
  uid: 'p',
  active: true,
  suspended: false,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

void main() {
  group('ProviderProfile.copyWith', () {
    test('overrides every field when provided', () {
      final p = _base().copyWith(
        bio: 'b',
        serviceArea: 'sa',
        serviceAreaLat: 1.0,
        serviceAreaLng: 2.0,
        workingHourStart: 9,
        workingHourEnd: 17,
        active: false,
        suspended: true,
        createdAt: DateTime(2025, 6, 1).toUtc(),
      );
      expect(p.uid, 'p'); // uid is identity, never copied
      expect(p.bio, 'b');
      expect(p.serviceArea, 'sa');
      expect(p.serviceAreaLat, 1.0);
      expect(p.serviceAreaLng, 2.0);
      expect(p.workingHourStart, 9);
      expect(p.workingHourEnd, 17);
      expect(p.active, false);
      expect(p.suspended, true);
      expect(p.createdAt, DateTime(2025, 6, 1).toUtc());
    });

    test('preserves existing values when called with no args', () {
      final p = _base().copyWith(
        bio: 'orig',
        workingHourStart: 7,
        workingHourEnd: 19,
      );
      final same = p.copyWith();
      expect(same.bio, 'orig');
      expect(same.active, true);
      expect(same.suspended, false);
      expect(same.workingHourStart, 7);
      expect(same.workingHourEnd, 19);
    });
  });

  group('ProviderProfile effective working hours', () {
    test('defaults when unset', () {
      final p = _base();
      expect(p.workingHourStart, isNull);
      expect(p.workingHourEnd, isNull);
      expect(p.effectiveHourStart, kDefaultWorkingHourStart);
      expect(p.effectiveHourEnd, kDefaultWorkingHourEnd);
    });

    test('uses configured values when valid', () {
      final p = _base().copyWith(workingHourStart: 7, workingHourEnd: 20);
      expect(p.effectiveHourStart, 7);
      expect(p.effectiveHourEnd, 20);
    });

    test('guards an invalid window (end <= start)', () {
      final p = _base().copyWith(workingHourStart: 22, workingHourEnd: 6);
      expect(p.effectiveHourStart, 22);
      expect(p.effectiveHourEnd, kDefaultWorkingHourEnd);
    });
  });
}
