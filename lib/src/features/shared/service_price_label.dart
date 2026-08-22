import '../../../l10n/app_localizations.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/enums/price_type.dart';
import '../../domain/models/service.dart';

/// The price label for a service, in whole FCFA with the mode's unit suffix.
///
/// The single source of the client-facing price string, shared by every
/// display surface so the amount and its unit cannot drift between screens
/// (spec AC-22). Monthly listings render a range (low - high, spec AC-14);
/// hourly and daily render a single amount. A legacy `fixed` listing that
/// somehow survives the migration falls back to the daily unit, matching the
/// migration's `fixed` -> `daily` rewrite (spec decision 11, scenario SC-45).
String servicePriceLabel(Service service, AppLocalizations l10n) {
  switch (service.priceType) {
    case PriceType.monthly:
      final max = service.priceMax ?? service.price;
      return '${formatPriceRange(service.price, max)}${l10n.priceUnitMonthly}';
    case PriceType.daily:
    case PriceType.fixed:
      return '${formatPrice(service.price)}${l10n.priceUnitDaily}';
    case PriceType.hourly:
      return '${formatPrice(service.price)}${l10n.priceUnitHourly}';
  }
}
