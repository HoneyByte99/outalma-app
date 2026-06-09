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
  });

  final String uid;
  final String? bio;

  /// Human-readable service-area label (geocoded address).
  final String? serviceArea;

  /// Geocoded coordinates for [serviceArea]. Both are null for legacy profiles
  /// created before address geocoding was enforced.
  final double? serviceAreaLat;
  final double? serviceAreaLng;

  final bool active;
  final bool suspended;
  final DateTime createdAt;

  ProviderProfile copyWith({
    String? bio,
    String? serviceArea,
    double? serviceAreaLat,
    double? serviceAreaLng,
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
      active: active ?? this.active,
      suspended: suspended ?? this.suspended,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
