import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreUserRepository implements UserRepository {
  const FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<AppUser?> watchById(String userId) {
    return FirestoreCollections.users(
      _db,
    ).doc(userId).snapshots().map((snap) => snap.exists ? snap.data() : null);
  }

  @override
  Future<AppUser?> getById(String userId) async {
    final snap = await FirestoreCollections.users(_db).doc(userId).get();
    return snap.exists ? snap.data() : null;
  }

  @override
  Future<void> upsert(AppUser user) async {
    await FirestoreCollections.users(
      _db,
    ).doc(user.id).set(user, SetOptions(merge: true));
  }

  @override
  Future<void> setProfileImage({
    required String userId,
    required String? photoPath,
    required String? avatarId,
  }) async {
    // Untyped on purpose: FieldValue.delete() cannot travel through the typed
    // AppUser converter, and it is the only way to REMOVE a key rather than
    // set it to null. A stored null would make `photoPath` and `avatarId`
    // present-but-empty, which the projection already treats as absent, but
    // leaving the key behind on a document that is mirrored world-readable is
    // worth avoiding.
    //
    // Only these two keys are sent, so nothing else on the document can be
    // clobbered by a stale in-memory copy.
    await FirestoreCollections.usersRaw(_db).doc(userId).set({
      'photoPath': photoPath ?? FieldValue.delete(),
      'avatarId': avatarId ?? FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}
