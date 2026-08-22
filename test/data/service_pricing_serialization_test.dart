// Roundtrip coverage for the pricing-ranges fields added to Service:
// extraTasks (list, defaults to empty) and priceMax (monthly high end, absent
// outside the monthly mode).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';

Service _service({
  PriceType priceType = PriceType.hourly,
  int price = 2500,
  int? priceMax,
  List<String> extraTasks = const [],
}) {
  final now = DateTime(2026, 8, 21).toUtc();
  return Service(
    id: 'svc_1',
    providerId: 'prov_1',
    categoryId: CategoryId.menage,
    title: 'Ménage',
    photos: const [],
    priceType: priceType,
    price: price,
    priceMax: priceMax,
    extraTasks: extraTasks,
    published: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('extraTasks roundtrips', () async {
    final col = FirestoreCollections.services(db);
    await col
        .doc('svc_1')
        .set(_service(extraTasks: const ['cuisine', 'repassage']));
    final read = (await col.doc('svc_1').get()).data()!;
    expect(read.extraTasks, ['cuisine', 'repassage']);
  });

  test('extraTasks defaults to an empty list when absent', () async {
    await db.collection('services').doc('svc_1').set({
      'providerId': 'prov_1',
      'categoryId': 'menage',
      'title': 'x',
      'priceType': 'hourly',
      'price': 2500,
      'published': true,
    });
    final read = (await FirestoreCollections.services(
      db,
    ).doc('svc_1').get()).data()!;
    expect(read.extraTasks, isEmpty);
    expect(read.priceMax, isNull);
  });

  test('monthly priceMax roundtrips', () async {
    final col = FirestoreCollections.services(db);
    await col
        .doc('svc_1')
        .set(
          _service(priceType: PriceType.monthly, price: 60000, priceMax: 90000),
        );
    final read = (await col.doc('svc_1').get()).data()!;
    expect(read.priceType, PriceType.monthly);
    expect(read.price, 60000);
    expect(read.priceMax, 90000);
  });

  test('priceMax is NOT written to the document when null', () async {
    await FirestoreCollections.services(db).doc('svc_1').set(_service());
    final raw = (await db.collection('services').doc('svc_1').get()).data()!;
    expect(raw.containsKey('priceMax'), isFalse);
    // extraTasks is always written, even when empty.
    expect(raw['extraTasks'], isEmpty);
  });

  test('copyWith can clear priceMax explicitly', () async {
    final monthly = _service(
      priceType: PriceType.monthly,
      price: 60000,
      priceMax: 90000,
    );
    final cleared = monthly.copyWith(
      priceType: PriceType.hourly,
      priceMax: null,
    );
    expect(cleared.priceMax, isNull);
    // Omitting the argument keeps the current value.
    final kept = monthly.copyWith(price: 61000);
    expect(kept.priceMax, 90000);
  });
}
