// Tests for format_utils.dart
//
// Covered:
//   - formatPrice: formats whole FCFA (spec decision 3, no cents) as a fr_FR
//     currency string with symbol "F CFA" and 0 decimal digits.
//   - formatPriceRange: monthly low - high range, symbol once on the high end.
//   - formatAmount: grouped number, no symbol, for injecting into localised
//     strings that carry "F CFA" themselves.
//   - Replaces the former formatPriceFromCents suite: the unit bascule from
//     cents to whole FCFA means 1500 now reads "1 500 F CFA", not "15 F CFA".

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/core/utils/format_utils.dart';

// ---------------------------------------------------------------------------
// Helper: normalise the various non-breaking spaces intl emits to plain spaces
// ---------------------------------------------------------------------------

String _normalise(String s) =>
    s.replaceAll(RegExp('[\u00A0\u202F\u2009\u2007]'), ' ').trim();

void main() {
  group('formatPrice', () {
    test('formats 0 as "0 F CFA"', () {
      expect(_normalise(formatPrice(0)), '0 F CFA');
    });

    test('formats whole FCFA without dividing by a hundred', () {
      // The core of the unit bascule: 1500 is 1 500 FCFA, not 15.
      expect(_normalise(formatPrice(1500)), '1 500 F CFA');
      expect(_normalise(formatPrice(15000)), '15 000 F CFA');
    });

    test('formats 2500 as "2 500 F CFA" (SC-41)', () {
      expect(_normalise(formatPrice(2500)), '2 500 F CFA');
    });

    test('groups thousands', () {
      expect(_normalise(formatPrice(150000)), '150 000 F CFA');
    });

    test('never emits a decimal separator (decimalDigits: 0)', () {
      for (final v in [1000, 3500, 12500, 99999]) {
        expect(formatPrice(v), isNot(contains(',')));
      }
    });

    test('always contains the F CFA symbol', () {
      for (final v in [0, 1000, 2500, 150000]) {
        expect(formatPrice(v), contains('F CFA'));
      }
    });
  });

  group('formatPriceRange', () {
    test('renders low - high with the symbol once (SC-30)', () {
      expect(
        _normalise(formatPriceRange(60000, 90000)),
        '60 000 - 90 000 F CFA',
      );
    });

    test('carries both bounds', () {
      final r = _normalise(formatPriceRange(50000, 150000));
      expect(r, contains('50 000'));
      expect(r, contains('150 000'));
      expect(r, contains('F CFA'));
    });
  });

  group('formatAmount', () {
    test('groups thousands with no currency symbol', () {
      expect(_normalise(formatAmount(1000)), '1 000');
      expect(_normalise(formatAmount(3500)), '3 500');
      expect(formatAmount(3500), isNot(contains('F CFA')));
    });
  });
}
