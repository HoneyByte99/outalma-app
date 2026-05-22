// Tests for format_utils.dart
//
// Covered:
//   - formatPriceFromCents: formats integer cents as a fr_FR currency string
//     with symbol "F CFA" and 0 decimal digits
//   - Various cent values: 0, 100, 1500, 100000, 500000
//   - No decimal separator in output (decimalDigits: 0)
//   - Thousands grouping for large values
//   - Symbol always present
//   - Negative value behaviour

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/core/utils/format_utils.dart';

// ---------------------------------------------------------------------------
// Helper: normalise non-breaking spaces to regular spaces for safe matching
// ---------------------------------------------------------------------------

String _normalise(String s) => s
    .replaceAll(' ', ' ') // non-breaking space U+00A0
    .replaceAll(' ', ' ') // narrow non-breaking space U+202F
    .trim();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('formatPriceFromCents', () {
    test('formats 0 cents as "0 F CFA"', () {
      final result = _normalise(formatPriceFromCents(0));
      expect(result, '0 F CFA');
    });

    test('formats 100 cents (1 unit) as "1 F CFA"', () {
      final result = _normalise(formatPriceFromCents(100));
      expect(result, '1 F CFA');
    });

    test('formats 1500 cents as 15 F CFA', () {
      // 1500 cents = 15 units
      final result = formatPriceFromCents(1500);
      expect(result, contains('15'));
      expect(result, contains('F CFA'));
    });

    test('formats 200 cents (2 units) without decimal separator', () {
      final result = formatPriceFromCents(200);
      expect(result, isNot(contains(',')));
      expect(result, contains('2'));
    });

    test('formats 100000 cents (1 000 units) with thousand separator', () {
      final result = _normalise(formatPriceFromCents(100000));
      // Locale fr_FR uses non-breaking space as thousand separator
      expect(result, '1 000 F CFA');
    });

    test('formats 50 cents — rounds to 0 decimal digits, no comma', () {
      // 50 cents = 0.5 units; fr_FR currency with 0 decimal digits rounds
      final result = formatPriceFromCents(50);
      expect(result, contains('F CFA'));
      // Should not contain a decimal separator since decimalDigits: 0
      expect(result, isNot(contains(',')));
    });

    test('formats 500000 cents (5 000 units) with grouping', () {
      final result = _normalise(formatPriceFromCents(500000));
      expect(result, '5 000 F CFA');
    });

    test('formats 5000 cents (50 units) as "50 F CFA"', () {
      expect(_normalise(formatPriceFromCents(5000)), '50 F CFA');
    });

    test('result always contains "F CFA" symbol', () {
      for (final cents in [0, 100, 2500, 75000, 1000000]) {
        expect(
          formatPriceFromCents(cents),
          contains('F CFA'),
          reason: 'cents=$cents should include F CFA',
        );
      }
    });

    test('output never contains decimal comma (decimalDigits is 0)', () {
      for (final cents in [50, 100, 150, 1234, 99999]) {
        expect(
          formatPriceFromCents(cents),
          isNot(contains(',')),
          reason: 'cents=$cents should have no decimal separator',
        );
      }
    });

    test('negative value contains number and F CFA symbol', () {
      final result = formatPriceFromCents(-100);
      expect(result, contains('F CFA'));
      expect(result, contains('1'));
    });
  });
}
