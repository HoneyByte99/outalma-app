import '../models/app_user.dart';

abstract interface class UserRepository {
  Stream<AppUser?> watchById(String userId);

  Future<AppUser?> getById(String userId);
  Future<void> upsert(AppUser user);
}
