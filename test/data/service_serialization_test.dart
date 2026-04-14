// Verifies that Service objects survive a Firestore write+read roundtrip.
//
// Critical cases per CLAUDE.md:
//   - Field name is "providerId" (not "ownerId" — historical regression risk)
//   - published defaults to false when field is absent
//   - priceType enum (fixed / hourly) roundtrips correctly
//   - serviceZones roundtrip with lat/lng/radiusKm
//   - Legacy "serviceArea" string is supported as a fallback zone
//   - photos is an empty list (not null) when absent

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';

Service _makeService({
  String id = 'service_1',
  String providerId = 'provider_abc',
  CategoryId categoryId = CategoryId.menage,
  PriceType priceType = PriceType.hourly,
  bool published = true,
  List<String> photos = const ['https://example.com/photo1.jpg'],
  List<ServiceZone> serviceZones = const [],
}) {
  return Service(
    id: id,
    providerId: providerId,
    categoryId: categoryId,
    title: 'Ménage appartement',
    description: 'Nettoyage complet 2 pièces',
    photos: photos,
    priceType: priceType,
    price: 2500,
    published: published,
    serviceZones: serviceZones,
    createdAt: DateTime(2024, 1, 10).toUtc(),
    updatedAt: DateTime(2024, 2, 20).toUtc(),
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('Service serialization — required fields', () {
    test('preserves all required fields through roundtrip', () async {
      final service = _makeService();
      final col = FirestoreCollections.services(fakeDb);
      await col.doc(service.id).set(service);
      final result = (await col.doc(service.id).get()).data()!;

      expect(result.id, service.id);
      expect(result.providerId, 'provider_abc');
      expect(result.title, 'Ménage appartement');
      expect(result.description, 'Nettoyage complet 2 pièces');
      expect(result.categoryId, CategoryId.menage);
      expect(result.priceType, PriceType.hourly);
      expect(result.price, 2500);
      expect(result.published, isTrue);
    });
  });

  group('Service serialization — field name contract', () {
    test('stores "providerId" (not "ownerId")', () async {
      final service = _makeService();
      final col = FirestoreCollections.services(fakeDb);
      await col.doc(service.id).set(service);

      // Read raw Firestore document to inspect field names
      final raw = (await fakeDb.collection('services').doc(service.id).get())
          .data()!;
      expect(
        raw.containsKey('providerId'),
        isTrue,
        reason: 'Field must be "providerId", not "ownerId"',
      );
      expect(
        raw.containsKey('ownerId'),
        isFalse,
        reason: 'Legacy "ownerId" must not be written',
      );
      expect(raw['providerId'], 'provider_abc');
    });

    test('reads "providerId" from raw Firestore doc', () async {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      await fakeDb.collection('services').doc('raw_service').set({
        'providerId': 'provider_xyz',
        'createdAt': ts,
        'updatedAt': ts,
      });
      final col = FirestoreCollections.services(fakeDb);
      final result = (await col.doc('raw_service').get()).data()!;
      expect(result.providerId, 'provider_xyz');
    });
  });

  group('Service serialization — published flag', () {
    test('published: true roundtrips correctly', () async {
      final service = _makeService(published: true);
      final col = FirestoreCollections.services(fakeDb);
      await col.doc(service.id).set(service);
      final result = (await col.doc(service.id).get()).data()!;
      expect(result.published, isTrue);
    });

    test('published: false roundtrips correctly', () async {
      final service = _makeService(published: false);
      final col = FirestoreCollections.services(fakeDb);
      await col.doc(service.id).set(service);
      final result = (await col.doc(service.id).get()).data()!;
      expect(result.published, isFalse);
    });

    test('published defaults to false when field is absent', () async {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      await fakeDb.collection('services').doc('no_published').set({
        'createdAt': ts,
        'updatedAt': ts,
      });
      final col = FirestoreCollections.services(fakeDb);
      final result = (await col.doc('no_published').get()).data()!;
      expect(
        result.published,
        isFalse,
        reason: 'New services must be hidden by default',
      );
    });
  });

  group('Service serialization — priceType enum', () {
    test('all PriceType values roundtrip correctly', () async {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      final col = FirestoreCollections.services(fakeDb);

      for (final priceType in PriceType.values) {
        final docId = 'pt_${priceType.name}';
        await fakeDb.collection('services').doc(docId).set({
          'priceType': priceType.name,
          'createdAt': ts,
          'updatedAt': ts,
        });
        final result = (await col.doc(docId).get()).data()!;
        expect(
          result.priceType,
          priceType,
          reason: 'PriceType.${priceType.name} must roundtrip',
        );
      }
    });

    test('unknown priceType falls back to fixed', () async {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      await fakeDb.collection('services').doc('bad_price').set({
        'priceType': 'per_project', // unknown
        'createdAt': ts,
        'updatedAt': ts,
      });
      final col = FirestoreCollections.services(fakeDb);
      final result = (await col.doc('bad_price').get()).data()!;
      expect(result.priceType, PriceType.fixed);
    });
  });

  group('Service serialization — serviceZones', () {
    test('serviceZones roundtrip with all fields', () async {
      final zones = [
        const ServiceZone(
          label: 'Paris 11e',
          latitude: 48.8566,
          longitude: 2.3522,
          radiusKm: 5,
        ),
        const ServiceZone(
          label: 'Paris 20e',
          latitude: 48.8649,
          longitude: 2.4000,
          radiusKm: 3,
        ),
      ];
      final service = _makeService(serviceZones: zones);
      final col = FirestoreCollections.services(fakeDb);
      await col.doc(service.id).set(service);
      final result = (await col.doc(service.id).get()).data()!;

      expect(result.serviceZones.length, 2);
      expect(result.serviceZones[0].label, 'Paris 11e');
      expect(result.serviceZones[0].latitude, closeTo(48.8566, 0.0001));
      expect(result.serviceZones[0].longitude, closeTo(2.3522, 0.0001));
      expect(result.serviceZones[0].radiusKm, 5);
      expect(result.serviceZones[1].label, 'Paris 20e');
    });

    test(
      'serviceZones is empty list (not null) when field is absent',
      () async {
        final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
        await fakeDb.collection('services').doc('no_zones').set({
          'createdAt': ts,
          'updatedAt': ts,
        });
        final col = FirestoreCollections.services(fakeDb);
        final result = (await col.doc('no_zones').get()).data()!;
        expect(result.serviceZones, isEmpty);
      },
    );

    test(
      'legacy "serviceArea" string becomes a single fallback zone',
      () async {
        final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
        await fakeDb.collection('services').doc('legacy').set({
          'serviceArea': 'Lyon',
          'createdAt': ts,
          'updatedAt': ts,
        });
        final col = FirestoreCollections.services(fakeDb);
        final result = (await col.doc('legacy').get()).data()!;
        expect(result.serviceZones.length, 1);
        expect(result.serviceZones.first.label, 'Lyon');
        expect(result.serviceZones.first.latitude, 0.0);
        expect(result.serviceZones.first.longitude, 0.0);
      },
    );
  });

  group('Service serialization — photos', () {
    test('photos list roundtrips correctly', () async {
      final service = _makeService(
        photos: [
          'https://example.com/photo1.jpg',
          'https://example.com/photo2.jpg',
        ],
      );
      final col = FirestoreCollections.services(fakeDb);
      await col.doc(service.id).set(service);
      final result = (await col.doc(service.id).get()).data()!;
      expect(result.photos.length, 2);
      expect(result.photos[0], 'https://example.com/photo1.jpg');
      expect(result.photos[1], 'https://example.com/photo2.jpg');
    });

    test('photos is empty list (not null) when field is absent', () async {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      await fakeDb.collection('services').doc('no_photos').set({
        'createdAt': ts,
        'updatedAt': ts,
      });
      final col = FirestoreCollections.services(fakeDb);
      final result = (await col.doc('no_photos').get()).data()!;
      expect(result.photos, isEmpty);
    });
  });

  group('Service serialization — categoryId', () {
    test('all CategoryId values roundtrip correctly', () async {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      final col = FirestoreCollections.services(fakeDb);

      for (final category in CategoryId.values) {
        final docId = 'cat_${category.name}';
        await fakeDb.collection('services').doc(docId).set({
          'categoryId': category.name,
          'createdAt': ts,
          'updatedAt': ts,
        });
        final result = (await col.doc(docId).get()).data()!;
        expect(
          result.categoryId,
          category,
          reason: 'CategoryId.${category.name} must roundtrip',
        );
      }
    });
  });
}
