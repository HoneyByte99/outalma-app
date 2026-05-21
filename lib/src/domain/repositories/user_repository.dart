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
}
