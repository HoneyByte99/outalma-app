// Locks the WIRE FORMAT of a service zone: `{label, lat, lng, radiusKm}`.
//
// Why a dedicated file rather than another roundtrip test: a roundtrip is
// symmetric, so it passes with any key as long as the writer and the reader
// agree. service_serialization_test.dart already had one, and it stayed green
// while the entire production catalogue was unreadable. The real bug lived
// between two DIFFERENT writers: the seed scripts wrote `latitude`/`longitude`
// while `serviceZoneFromMap` and the `createBooking` callable read `lat`/`lng`.
// Every zone therefore parsed to (0, 0) and the distance filter emptied the
// catalogue as soon as the client picked a location (build 30).
//
// The failure was invisible because (0, 0) is a MEANINGFUL value in this
// domain: `zoneIsLocatable` treats it as "the provider typed a label but no
// position was resolved", and the legacy `serviceArea` fallback synthesises
// exactly that. A parse failure was indistinguishable from a legitimately
// unlocated zone.
//
// So the assertions below are about key NAMES on the raw map, not about a
// roundtrip, and about the deliberate choice NOT to make the reader tolerant of
// the legacy keys. Renaming the emitted key back to `latitude`/`longitude`, or
// teaching `serviceZoneFromMap` to accept it, turns this file red.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/data/firestore/firestore_serialization.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/utils/distance.dart';

const _dakar = ServiceZone(
  label: 'Dakar Centre',
  latitude: 14.6928,
  longitude: -17.4467,
  radiusKm: 15,
);

Service _serviceWith(List<ServiceZone> zones) => Service(
  id: 'svc_zone_keys',
  providerId: 'provider_abc',
  categoryId: CategoryId.menage,
  title: 'Menage appartement',
  description: 'Nettoyage complet 2 pieces',
  photos: const [],
  priceType: PriceType.hourly,
  price: 2500,
  published: true,
  serviceZones: zones,
  createdAt: DateTime(2024, 1, 10).toUtc(),
  updatedAt: DateTime(2024, 2, 20).toUtc(),
);

void main() {
  group('ServiceZone wire format', () {
    test('serviceZoneToMap emits exactly label, lat, lng, radiusKm', () {
      final map = serviceZoneToMap(_dakar);

      expect(
        map.keys.toSet(),
        {'label', 'lat', 'lng', 'radiusKm'},
        reason:
            'The zone contract is read by serviceZoneFromMap AND by the '
            'createBooking callable (functions/src/index.ts). Adding, removing '
            'or renaming a key here breaks one of the two silently.',
      );
      expect(map['lat'], 14.6928);
      expect(map['lng'], -17.4467);
    });

    test('serviceZoneToMap never emits the legacy latitude/longitude', () {
      final map = serviceZoneToMap(_dakar);

      expect(map.containsKey('latitude'), isFalse);
      expect(map.containsKey('longitude'), isFalse);
    });

    test('serviceZoneFromMap reads the canonical keys', () {
      final zone = serviceZoneFromMap(const {
        'label': 'Thies',
        'lat': 14.7886,
        'lng': -16.9260,
        'radiusKm': 20,
      });

      expect(zone.label, 'Thies');
      expect(zone.latitude, closeTo(14.7886, 0.0001));
      expect(zone.longitude, closeTo(-16.9260, 0.0001));
      expect(zone.radiusKm, 20);
      expect(zoneIsLocatable(zone), isTrue);
    });

    test('a written service document carries lat/lng on every zone', () async {
      final fakeDb = FakeFirebaseFirestore();
      final service = _serviceWith(const [_dakar]);
      await FirestoreCollections.services(fakeDb).doc(service.id).set(service);

      // Read the RAW document: the point is the key names on the wire, which a
      // typed read would hide behind the same deserialiser under test.
      final raw = (await fakeDb.collection('services').doc(service.id).get())
          .data()!;
      final zones = (raw['serviceZones'] as List).cast<Map<String, dynamic>>();

      expect(zones, hasLength(1));
      expect(zones.single.containsKey('lat'), isTrue);
      expect(zones.single.containsKey('lng'), isTrue);
      expect(zones.single.containsKey('latitude'), isFalse);
      expect(zones.single.containsKey('longitude'), isFalse);
    });

    test('a canonical zone survives the full document roundtrip', () async {
      final fakeDb = FakeFirebaseFirestore();
      final service = _serviceWith(const [_dakar]);
      final col = FirestoreCollections.services(fakeDb);
      await col.doc(service.id).set(service);

      final read = (await col.doc(service.id).get()).data()!;

      expect(read.serviceZones, hasLength(1));
      expect(read.serviceZones.single, _dakar);
      expect(zoneIsLocatable(read.serviceZones.single), isTrue);
    });
  });

  group('ServiceZone legacy latitude/longitude is out of contract', () {
    // Deliberate decision, not an oversight: the reader stays on a single
    // contract and the DATA gets fixed once (scripts/fix-service-zone-keys.py).
    //
    // Tolerating both key sets client-side would only half fix the bug: the
    // `createBooking` callable reads `z.lat`/`z.lng` and would keep refusing
    // every geocoded address with "outside the service intervention zones". The
    // app would then show a service as coverable while the server refuses to
    // book it, which is a worse failure than today's consistent one. It would
    // also make the wrong key permanently viable, so the next reseed that
    // reintroduces the drift would again go unnoticed.
    //
    // These tests pin the CURRENT behaviour so that a future decision to become
    // tolerant is a conscious edit to this file, not an accident.

    test('a legacy zone map parses to (0, 0) and is not locatable', () {
      final zone = serviceZoneFromMap(const {
        'label': 'Dakar Centre',
        'latitude': 14.6928,
        'longitude': -17.4467,
        'radiusKm': 15,
      });

      expect(zone.label, 'Dakar Centre');
      expect(zone.radiusKm, 15);
      // The coordinates are dropped on the floor: the keys are not the
      // contract. (0, 0) is the repo's "no position resolved" marker.
      expect(zone.latitude, 0.0);
      expect(zone.longitude, 0.0);
      expect(
        zoneIsLocatable(zone),
        isFalse,
        reason:
            'A legacy zone must never take part in a distance computation: at '
            '(0, 0) it would win every "closest" contest run from Dakar.',
      );
    });

    test('a legacy service document yields no locatable zone', () async {
      final fakeDb = FakeFirebaseFirestore();
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      // The exact shape of the 44 production zones before migration.
      await fakeDb.collection('services').doc('legacy_keys').set({
        'providerId': 'provider_abc',
        'serviceZones': [
          {
            'label': 'Dakar Centre',
            'latitude': 14.6928,
            'longitude': -17.4467,
            'radiusKm': 15,
          },
        ],
        'createdAt': ts,
        'updatedAt': ts,
      });

      final read = (await FirestoreCollections.services(
        fakeDb,
      ).doc('legacy_keys').get()).data()!;

      expect(read.serviceZones, hasLength(1));
      expect(read.serviceZones.single.label, 'Dakar Centre');
      expect(
        read.serviceZones.where(zoneIsLocatable),
        isEmpty,
        reason:
            'This is the production bug: the zone exists, carries its label, '
            'and is invisible to the distance filter.',
      );
    });
  });
}
