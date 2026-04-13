import '../models/app_user.dart';

abstract interface class UserRepository {
  Stream<AppUser?> watchById(String userId);

  Future<AppUser?> getById(String userId);
  Future<void> upsert(AppUser user);

  /// Returns `true` if [phoneE164] is already used by another user
  /// (excluding [excludeUid] if provided — useful for profile updates).
  Future<bool> isPhoneTaken(String phoneE164, {String? excludeUid});
}
