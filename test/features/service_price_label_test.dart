// Tests for servicePriceLabel, the single client-facing price string shared by
// every display surface (spec AC-22, AC-14; scenarios SC-30, SC-41, SC-45).

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations_en.dart';
import 'package:outalma_app/l10n/app_localizations_fr.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/features/shared/service_price_label.dart';

// intl uses various Unicode spaces (narrow/regular no-break, thin) as the
// fr_FR thousands separator; collapse them to a plain space for assertions.
String _normalise(String s) =>
    s.replaceAll(RegExp('[\u00A0\u202F\u2009\u2007]'), ' ').trim();

Service _service({
  required PriceType priceType,
  required int price,
  int? priceMax,
}) {
  final now = DateTime(2026, 1, 1);
  return Service(
    id: 's1',
    providerId: 'p1',
    categoryId: CategoryId.menage,
    title: 'Test',
    photos: const [],
    priceType: priceType,
    price: price,
    priceMax: priceMax,
    published: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final fr = AppLocalizationsFr();
  final en = AppLocalizationsEn();

  group('servicePriceLabel (fr)', () {
    test('hourly renders the amount with the /h unit (SC-41)', () {
      final label = _normalise(
        servicePriceLabel(
          _service(priceType: PriceType.hourly, price: 2500),
          fr,
        ),
      );
      expect(label, '2 500 F CFA/h');
    });

    test('daily renders the amount with the /jour unit', () {
      final label = _normalise(
        servicePriceLabel(
          _service(priceType: PriceType.daily, price: 8000),
          fr,
        ),
      );
      expect(label, '8 000 F CFA/jour');
    });

    test('monthly renders a range with the /mois unit (SC-30)', () {
      final label = _normalise(
        servicePriceLabel(
          _service(priceType: PriceType.monthly, price: 60000, priceMax: 90000),
          fr,
        ),
      );
      expect(label, '60 000 - 90 000 F CFA/mois');
    });

    test('legacy fixed falls back to the daily unit (SC-45)', () {
      final label = _normalise(
        servicePriceLabel(
          _service(priceType: PriceType.fixed, price: 5000),
          fr,
        ),
      );
      expect(label, '5 000 F CFA/jour');
    });

    test('monthly with a missing max falls back to a single amount', () {
      final label = _normalise(
        servicePriceLabel(
          _service(priceType: PriceType.monthly, price: 50000),
          fr,
        ),
      );
      expect(label, '50 000 - 50 000 F CFA/mois');
    });
  });

  group('servicePriceLabel (en)', () {
    test('monthly uses the /mo unit', () {
      final label = _normalise(
        servicePriceLabel(
          _service(priceType: PriceType.monthly, price: 60000, priceMax: 90000),
          en,
        ),
      );
      expect(label, '60 000 - 90 000 F CFA/mo');
    });
  });
}
