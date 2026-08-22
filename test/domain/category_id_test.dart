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

  group('CategoryId.clientFilterCategories', () {
    test('is the curated order, not the raw enum order', () {
      expect(CategoryId.clientFilterCategories, [
        CategoryId.menage,
        CategoryId.repassage,
        CategoryId.cuisine,
        CategoryId.gardeEnfants,
      ]);
    });

    test('Menage is first (anchor of the pool)', () {
      expect(CategoryId.clientFilterCategories.first, CategoryId.menage);
    });

    test('every curated entry is visible in the client filter', () {
      for (final c in CategoryId.clientFilterCategories) {
        expect(c.visibleInClientFilter, isTrue, reason: '${c.name} hidden');
      }
    });

    test('contains exactly the visible categories (no drift)', () {
      expect(
        CategoryId.clientFilterCategories.toSet(),
        CategoryId.values.where((c) => c.visibleInClientFilter).toSet(),
      );
    });

    test('has no duplicates', () {
      const list = CategoryId.clientFilterCategories;
      expect(list.toSet().length, list.length);
    });
  });
}
