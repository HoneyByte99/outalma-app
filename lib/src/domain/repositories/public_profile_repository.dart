import '../models/public_profile.dart';

/// Read-only contract for the world-readable [PublicProfile] projection.
///
/// The projection is written exclusively by Cloud Functions, so there is no
/// write method here: clients only ever observe it.
abstract interface class PublicProfileRepository {
  Stream<PublicProfile?> watchById(String uid);
}
