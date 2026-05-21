import 'package:intl/intl.dart';

final _priceFormatter = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 0,
);

/// Formats a price stored in cents as a French-locale currency string with
/// a thin-space thousands separator, e.g. `1500` -> `1 500 €`.
String formatPriceFromCents(int cents) =>
    _priceFormatter.format(cents / 100);
