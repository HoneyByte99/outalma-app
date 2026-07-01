import 'package:intl/intl.dart';

final _priceFormatter = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: 'F CFA',
  decimalDigits: 0,
);

/// Formats a price stored in cents as a currency string,
/// e.g. `1500` -> `1 500 F CFA`.
String formatPriceFromCents(int cents) => _priceFormatter.format(cents / 100);

/// Formats a distance in kilometers for compact display (e.g. on service
/// cards): `0.4` -> `400 m`, `1.2` -> `1,2 km`, `12.7` -> `13 km`.
/// Uses the French decimal comma to match the rest of the UI.
String formatDistanceKm(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return '${km.round()} km';
}
