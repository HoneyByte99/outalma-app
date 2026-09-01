import '../../../l10n/app_localizations.dart';
import '../../domain/models/service.dart';
import '../../domain/utils/distance.dart';

/// Where a service operates, as one short line for a listing card.
///
/// The home grid already computed this distance and threw it away: it ran
/// `haversineKm` between every zone of a service and the active location filter
/// to DECIDE whether to show the card, then displayed nothing about it. The
/// client was left with a filtered list and no idea why any given result was in
/// it, or which of the two results was nearer.
///
/// Returns null when the service carries no zone at all, so the caller renders
/// nothing rather than an empty line.
///
/// ## The distance appears only when a filter is active
///
/// [origin] is the client's active location filter, null when there is none.
/// With no origin there is no reference point, and a bare "12 km" would be a
/// number measured from somewhere the client never named: it would read as
/// "12 km from you" while actually meaning "12 km from the first zone in the
/// list". So without a filter this shows the zone alone.
///
/// ## Which zone, when a service covers several
///
/// A provider can list several intervention zones ("Dakar Plateau", "Rufisque",
/// "Pikine"). The rule is explicit:
///
///  - With an [origin]: the CLOSEST locatable zone, with its distance. That is
///    the zone that answers the question the client just asked by setting a
///    filter, and it matches the reason the card passed the filter in the first
///    place, which is that SOME zone was in range. Showing any other zone would
///    display a distance larger than the one that let the card through.
///  - Without an [origin]: the FIRST zone, plus a count of the others. First
///    because a provider enters the zone they care most about first, and there
///    is no reference point that would make any other choice less arbitrary.
///    The count matters: dropping it would let a client read "Rufisque" and
///    conclude the provider does not cover Dakar, when they do.
///
/// Zones at (0, 0) are excluded from the distance computation but NOT from the
/// labelling. See [zoneIsLocatable]: those coordinates mean the provider typed a
/// place name that never resolved to a position. The name is still true and
/// still worth showing; only the arithmetic on it would be false.
String? serviceLocationLabel(
  Service service,
  AppLocalizations l10n, {
  ({double lat, double lng})? origin,
}) {
  final zones = service.serviceZones;
  if (zones.isEmpty) return null;

  if (origin != null) {
    final locatable = zones.where(zoneIsLocatable).toList();
    final closest = locatable.isEmpty
        ? null
        : closestZoneKm(locatable, origin.lat, origin.lng);
    if (closest != null) {
      return l10n.serviceZoneWithDistance(
        closest.zone.label,
        formatDistanceKm(closest.km),
      );
    }
    // A filter is set but no zone of this service can be measured against it.
    // Falls through to the label-only form rather than inventing a distance.
  }

  final first = zones.first.label;
  final others = zones.length - 1;
  return others == 0 ? first : l10n.serviceZoneWithMore(first, others);
}
