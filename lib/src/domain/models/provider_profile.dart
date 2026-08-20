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
    this.workingHourStart,
    this.workingHourEnd,
    this.identityVerified = false,
  });

  final String uid;
  final String? bio;

  /// Public identity badge (D6-a). Server-owned boolean, written ONLY by the
  /// decision Cloud Function (approve sets it true, reject and revoke set it
  /// false). Firestore rules forbid the owner from writing it, so this value is
  /// trustworthy: the "Verified" badge reads it and nothing else. Absent field
  /// means not verified. Replaces the old phone-number heuristic (E7/D6).
  final bool identityVerified;

  /// Daily working-hours window [start, end) in 24h local hours. Null when the
  /// provider hasn't configured it: callers fall back to the k* defaults.
  /// Clients can offer bookings only on hourly slots inside this window.
  final int? workingHourStart;
  final int? workingHourEnd;

  /// Provider-controlled availability. `true` = "Disponible" (listings visible
  /// & bookable); `false` = "En pause" (the provider hid their whole catalogue
  /// to manage their schedule). Non-destructive: it never touches each service's
  /// `published` flag, so resuming restores everything instantly. Distinct from
  /// [suspended], which is admin moderation. Server-authoritative gate lives in
  /// `createBooking`; discovery filters paused providers client-side.
  final bool active;

  /// Admin moderation flag (set only by suspendProvider/unsuspendProvider).
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
    int? workingHourStart,
    int? workingHourEnd,
    bool? active,
    bool? suspended,
    DateTime? createdAt,
    bool? identityVerified,
  }) {
    return ProviderProfile(
      uid: uid,
      bio: bio ?? this.bio,
      workingHourStart: workingHourStart ?? this.workingHourStart,
      workingHourEnd: workingHourEnd ?? this.workingHourEnd,
      active: active ?? this.active,
      suspended: suspended ?? this.suspended,
      createdAt: createdAt ?? this.createdAt,
      identityVerified: identityVerified ?? this.identityVerified,
    );
  }
}
