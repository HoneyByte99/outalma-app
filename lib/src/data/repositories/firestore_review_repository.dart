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

  /// Reviews received by [userId], moderated ones EXCLUDED **by the query**.
  ///
  /// `hidden == false` is in the WHERE clause, not in a `.where()` on the Dart
  /// list, and that is a hard requirement rather than an optimisation. The
  /// public read rule is `signedIn() || resource.data.hidden == false`, and for
  /// a `list` Firestore evaluates rules against the fields the QUERY constrains,
  /// not against each returned document. An unconstrained list from a visitor
  /// with no account is therefore refused outright: PERMISSION_DENIED, an empty
  /// reviews section, and a red error state on the very screen where the client
  /// decides. Filtering afterwards in Dart cannot fix that, because the
  /// response never arrives.
  ///
  /// It also promotes moderation from cosmetic to enforced: before, the rule let
  /// any signed-in account read a hidden review and only the UI hid it.
  ///
  /// Hard prerequisite, same one the rule file states: every review document must
  /// CARRY `hidden`. A document lacking the field matches no equality query and
  /// would become invisible for ever. The client serializer always writes the
  /// literal `false`, `onReviewCreated` backfills clients already in the wild,
  /// and scripts/normalize-review-hidden.py cleared the historical corpus
  /// (verified: 36/36 production reviews carry the field).
  @override
  Stream<List<Review>> watchForUser(String userId) {
    return FirestoreCollections.reviews(_db)
        .where('revieweeId', isEqualTo: userId)
        .where('hidden', isEqualTo: false)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Stream<List<Review>> watchRecentForUser(String userId, {required int limit}) {
    // Ordered AND bounded: without the order the average would cover an
    // arbitrary slice ordered by document id, which is worse than unbounded.
    //
    // `hidden == false` is server-side here for the same reason as
    // watchForUser: a visitor cannot list this collection without it.
    //
    // Side benefit worth recording, since the previous note said the opposite:
    // the filter now runs BEFORE the limit, so the window really is the 50 most
    // recent VISIBLE reviews. It used to be the 50 most recent documents minus
    // whatever was hidden among them, which quietly shrank a client's
    // reputation sample every time a review was moderated.
    //
    // Needs the composite index (revieweeId ASC, hidden ASC, createdAt DESC),
    // declared in firebase/firestore.indexes.json.
    return FirestoreCollections.reviews(_db)
        .where('revieweeId', isEqualTo: userId)
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
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
