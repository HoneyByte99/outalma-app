import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/phone_share.dart';
import '../../domain/repositories/phone_share_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestorePhoneShareRepository implements PhoneShareRepository {
  const FirestorePhoneShareRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<PhoneShare>> watchForBooking(String bookingId) {
    return FirestoreCollections.phoneShares(db: _db, bookingId: bookingId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Future<void> share({
    required String bookingId,
    required String uid,
    required String phone,
  }) async {
    final ref = FirestoreCollections.phoneShares(db: _db, bookingId: bookingId)
        .doc(uid);
    await ref.set(
      PhoneShare(uid: uid, phone: phone, createdAt: DateTime.now().toUtc()),
      SetOptions(merge: true),
    );
  }
}
