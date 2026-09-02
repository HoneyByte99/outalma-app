import '../models/public_profile.dart';

abstract interface class PublicProfileRepository {
  /// Streams the public projection of [uid], or null when no document exists
  /// (unknown uid, or an account deleted since the reference was written).
  Stream<PublicProfile?> watchById(String uid);
}
