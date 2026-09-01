import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/review.dart';
import '../../domain/repositories/review_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreReviewRepository implements ReviewRepository {
  const FirestoreReviewRepository(this._db);

  final FirebaseFirestore _db;

  /// Reviews on one booking, moderated ones INCLUDED, deliberately.
  ///
  /// `hasReviewedProvider` reads this to know whether the user has already left
  /// a review. Filtering `hidden` here would offer the form a second time, and
  /// the write would then be refused: the document id is deterministic
  /// (`{bookingId}_{reviewerId}`), so a second attempt is an update, and the
  /// rule is create-only. A visible dead end.
  @override
  Stream<List<Review>> watchForBooking(String bookingId) {
    return FirestoreCollections.reviews(_db)
        .where('bookingId', isEqualTo: bookingId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  /// Reviews received by [userId], moderated ones EXCLUDED.
  ///
  /// `hideReview` sets `hidden: true` server-side and the aggregate already
  /// skips those, but nothing on this side did: a moderated review stayed fully
  /// visible on the profile, on the reviews page and on the author's own "my
  /// reviews" screen, which made moderation cosmetic on every list.
  ///
  /// Filtered here in the data layer rather than per screen, so a surface added
  /// later cannot forget it. Client-side filtering is not a security boundary:
  /// the rule still allows any signed-in account to read the documents, and
  /// tightening it needs a moderator exemption plus emulator tests.
  @override
  Stream<List<Review>> watchForUser(String userId) {
    return FirestoreCollections.reviews(_db)
        .where('revieweeId', isEqualTo: userId)
        .snapshots()
        .map(
          (qs) => qs.docs.map((d) => d.data()).where((r) => !r.hidden).toList(),
        );
  }

  @override
  Stream<List<Review>> watchRecentForUser(String userId, {required int limit}) {
    // Ordered AND bounded: without the order the average would cover an
    // arbitrary slice ordered by document id, which is worse than unbounded.
    // The composite index (revieweeId ASC, createdAt DESC) already exists.
    //
    // Moderated reviews are excluded, like watchForUser above: a hidden review
    // must not keep counting in a client's reputation on the screen where a
    // provider decides whether to accept.
    //
    // The filter runs AFTER the limit, so a window of 50 documents can yield
    // fewer than 50 kept reviews. Accepted: filtering server-side would need an
    // index and a rule change, and this reputation is a bounded sample by
    // design, not an exact count.
    return FirestoreCollections.reviews(_db)
        .where('revieweeId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (qs) => qs.docs.map((d) => d.data()).where((r) => !r.hidden).toList(),
        );
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
