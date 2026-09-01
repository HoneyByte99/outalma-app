import 'dart:math' as math;

import '../models/service_zone.dart';

/// Great-circle distance in kilometers between two coordinates.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _deg2rad(double deg) => deg * (math.pi / 180);

/// A distance in km, rounded for reading rather than for precision.
///
/// One decimal below 10 km, whole kilometers above. Under 10 km the decimal is
/// the difference between "same street" and "across town", so it earns its
/// character; above it, a tenth of a kilometer on a great-circle estimate is
/// noise the display would be pretending to know.
///
/// Shared by every surface that shows a distance, so the service card and the
/// booking detail cannot drift apart on the rounding.
String formatDistanceKm(double km) =>
    km < 10 ? km.toStringAsFixed(1) : km.round().toString();

/// Whether a zone carries usable coordinates.
///
/// (0, 0) is the repo's marker for "the provider typed a label but no position
/// was resolved", not a point in the Gulf of Guinea. A zone like that must
/// never take part in a distance computation: it would win every "closest"
/// contest run from Dakar or Paris by several thousand kilometers.
bool zoneIsLocatable(ServiceZone zone) =>
    zone.latitude != 0 || zone.longitude != 0;

/// Closest zone to a target coordinate, with the distance in km.
/// Returns null if [zones] is empty.
({ServiceZone zone, double km})? closestZoneKm(
  List<ServiceZone> zones,
  double targetLat,
  double targetLng,
) {
  if (zones.isEmpty) return null;
  ServiceZone? best;
  double bestKm = double.infinity;
  for (final z in zones) {
    final km = haversineKm(z.latitude, z.longitude, targetLat, targetLng);
    if (km < bestKm) {
      bestKm = km;
      best = z;
    }
  }
  return (zone: best!, km: bestKm);
}
