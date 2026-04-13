import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreUserRepository implements UserRepository {
  const FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<AppUser?> watchById(String userId) {
    return FirestoreCollections.users(_db)
        .doc(userId)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  @override
  Future<AppUser?> getById(String userId) async {
    final snap = await FirestoreCollections.users(_db).doc(userId).get();
    return snap.exists ? snap.data() : null;
  }

  @override
  Future<void> upsert(AppUser user) async {
    await FirestoreCollections.users(_db)
        .doc(user.id)
        .set(user, SetOptions(merge: true));
  }

  @override
  Future<bool> isPhoneTaken(String phoneE164, {String? excludeUid}) async {
    final snap = await FirestoreCollections.users(_db)
        .where('phoneE164', isEqualTo: phoneE164)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;
    if (excludeUid != null && snap.docs.first.id == excludeUid) return false;
    return true;
  }
}
