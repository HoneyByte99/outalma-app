/// Default working-hours window applied when a provider has not set their own
/// (legacy profiles, or before they configure availability).
const int kDefaultWorkingHourStart = 8;
const int kDefaultWorkingHourEnd = 18;

class ProviderProfile {
  const ProviderProfile({
    required this.uid,
    required this.active,
    required this.suspended,
    required this.createdAt,
    this.bio,
    this.serviceArea,
    this.serviceAreaLat,
    this.serviceAreaLng,
    this.workingHourStart,
    this.workingHourEnd,
  });

  final String uid;
  final String? bio;

  /// Human-readable service-area label (geocoded address).
  final String? serviceArea;

  /// Geocoded coordinates for [serviceArea]. Both are null for legacy profiles
  /// created before address geocoding was enforced.
  final double? serviceAreaLat;
  final double? serviceAreaLng;

  /// Daily working-hours window [start, end) in 24h local hours. Null when the
  /// provider hasn't configured it — callers fall back to the k* defaults.
  /// Clients can offer bookings only on hourly slots inside this window.
  final int? workingHourStart;
  final int? workingHourEnd;

  final bool active;
  final bool suspended;
  final DateTime createdAt;

  /// Effective working window, applying defaults for unset/invalid values.
  int get effectiveHourStart => workingHourStart ?? kDefaultWorkingHourStart;
  int get effectiveHourEnd {
    final end = workingHourEnd ?? kDefaultWorkingHourEnd;
    // Guard against a misconfigured window (end <= start).
    return end > effectiveHourStart ? end : kDefaultWorkingHourEnd;
  }

  ProviderProfile copyWith({
    String? bio,
    String? serviceArea,
    double? serviceAreaLat,
    double? serviceAreaLng,
    int? workingHourStart,
    int? workingHourEnd,
    bool? active,
    bool? suspended,
    DateTime? createdAt,
  }) {
    return ProviderProfile(
      uid: uid,
      bio: bio ?? this.bio,
      serviceArea: serviceArea ?? this.serviceArea,
      serviceAreaLat: serviceAreaLat ?? this.serviceAreaLat,
      serviceAreaLng: serviceAreaLng ?? this.serviceAreaLng,
      workingHourStart: workingHourStart ?? this.workingHourStart,
      workingHourEnd: workingHourEnd ?? this.workingHourEnd,
      active: active ?? this.active,
      suspended: suspended ?? this.suspended,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
