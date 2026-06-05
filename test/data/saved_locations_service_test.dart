// Tests for SavedLocationsNotifier and SavedLocation model.
//
// Covered:
//   - add(): inserts location at front of list
//   - add(): deduplicates by address (replaces existing)
//   - add(): enforces max 5 items, oldest drops off
//   - remove(): removes item at given index
//   - SavedLocation.fromJson: handles missing/null fields with safe defaults
//   - SavedLocation.toJson: roundtrips correctly

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/services/saved_locations_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SavedLocation _loc({
  String label = 'Maison',
  String address = '10 rue de Rivoli, Paris',
  double lat = 48.8566,
  double lng = 2.3522,
  double radiusKm = 10,
}) {
  return SavedLocation(
    label: label,
    address: address,
    lat: lat,
    lng: lng,
    radiusKm: radiusKm,
  );
}

/// Creates a [ProviderContainer] with in-memory SharedPreferences.
/// Always call [container.dispose] after the test.
ProviderContainer _makeContainer() {
  return ProviderContainer();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedLocationsNotifier', () {
    test('initial state is empty', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // Allow async build/_load to settle
      await Future<void>.delayed(Duration.zero);

      expect(container.read(savedLocationsProvider), isEmpty);
    });

    test('add() inserts location at front of list', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(savedLocationsProvider.notifier);
      final first = _loc(label: 'A', address: 'addr_A');
      final second = _loc(label: 'B', address: 'addr_B');

      await notifier.add(first);
      await notifier.add(second);

      final state = container.read(savedLocationsProvider);
      expect(state.first.label, 'B');
      expect(state[1].label, 'A');
    });

    test('add() replaces duplicate by address (no duplicates)', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(savedLocationsProvider.notifier);
      final original = _loc(label: 'Old label', address: 'same_address');
      final updated = _loc(label: 'New label', address: 'same_address');

      await notifier.add(original);
      await notifier.add(updated);

      final state = container.read(savedLocationsProvider);
      expect(state, hasLength(1));
      expect(state.first.label, 'New label');
    });

    test('add() enforces max 5 items — oldest drops off', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(savedLocationsProvider.notifier);
      for (var i = 1; i <= 6; i++) {
        await notifier.add(_loc(label: 'Loc $i', address: 'addr_$i'));
      }

      final state = container.read(savedLocationsProvider);
      expect(state, hasLength(5));
      // Most-recently added is at front; oldest (Loc 1) should be gone.
      expect(state.map((l) => l.label), isNot(contains('Loc 1')));
      expect(state.first.label, 'Loc 6');
    });

    test('remove() removes item at given index', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(savedLocationsProvider.notifier);
      await notifier.add(_loc(label: 'A', address: 'addr_A'));
      await notifier.add(_loc(label: 'B', address: 'addr_B'));

      // State is [B, A]. Remove index 0 → only A remains.
      await notifier.remove(0);

      final state = container.read(savedLocationsProvider);
      expect(state, hasLength(1));
      expect(state.first.label, 'A');
    });
  });

  group('SavedLocation.fromJson', () {
    test('parses a complete JSON object correctly', () {
      final json = {
        'label': 'Bureau',
        'address': '1 Allée du Roi, Versailles',
        'lat': 48.8044,
        'lng': 2.1200,
        'radiusKm': 15.0,
      };

      final loc = SavedLocation.fromJson(json);
      expect(loc.label, 'Bureau');
      expect(loc.address, '1 Allée du Roi, Versailles');
      expect(loc.lat, closeTo(48.8044, 0.0001));
      expect(loc.lng, closeTo(2.1200, 0.0001));
      expect(loc.radiusKm, 15.0);
    });

    test('uses safe defaults for missing fields', () {
      final loc = SavedLocation.fromJson({});
      expect(loc.label, '');
      expect(loc.address, '');
      expect(loc.lat, 0.0);
      expect(loc.lng, 0.0);
      expect(loc.radiusKm, 30.0);
    });

    test('uses safe defaults for null fields', () {
      final json = <String, dynamic>{
        'label': null,
        'address': null,
        'lat': null,
        'lng': null,
        'radiusKm': null,
      };

      final loc = SavedLocation.fromJson(json);
      expect(loc.label, '');
      expect(loc.address, '');
      expect(loc.lat, 0.0);
      expect(loc.lng, 0.0);
      expect(loc.radiusKm, 30.0);
    });
  });

  group('SavedLocation.toJson', () {
    test('roundtrips through toJson → fromJson', () {
      final original = _loc(
        label: 'Dakar',
        address: 'Plateau, Dakar, Sénégal',
        lat: 14.6928,
        lng: -17.4467,
        radiusKm: 25.0,
      );

      final restored = SavedLocation.fromJson(original.toJson());

      expect(restored.label, original.label);
      expect(restored.address, original.address);
      expect(restored.lat, original.lat);
      expect(restored.lng, original.lng);
      expect(restored.radiusKm, original.radiusKm);
    });

    test('toJson contains all expected keys', () {
      final loc = _loc();
      final json = loc.toJson();

      expect(
        json.keys,
        containsAll(['label', 'address', 'lat', 'lng', 'radiusKm']),
      );
    });
  });
}
