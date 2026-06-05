import 'package:intl/intl.dart';

final _priceFormatter = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: 'F CFA',
  decimalDigits: 0,
);

/// Formats a price stored in cents as a currency string,
/// e.g. `1500` -> `1 500 F CFA`.
String formatPriceFromCents(int cents) => _priceFormatter.format(cents / 100);
