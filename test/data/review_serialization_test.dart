// Verifies that Review objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// Critical cases:
//   - reviewerRole enum (client / provider) stored as string
//   - Rating boundary values: 1 (minimum) and 5 (maximum)
//   - Optional comment null / non-null
//   - createdAt Timestamp ↔ DateTime conversion

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';

Review _makeReview({
  String id = 'review_1',
  String bookingId = 'booking_1',
  String reviewerId = 'user_reviewer',
  String revieweeId = 'user_reviewee',
  ReviewerRole reviewerRole = ReviewerRole.client,
  int rating = 4,
  String? comment,
  DateTime? createdAt,
}) {
  return Review(
    id: id,
    bookingId: bookingId,
    reviewerId: reviewerId,
    revieweeId: revieweeId,
    reviewerRole: reviewerRole,
    rating: rating,
    comment: comment,
    createdAt: createdAt ?? DateTime(2024, 3, 10, 12, 0).toUtc(),
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('Review serialization — all fields', () {
    test('roundtrip preserves all fields', () async {
      final review = _makeReview(
        comment: 'Excellent travail, très professionnel.',
      );
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);
      final result = (await col.doc(review.id).get()).data()!;

      expect(result.id, review.id);
      expect(result.bookingId, 'booking_1');
      expect(result.reviewerId, 'user_reviewer');
      expect(result.revieweeId, 'user_reviewee');
      expect(result.reviewerRole, ReviewerRole.client);
      expect(result.rating, 4);
      expect(result.comment, 'Excellent travail, très professionnel.');
    });
  });

  group('Review serialization — null comment', () {
    test('null comment roundtrips as null', () async {
      final review = _makeReview(comment: null);
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);
      final result = (await col.doc(review.id).get()).data()!;
      expect(result.comment, isNull);
    });
  });

  group('Review serialization — rating boundaries', () {
    test('rating 1 (minimum) roundtrips correctly', () async {
      final review = _makeReview(rating: 1);
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);
      final result = (await col.doc(review.id).get()).data()!;
      expect(result.rating, 1);
    });

    test('rating 5 (maximum) roundtrips correctly', () async {
      final review = _makeReview(rating: 5);
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);
      final result = (await col.doc(review.id).get()).data()!;
      expect(result.rating, 5);
    });
  });

  group('Review serialization — reviewerRole enum', () {
    test('client role stored as "client" string', () async {
      final review = _makeReview(reviewerRole: ReviewerRole.client);
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);

      final raw =
          (await fakeDb.collection('reviews').doc(review.id).get()).data()!;
      expect(raw['reviewerRole'], 'client');

      final result = (await col.doc(review.id).get()).data()!;
      expect(result.reviewerRole, ReviewerRole.client);
    });

    test('provider role stored as "provider" string', () async {
      final review = _makeReview(
        id: 'review_provider',
        reviewerRole: ReviewerRole.provider,
      );
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);

      final raw = (await fakeDb
              .collection('reviews')
              .doc(review.id)
              .get())
          .data()!;
      expect(raw['reviewerRole'], 'provider');

      final result = (await col.doc(review.id).get()).data()!;
      expect(result.reviewerRole, ReviewerRole.provider);
    });

    test('unknown reviewerRole falls back to client', () async {
      await fakeDb.collection('reviews').doc('bad_role').set({
        'reviewerRole': 'admin',
        'rating': 3,
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.reviews(fakeDb);
      final result = (await col.doc('bad_role').get()).data()!;
      expect(result.reviewerRole, ReviewerRole.client);
    });
  });

  group('Review serialization — createdAt timestamp', () {
    test('createdAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 5, 1, 8, 0, 0).toUtc();
      final review = _makeReview(createdAt: t);
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);
      final result = (await col.doc(review.id).get()).data()!;

      expect(
        result.createdAt.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
      );
    });

    test('createdAt is stored as Firestore Timestamp', () async {
      final review = _makeReview();
      final col = FirestoreCollections.reviews(fakeDb);
      await col.doc(review.id).set(review);

      final raw =
          (await fakeDb.collection('reviews').doc(review.id).get()).data()!;
      expect(raw['createdAt'], isA<Timestamp>());
    });
  });

  group('Review serialization — safe defaults for missing fields', () {
    test('missing fields do not crash and use safe defaults', () async {
      await fakeDb.collection('reviews').doc('minimal').set({
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.reviews(fakeDb);
      final result = (await col.doc('minimal').get()).data()!;

      expect(result.bookingId, '');
      expect(result.reviewerId, '');
      expect(result.revieweeId, '');
      expect(result.reviewerRole, ReviewerRole.client);
      expect(result.rating, 1);
      expect(result.comment, isNull);
    });
  });
}
