import '../models/identity_verification_record.dart';

/// Reads a provider's own latest identity verification file (archi 5.6).
///
/// Separate from `IdentityTrustRepository`, which reads the public projection:
/// the projection says the state to everyone, this reads the private history to
/// its owner only. Two readers, two collections, one on a world-readable
/// document and one gated to the owner by the Firestore rules.
abstract interface class IdentityVerificationRepository {
  /// Streams the provider's most recent file, or null when they have none.
  ///
  /// Query: `where providerId == uid order by submittedAt desc limit 1`, which
  /// needs the composite index declared in the same increment (archi D2).
  Stream<IdentityVerificationRecord?> watchLatest(String uid);
}
