import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/pricing/pricing_config.dart';

// The grid from spec-pricing-ranges.md section 4, mirrored as it lives in the
// `config/pricing` Firestore document (archi section 3.1).
Map<String, Object?> _gridMap() => {
  'version': 1,
  'currency': 'XOF',
  'boundedCategories': ['menage', 'cuisine', 'gardeEnfants', 'repassage'],
  'maxExtraTasks': 3,
  'modes': {
    'hourly': {'min': 1000, 'max': 3500, 'extraBonusPercent': 25},
    'daily': {'min': 2000, 'max': 10000, 'extraBonusPercent': 25},
    'monthly': {
      'min': 50000,
      'max': 150000,
      'extraBonusPercent': 0,
      'isRange': true,
    },
  },
};

void main() {
  group('cap()', () {
    test('no extra task returns the base ceiling unchanged', () {
      expect(cap(3500, 25, 0), 3500);
      expect(cap(10000, 25, 0), 10000);
    });

    test('matches the spec ceilings for hourly (25% per extra task)', () {
      expect(cap(3500, 25, 1), 4375);
      expect(cap(3500, 25, 2), 5250);
      expect(cap(3500, 25, 3), 6125);
    });

    test('matches the spec ceilings for daily (25% per extra task)', () {
      expect(cap(10000, 25, 1), 12500);
      expect(cap(10000, 25, 2), 15000);
      expect(cap(10000, 25, 3), 17500);
    });

    test('is exact integer arithmetic, not floating point', () {
      // 3500 * 1.15 = 4024.999... in double; the integer formula must give 4025
      // so a legitimate 4025 price is not wrongly rejected (archi section 4.2).
      expect(cap(3500, 15, 1), 4025);
    });

    test('zero bonus never raises the ceiling (monthly)', () {
      expect(cap(150000, 0, 3), 150000);
    });
  });

  group('PricingConfig.fromMap', () {
    test('parses the grid and exposes per-mode bounds', () {
      final cfg = PricingConfig.fromMap(_gridMap());
      expect(cfg.version, 1);
      expect(cfg.currency, 'XOF');
      expect(cfg.maxExtraTasks, 3);
      expect(cfg.boundedCategories, contains('cuisine'));
      expect(cfg.boundedCategories, contains('repassage'));

      final hourly = cfg.boundsFor(PriceType.hourly)!;
      expect(hourly.min, 1000);
      expect(hourly.max, 3500);
      expect(hourly.extraBonusPercent, 25);
      expect(hourly.isRange, isFalse);

      final monthly = cfg.boundsFor(PriceType.monthly)!;
      expect(monthly.min, 50000);
      expect(monthly.max, 150000);
      expect(monthly.extraBonusPercent, 0);
      expect(monthly.isRange, isTrue);
    });

    test('capFor delegates to cap with the mode bonus', () {
      final cfg = PricingConfig.fromMap(_gridMap());
      expect(cfg.boundsFor(PriceType.hourly)!.capFor(2), 5250);
      expect(cfg.boundsFor(PriceType.monthly)!.capFor(3), 150000);
    });

    test('isBounded reflects the bounded-category allowlist', () {
      final cfg = PricingConfig.fromMap(_gridMap());
      expect(cfg.isBounded('menage'), isTrue);
      expect(cfg.isBounded('cuisine'), isTrue);
      expect(cfg.isBounded('plomberie'), isFalse);
    });
  });

  group('PricingConfig.isCoherent', () {
    test('accepts a well-formed grid', () {
      expect(PricingConfig.fromMap(_gridMap()).isCoherent, isTrue);
    });

    test('rejects a grid whose floor is above its ceiling', () {
      final bad = _gridMap();
      (bad['modes'] as Map)['hourly'] = {
        'min': 9000,
        'max': 3500,
        'extraBonusPercent': 25,
      };
      expect(PricingConfig.fromMap(bad).isCoherent, isFalse);
    });

    test('rejects a grid missing a bounded mode', () {
      final bad = _gridMap();
      (bad['modes'] as Map).remove('monthly');
      expect(PricingConfig.fromMap(bad).isCoherent, isFalse);
    });

    test('rejects a negative bonus', () {
      final bad = _gridMap();
      (bad['modes'] as Map)['daily'] = {
        'min': 2000,
        'max': 10000,
        'extraBonusPercent': -5,
      };
      expect(PricingConfig.fromMap(bad).isCoherent, isFalse);
    });
  });
}
