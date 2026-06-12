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
  Stream<Set<String>> watchPausedProviderIds() {
    // Only providers who explicitly paused (active == false). Docs missing the
    // field don't match `== false`, which is correct: missing = available.
    return FirestoreCollections.providers(_db)
        .where('active', isEqualTo: false)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.id).toSet());
  }

  @override
  Future<void> upsert(ProviderProfile profile) async {
    final ref = FirestoreCollections.providers(_db).doc(profile.uid);
    final existing = await ref.get();
    if (existing.exists) {
      // Update: write only the owner-editable profile fields via an explicit
      // map. `suspended`/`suspendedAt`/`suspendedReason`/`createdAt` are
      // server-authoritative (moderation Cloud Functions only). `active`
      // (availability) is owner-controlled but flipped via [setActive], not
      // here, so a profile edit never disturbs availability.
      await ref.update(<String, Object?>{
        'bio': profile.bio,
        'workingHourStart': profile.workingHourStart,
        'workingHourEnd': profile.workingHourEnd,
      });
    } else {
      // Create: write the full document, including the initial
      // active/suspended state and createdAt.
      await ref.set(profile);
    }
  }

  @override
  Future<void> setActive(String uid, bool active) async {
    // Targeted single-field write — the diff touches only `active`, which the
    // Firestore `providers` update rule permits the owner (but not `suspended`).
    await FirestoreCollections.providers(
      _db,
    ).doc(uid).update({'active': active});
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
