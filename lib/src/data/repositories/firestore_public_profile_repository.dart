import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/public_profile.dart';
import '../../domain/repositories/public_profile_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestorePublicProfileRepository implements PublicProfileRepository {
  const FirestorePublicProfileRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<PublicProfile?> watchById(String uid) {
    return FirestoreCollections.publicProfiles(
      _db,
    ).doc(uid).snapshots().map((snap) => snap.exists ? snap.data() : null);
  }
}
