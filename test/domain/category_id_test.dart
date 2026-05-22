import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';

void main() {
  group('CategoryId.label', () {
    test('every value has a non-empty label', () {
      for (final id in CategoryId.values) {
        expect(id.label, isNotEmpty, reason: '${id.name} has an empty label');
      }
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
  });
}
