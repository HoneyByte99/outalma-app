/// A PII-free public view of a user, mirrored server-side into the
/// world-readable `public_profiles` collection.
///
/// Guests (and signed-in users alike) resolve provider and reviewer display
/// info from here, so the `users` collection - which holds email and phone -
/// never has to be opened to the public. Carries only display fields plus a
/// derived `phoneVerified` boolean (never the number itself).
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.displayName,
    this.photoPath,
    this.country,
    this.phoneVerified = false,
  });

  final String id;
  final String displayName;
  final String? photoPath;
  final String? country;
  final bool phoneVerified;
}
