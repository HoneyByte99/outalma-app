// Tests for FirestoreServiceRepository using FakeFirebaseFirestore.
//
// Covered:
//   - watchAllPublished(): streams published services, respects limit
//   - watchById(): returns null for missing doc, service for existing
//   - watchForProvider(): filters by providerId
//   - create(): writes to Firestore and returns the created service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/data/repositories/firestore_service_repository.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Service _makeService({
  String id = 'svc_1',
  String providerId = 'provider_1',
  CategoryId categoryId = CategoryId.menage,
  bool published = true,
}) {
  final now = DateTime(2024, 6, 1).toUtc();
  return Service(
    id: id,
    providerId: providerId,
    categoryId: categoryId,
    title: 'Service $id',
    photos: [],
    priceType: PriceType.fixed,
    price: 80,
    published: published,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _writeService(FirebaseFirestore db, Service service) {
  return FirestoreCollections.services(db).doc(service.id).set(service);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreServiceRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestoreServiceRepository(fakeDb);
  });

  // -------------------------------------------------------------------------
  // watchAllPublished
  // -------------------------------------------------------------------------

  group('watchAllPublished', () {
    test('returns empty list when no services exist', () async {
      final list = await repo.watchAllPublished().first;
      expect(list, isEmpty);
    });

    test('returns only published services', () async {
      await _writeService(fakeDb, _makeService(id: 's1', published: true));
      await _writeService(fakeDb, _makeService(id: 's2', published: false));

      final list = await repo.watchAllPublished().first;
      expect(list.length, 1);
      expect(list.first.id, 's1');
    });

    test('respects limit parameter', () async {
      for (var i = 1; i <= 5; i++) {
        await _writeService(fakeDb, _makeService(id: 'svc_$i', published: true));
      }

      final list = await repo.watchAllPublished(limit: 3).first;
      expect(list.length, lessThanOrEqualTo(3));
    });

    test('returns correct fields', () async {
      final service = _makeService(
        id: 's_full',
        providerId: 'prov_X',
        categoryId: CategoryId.plomberie,
        published: true,
      );
      await _writeService(fakeDb, service);

      final list = await repo.watchAllPublished().first;
      final result = list.first;

      expect(result.id, 's_full');
      expect(result.providerId, 'prov_X');
      expect(result.categoryId, CategoryId.plomberie);
      expect(result.published, true);
    });
  });

  // -------------------------------------------------------------------------
  // watchById
  // -------------------------------------------------------------------------

  group('watchById', () {
    test('returns null for a missing document', () async {
      final result = await repo.watchById('nonexistent').first;
      expect(result, isNull);
    });

    test('returns the service for an existing document', () async {
      final service = _makeService(id: 'svc_detail');
      await _writeService(fakeDb, service);

      final result = await repo.watchById('svc_detail').first;
      expect(result, isNotNull);
      expect(result!.id, 'svc_detail');
      expect(result.categoryId, CategoryId.menage);
    });

    test('streams update when document changes', () async {
      await _writeService(
        fakeDb,
        _makeService(id: 'svc_live', published: false),
      );

      final stream = repo.watchById('svc_live');
      final first = await stream.first;
      expect(first?.published, false);

      // Update the doc — republish
      await FirestoreCollections.services(fakeDb).doc('svc_live').set(
        _makeService(id: 'svc_live', published: true),
      );

      // Give Firestore a tick to emit the update
      await Future<void>.delayed(Duration.zero);
      final updated = await repo.watchById('svc_live').first;
      expect(updated?.published, true);
    });
  });

  // -------------------------------------------------------------------------
  // watchForProvider
  // -------------------------------------------------------------------------

  group('watchForProvider', () {
    test('returns empty list when provider has no services', () async {
      await _writeService(
        fakeDb,
        _makeService(id: 's_other', providerId: 'other_provider'),
      );

      final list = await repo.watchForProvider('my_provider').first;
      expect(list, isEmpty);
    });

    test('returns only services for the given provider', () async {
      await _writeService(
        fakeDb,
        _makeService(id: 's1', providerId: 'provider_A'),
      );
      await _writeService(
        fakeDb,
        _makeService(id: 's2', providerId: 'provider_B'),
      );
      await _writeService(
        fakeDb,
        _makeService(id: 's3', providerId: 'provider_A'),
      );

      final list = await repo.watchForProvider('provider_A').first;
      expect(list.length, 2);
      expect(list.map((s) => s.id), containsAll(['s1', 's3']));
    });

    test('includes both published and unpublished services for provider',
        () async {
      await _writeService(
        fakeDb,
        _makeService(id: 'pub', providerId: 'prov_1', published: true),
      );
      await _writeService(
        fakeDb,
        _makeService(id: 'draft', providerId: 'prov_1', published: false),
      );

      final list = await repo.watchForProvider('prov_1').first;
      expect(list.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // create
  // -------------------------------------------------------------------------

  group('create', () {
    test('writes service with explicit id and returns it', () async {
      final service = _makeService(id: 'my_id');
      final result = await repo.create(service);

      expect(result.id, 'my_id');
      expect(result.title, service.title);

      // Verify document exists in Firestore
      final snap = await FirestoreCollections.services(fakeDb).doc('my_id').get();
      expect(snap.exists, true);
      expect(snap.data()?.id, 'my_id');
    });

    test('auto-generates id when service id is empty', () async {
      final service = Service(
        id: '',
        providerId: 'prov_1',
        categoryId: CategoryId.jardinage,
        title: 'Auto ID service',
        photos: [],
        priceType: PriceType.hourly,
        price: 30,
        published: false,
        createdAt: DateTime(2024, 1, 1).toUtc(),
        updatedAt: DateTime(2024, 1, 1).toUtc(),
      );

      final result = await repo.create(service);
      expect(result.id, isNotEmpty);
      expect(result.id.isNotEmpty, true);
    });
  });
}
