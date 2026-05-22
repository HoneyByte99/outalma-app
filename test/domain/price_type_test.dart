import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';

void main() {
  group('PriceType.fromString', () {
    test('parses "hourly"', () {
      expect(PriceType.fromString('hourly'), PriceType.hourly);
    });

    test('parses "fixed"', () {
      expect(PriceType.fromString('fixed'), PriceType.fixed);
    });

    test('falls back to fixed for unknown string', () {
      expect(PriceType.fromString('unknown'), PriceType.fixed);
    });

    test('falls back to fixed for empty string', () {
      expect(PriceType.fromString(''), PriceType.fixed);
    });

    test('round-trip: name -> fromString for all values', () {
      for (final pt in PriceType.values) {
        expect(PriceType.fromString(pt.name), pt);
      }
    });
  });
}
