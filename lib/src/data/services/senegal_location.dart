/// Client-side mirror of the server's Senegal-only location gate
/// (CADRAGE section 5). The server (`createBooking`) is the source of truth and
/// refuses the same cases; this exists so the client can warn and block BEFORE
/// a round trip, with an explicit message.
///
/// The two signals match the server exactly:
///  - a resolved ISO `countryCode` (must be SN when known), and
///  - `lat`/`lng` checked against Senegal's bounding box (coordinates are harder
///    to get wrong than a label, so they are checked even alongside a country).
///
/// A missing/partial signal is NOT treated as foreign: the gate refuses what it
/// can prove is outside Senegal, it does not demand proof the client may lack.
library;

/// Padded bounding box for Senegal, identical to the server's. Mainland Senegal
/// spans roughly lat 12.3..16.7 and lng -17.6..-11.3; the padding avoids
/// rejecting a coastal or border geocode that lands just outside the tight hull.
/// The purpose is to reject France/Europe/other continents, not to adjudicate
/// the Gambia border.
const double kSenegalLatMin = 12.0;
const double kSenegalLatMax = 17.0;
const double kSenegalLngMin = -17.9;
const double kSenegalLngMax = -11.0;

/// Whether [lat]/[lng] fall inside the Senegal bounding box.
bool isWithinSenegalBox(double lat, double lng) {
  return lat >= kSenegalLatMin &&
      lat <= kSenegalLatMax &&
      lng >= kSenegalLngMin &&
      lng <= kSenegalLngMax;
}

/// Outcome of evaluating a candidate service location.
enum SenegalLocationResult {
  /// Known to be in Senegal, or no signal proves otherwise: allowed.
  ok,

  /// Provably outside Senegal: the client must block and show a message.
  outside,
}

/// Evaluates a candidate service location against the Senegal gate. Mirrors the
/// server's `assertServiceLocationInSenegal`.
SenegalLocationResult evaluateSenegalLocation({
  String? countryCode,
  double? lat,
  double? lng,
}) {
  final cc = countryCode?.trim().toUpperCase();
  if (cc != null && cc.isNotEmpty && cc != 'SN') {
    return SenegalLocationResult.outside;
  }
  if (lat != null && lng != null && !isWithinSenegalBox(lat, lng)) {
    return SenegalLocationResult.outside;
  }
  return SenegalLocationResult.ok;
}
