import '../enums/gender.dart';

/// The PII-free public view of a user, mirrored server-side into the
/// world-readable `public_profiles` collection.
///
/// Every surface a visitor without an account can reach resolves display info
/// from here, never from `users/{uid}`: that document carries `email` and
/// `phoneE164`, and its rule is `allow read: if signedIn()`. A guest reading it
/// gets PERMISSION_DENIED, so a public card that read it showed no name at all.
///
/// Carries display fields plus a DERIVED [phoneVerified] boolean: whether a
/// number is on file, never the number. Written exclusively by the
/// `mirrorPublicProfile` Cloud Function (client writes are denied), so the
/// projection cannot be poisoned and cannot drift into holding PII.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.displayName,
    this.photoPath,
    this.country,
    this.phoneVerified = false,
    this.gender,
    this.avatarId,
  });

  final String id;
  final String displayName;
  final String? photoPath;

  /// ISO country code. Nullable here, unlike `AppUser.country`: the projection
  /// omits the field for a user who never set one (42 of 50 documents in
  /// production carry it), and defaulting it to 'FR' on a public profile would
  /// invent a location for the eight who did not.
  final String? country;

  /// Whether a verified phone number is on file. The trust badge on a public
  /// profile reads this, so it never has to touch `phoneE164`.
  final bool phoneVerified;

  /// The gender the provider declared at sign-up, projected here because the
  /// surfaces that show it are GUEST surfaces: the catalogue card and the
  /// service detail both resolve the provider through this document, never
  /// through `users/{uid}`, which a visitor cannot read.
  ///
  /// Nullable like [country], and for the same reason turned up one notch: an
  /// account created before the field existed has none, and a default would
  /// print a pictogram asserting a gender the person never declared.
  final Gender? gender;

  /// The illustrated avatar, mirrored from `users` so the guest-reachable
  /// surfaces can draw it: the catalogue card, the public provider profile and
  /// the review rows all resolve their person through this document.
  final String? avatarId;
}
