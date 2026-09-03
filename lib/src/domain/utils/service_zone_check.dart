/// Client-side mirror of the server's zone-coverage gate (`createBooking`,
/// `functions/src/index.ts`): with a geocoded address and at least one
/// declared zone, the address must fall within at least one zone's radius. No
/// coordinates or no declared zones -> allowed (provider discretion), exactly
/// like the server. The server remains the source of truth; this exists so
/// the client can refuse and explain BEFORE a round trip.
library;

import '../models/service_zone.dart';
import 'distance.dart';

enum ServiceZoneCoverage {
  /// In a declared zone, or no signal to judge by: allowed.
  ok,

  /// Provably outside every declared zone: the client must block and explain.
  outside,
}

/// Evaluates [lat]/[lng] against [zones] using the same haversine-vs-radius
/// rule as the server.
ServiceZoneCoverage evaluateServiceZoneCoverage({
  required List<ServiceZone> zones,
  double? lat,
  double? lng,
}) {
  if (lat == null || lng == null) return ServiceZoneCoverage.ok;
  if (zones.isEmpty) return ServiceZoneCoverage.ok;
  final inZone = zones.any(
    (z) => haversineKm(lat, lng, z.latitude, z.longitude) <= z.radiusKm,
  );
  return inZone ? ServiceZoneCoverage.ok : ServiceZoneCoverage.outside;
}
