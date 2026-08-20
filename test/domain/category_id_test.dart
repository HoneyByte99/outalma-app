import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';

void main() {
  group('CategoryId.label', () {
    test('every value has a non-empty label', () {
      for (final id in CategoryId.values) {
        expect(id.label, isNotEmpty, reason: '${id.name} has an empty label');
      }
    });

    test('cuisine and repassage have the expected FR labels', () {
      expect(CategoryId.cuisine.label, 'Cuisine');
      expect(CategoryId.repassage.label, 'Repassage');
    });
  });

  group('CategoryId.fromString', () {
    test('parses each known enum name', () {
      for (final id in CategoryId.values) {
        expect(CategoryId.fromString(id.name), id);
      }
    });

    test('falls back to menage for unknown string', () {
      expect(CategoryId.fromString('unknown_value'), CategoryId.menage);
    });

    test('falls back to menage for empty string', () {
      expect(CategoryId.fromString(''), CategoryId.menage);
    });

    test('parses gardeEnfants correctly', () {
      expect(CategoryId.fromString('gardeEnfants'), CategoryId.gardeEnfants);
    });

    test('parses cuisine correctly', () {
      expect(CategoryId.fromString('cuisine'), CategoryId.cuisine);
    });

    test('parses repassage correctly', () {
      expect(CategoryId.fromString('repassage'), CategoryId.repassage);
    });
  });

  group('CategoryId.visibleInClientFilter', () {
    const mvpVisible = {
      CategoryId.menage,
      CategoryId.gardeEnfants,
      CategoryId.cuisine,
      CategoryId.repassage,
    };

    test('returns true for the 4 MVP categories', () {
      for (final id in mvpVisible) {
        expect(
          id.visibleInClientFilter,
          isTrue,
          reason: '${id.name} should be visible',
        );
      }
    });

    test('returns false for out-of-scope categories', () {
      final outOfScope = CategoryId.values.toSet().difference(mvpVisible);
      for (final id in outOfScope) {
        expect(
          id.visibleInClientFilter,
          isFalse,
          reason: '${id.name} should be hidden',
        );
      }
    });

    test('exactly 4 categories are visible', () {
      final visibleCount = CategoryId.values
          .where((c) => c.visibleInClientFilter)
          .length;
      expect(visibleCount, 4);
    });
  });
}
