import '../models/app_user.dart';

/// Repository contract for the [AppUser] aggregate.
///
/// Phone uniqueness is **not** exposed here — it is enforced server-side by
/// the `verifyPhoneOtpAndSignUp` Cloud Function, which is the only legitimate
/// path for claiming a phone number.
abstract interface class UserRepository {
  Stream<AppUser?> watchById(String userId);

  Future<AppUser?> getById(String userId);
  Future<void> upsert(AppUser user);

  /// Writes ONLY the two profile-image fields, each null meaning "erase".
  ///
  /// Separate from [upsert] on purpose. [upsert] sends the whole document as a
  /// merge, so it cannot express an erasure: an explicit null there would also
  /// clobber a value written by another device whose change this client has not
  /// read back, which is the hazard the `pushToken` and `gender` comments in
  /// the converter already describe. Writing the two fields on their own keeps
  /// the erasure precise and touches nothing else.
  ///
  /// The two are written together because they are mutually exclusive: a photo
  /// clears the avatar, an avatar clears the photo, and "none" clears both.
  Future<void> setProfileImage({
    required String userId,
    required String? photoPath,
    required String? avatarId,
  });
}
