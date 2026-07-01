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

/// Like [closestZoneKm] but ignores unset placeholder zones sitting at the
/// null island (0,0): those mean "no coordinate captured yet", not a real
/// location, and would otherwise register as an absurd ~5000 km match.
/// Returns null when no geolocated zone remains.
({ServiceZone zone, double km})? closestRealZoneKm(
  List<ServiceZone> zones,
  double targetLat,
  double targetLng,
) {
  final real = zones
      .where((z) => !(z.latitude == 0 && z.longitude == 0))
      .toList();
  return closestZoneKm(real, targetLat, targetLng);
}
