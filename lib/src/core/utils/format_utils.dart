import 'package:intl/intl.dart';

final _priceFormatter = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: 'F CFA',
  decimalDigits: 0,
);

final _amountFormatter = NumberFormat.decimalPattern('fr_FR');

/// Formats a whole-FCFA price as a currency string, e.g. `1500` -> `1 500 F CFA`.
///
/// Prices are stored as whole FCFA (spec decision 3): no cents, no division by
/// a hundred. This replaces the former `formatPriceFromCents`, which divided by
/// 100 and made every seeded listing display at a hundredth of its real price.
String formatPrice(int fcfa) => _priceFormatter.format(fcfa);

/// Formats a monthly price range, e.g. `60000, 90000` -> `60 000 - 90 000 F CFA`.
///
/// The currency symbol appears once, on the high end, so the range reads as a
/// single amount rather than two separate prices.
String formatPriceRange(int min, int max) =>
    '${_amountFormatter.format(min)} - ${_priceFormatter.format(max)}';

/// Formats a whole number with fr_FR thousands grouping and no currency symbol,
/// e.g. `1000` -> `1 000`. Used to inject range bounds into localised strings
/// that already carry the `F CFA` suffix themselves.
String formatAmount(int value) => _amountFormatter.format(value);
