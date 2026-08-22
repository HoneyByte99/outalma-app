import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/enums/identity_trust_status.dart';
import '../../domain/repositories/identity_trust_repository.dart';

/// Reads `provider_trust/{uid}`, the server-owned public projection.
///
/// One document, two fields, no personal data: the whole point of the
/// collection is that it can be world readable without exposing anything. No
/// client can write it (Firestore rules `write: if false`), so what is read
/// here is always what the decision transaction wrote.
class FirestoreIdentityTrustRepository implements IdentityTrustRepository {
  FirestoreIdentityTrustRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<IdentityTrustStatus?> watch(String uid) {
    return _db.collection('provider_trust').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return IdentityTrustStatus.fromString(
        snap.data()?['identityStatus'] as String?,
      );
    });
  }
}
