import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/blocked_slot.dart';
import '../../domain/models/provider_profile.dart';
import '../../domain/repositories/provider_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreProviderRepository implements ProviderRepository {
  const FirestoreProviderRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<ProviderProfile?> watchByUid(String uid) {
    return FirestoreCollections.providers(
      _db,
    ).doc(uid).snapshots().map((snap) => snap.exists ? snap.data() : null);
  }

  @override
  Stream<List<ProviderProfile>> watchAll() {
    return FirestoreCollections.providers(_db)
        .where('active', isEqualTo: true)
        .where('suspended', isEqualTo: false)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Future<void> upsert(ProviderProfile profile) async {
    await FirestoreCollections.providers(
      _db,
    ).doc(profile.uid).set(profile, SetOptions(merge: true));
  }

  // -- Blocked slots --

  @override
  Stream<List<BlockedSlot>> watchBlockedSlots(String uid) {
    return FirestoreCollections.blockedSlots(_db, uid)
        .orderBy('date')
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Future<void> addBlockedSlot(String uid, BlockedSlot slot) async {
    await FirestoreCollections.blockedSlots(_db, uid).add(slot);
  }

  @override
  Future<void> removeBlockedSlot(String uid, String slotId) async {
    await FirestoreCollections.blockedSlots(_db, uid).doc(slotId).delete();
  }
}
