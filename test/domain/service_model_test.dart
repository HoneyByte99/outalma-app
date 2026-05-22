import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';

Service _base() => Service(
      id: 's1',
      providerId: 'p1',
      categoryId: CategoryId.menage,
      title: 'Ménage complet',
      photos: const [],
      priceType: PriceType.hourly,
      price: 2500,
      published: true,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
    );

void main() {
  group('Service.copyWith', () {
    test('unchanged fields are preserved', () {
      final s = _base().copyWith(title: 'Nouveau titre');
      expect(s.id, 's1');
      expect(s.providerId, 'p1');
      expect(s.title, 'Nouveau titre');
      expect(s.price, 2500);
    });

    test('price can be set to 0', () {
      final s = _base().copyWith(price: 0);
      expect(s.price, 0);
    });

    test('price can be set to a very high value', () {
      final s = _base().copyWith(price: 9999999);
      expect(s.price, 9999999);
    });

    test('published flag toggles', () {
      final s = _base().copyWith(published: false);
      expect(s.published, isFalse);
    });

    test('description defaults to null and can be set', () {
      expect(_base().description, isNull);
      final s = _base().copyWith(description: 'desc');
      expect(s.description, 'desc');
    });
  });

  group('ServiceZone', () {
    test('equality holds when all fields match', () {
      const a = ServiceZone(
        label: 'Paris 11e',
        latitude: 48.8588,
        longitude: 2.3472,
        radiusKm: 5,
      );
      const b = ServiceZone(
        label: 'Paris 11e',
        latitude: 48.8588,
        longitude: 2.3472,
        radiusKm: 5,
      );
      expect(a, equals(b));
    });

    test('inequality when radiusKm differs', () {
      const a = ServiceZone(
        label: 'Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
        radiusKm: 10,
      );
      const b = ServiceZone(
        label: 'Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
        radiusKm: 20,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes label and radius', () {
      const z = ServiceZone(
        label: 'Lyon',
        latitude: 45.75,
        longitude: 4.85,
        radiusKm: 15,
      );
      expect(z.toString(), contains('Lyon'));
      expect(z.toString(), contains('15km'));
    });
  });
}
