import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/review.dart';
import '../../domain/repositories/review_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreReviewRepository implements ReviewRepository {
  const FirestoreReviewRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Review>> watchForBooking(String bookingId) {
    return FirestoreCollections.reviews(_db)
        .where('bookingId', isEqualTo: bookingId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Stream<List<Review>> watchForUser(String userId) {
    return FirestoreCollections.reviews(_db)
        .where('revieweeId', isEqualTo: userId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Future<Review> create(Review review) async {
    final col = FirestoreCollections.reviews(_db);
    // Deterministic id enforces one review per (booking, reviewer): a second
    // submission becomes an update, which the Firestore create-only rule
    // rejects. Prevents duplicate/spam reviews skewing the average.
    final ref = col.doc('${review.bookingId}_${review.reviewerId}');
    await ref.set(review);
    final snap = await ref.get();
    return snap.data()!;
  }
}
