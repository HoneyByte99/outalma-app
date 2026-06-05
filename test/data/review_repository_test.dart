// Tests for FirestoreReviewRepository using FakeFirebaseFirestore.
//
// Covered:
//   - watchForUser(userId): empty when no reviews, returns reviews where
//     revieweeId == userId, live updates
//   - watchForBooking(bookingId): returns both sides (client→provider AND
//     provider→client) for a booking
//   - create(review): writes to Firestore with correct fields, returns
//     persisted review with non-empty id

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/data/repositories/firestore_review_repository.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Review _makeReview({
  String id = 'review_1',
  String bookingId = 'booking_1',
  String reviewerId = 'user_A',
  String revieweeId = 'user_B',
  ReviewerRole reviewerRole = ReviewerRole.client,
  int rating = 5,
  String? comment,
}) {
  return Review(
    id: id,
    bookingId: bookingId,
    reviewerId: reviewerId,
    revieweeId: revieweeId,
    reviewerRole: reviewerRole,
    rating: rating,
    comment: comment,
    createdAt: DateTime(2024, 6, 1).toUtc(),
  );
}

Future<void> _writeReview(FakeFirebaseFirestore db, Review review) {
  return FirestoreCollections.reviews(db).doc(review.id).set(review);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreReviewRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestoreReviewRepository(fakeDb);
  });

  // -------------------------------------------------------------------------
  // watchForUser
  // -------------------------------------------------------------------------

  group('watchForUser', () {
    test('returns empty list when no reviews exist', () async {
      final list = await repo.watchForUser('user_X').first;
      expect(list, isEmpty);
    });

    test('returns reviews where revieweeId == userId', () async {
      // Review targeting user_B
      await _writeReview(
        fakeDb,
        _makeReview(id: 'r1', revieweeId: 'user_B', reviewerId: 'user_A'),
      );
      // Review targeting a different user
      await _writeReview(
        fakeDb,
        _makeReview(
          id: 'r2',
          revieweeId: 'user_C',
          reviewerId: 'user_A',
          bookingId: 'booking_2',
        ),
      );

      final list = await repo.watchForUser('user_B').first;
      expect(list.length, 1);
      expect(list.first.id, 'r1');
      expect(list.first.revieweeId, 'user_B');
    });

    test('does not return reviews for a different revieweeId', () async {
      await _writeReview(fakeDb, _makeReview(id: 'r1', revieweeId: 'user_B'));

      final list = await repo.watchForUser('user_Z').first;
      expect(list, isEmpty);
    });

    test('streams live updates when a new review is added', () async {
      final stream = repo.watchForUser('user_B');

      final events = <List<Review>>[];
      final subscription = stream.listen(events.add);
      addTearDown(subscription.cancel);

      // Initial empty state
      await Future<void>.delayed(Duration.zero);

      // Add a review targeting user_B
      await _writeReview(fakeDb, _makeReview(id: 'r1', revieweeId: 'user_B'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.length, 1);
      expect(events.last.first.revieweeId, 'user_B');
    });

    test('returns multiple reviews for the same reviewee', () async {
      await _writeReview(
        fakeDb,
        _makeReview(
          id: 'r1',
          bookingId: 'booking_1',
          revieweeId: 'user_B',
          reviewerId: 'user_A',
        ),
      );
      await _writeReview(
        fakeDb,
        _makeReview(
          id: 'r2',
          bookingId: 'booking_2',
          revieweeId: 'user_B',
          reviewerId: 'user_C',
        ),
      );

      final list = await repo.watchForUser('user_B').first;
      expect(list.length, 2);
      expect(list.map((r) => r.id), containsAll(['r1', 'r2']));
    });
  });

  // -------------------------------------------------------------------------
  // watchForBooking
  // -------------------------------------------------------------------------

  group('watchForBooking', () {
    test('returns empty list when no reviews exist for booking', () async {
      final list = await repo.watchForBooking('booking_1').first;
      expect(list, isEmpty);
    });

    test('returns both client→provider and provider→client reviews', () async {
      // Client reviews provider
      await _writeReview(
        fakeDb,
        _makeReview(
          id: 'r_client',
          bookingId: 'booking_1',
          reviewerId: 'user_A',
          revieweeId: 'user_B',
          reviewerRole: ReviewerRole.client,
        ),
      );
      // Provider reviews client
      await _writeReview(
        fakeDb,
        _makeReview(
          id: 'r_provider',
          bookingId: 'booking_1',
          reviewerId: 'user_B',
          revieweeId: 'user_A',
          reviewerRole: ReviewerRole.provider,
        ),
      );

      final list = await repo.watchForBooking('booking_1').first;
      expect(list.length, 2);
      expect(list.map((r) => r.id), containsAll(['r_client', 'r_provider']));
    });

    test('does not return reviews for a different booking', () async {
      await _writeReview(
        fakeDb,
        _makeReview(id: 'r1', bookingId: 'booking_OTHER'),
      );

      final list = await repo.watchForBooking('booking_1').first;
      expect(list, isEmpty);
    });

    test('returns correct reviewerRole for each side', () async {
      await _writeReview(
        fakeDb,
        _makeReview(
          id: 'r_client',
          bookingId: 'booking_1',
          reviewerRole: ReviewerRole.client,
        ),
      );
      await _writeReview(
        fakeDb,
        _makeReview(
          id: 'r_provider',
          bookingId: 'booking_1',
          reviewerId: 'user_B',
          revieweeId: 'user_A',
          reviewerRole: ReviewerRole.provider,
        ),
      );

      final list = await repo.watchForBooking('booking_1').first;
      final roles = list.map((r) => r.reviewerRole).toSet();
      expect(roles, containsAll([ReviewerRole.client, ReviewerRole.provider]));
    });
  });

  // -------------------------------------------------------------------------
  // create
  // -------------------------------------------------------------------------

  group('create', () {
    test('writes review to Firestore and returns it with an id', () async {
      final review = _makeReview(
        id: 'temp',
        bookingId: 'booking_1',
        reviewerId: 'user_A',
        revieweeId: 'user_B',
        rating: 4,
        comment: 'Très bien!',
      );

      final created = await repo.create(review);
      expect(created.id, isNotEmpty);
    });

    test('persists correct reviewerId, revieweeId, and bookingId', () async {
      final review = _makeReview(
        id: 'temp',
        bookingId: 'booking_42',
        reviewerId: 'user_X',
        revieweeId: 'user_Y',
        rating: 3,
      );

      await repo.create(review);

      final snap = await fakeDb.collection('reviews').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['reviewerId'], 'user_X');
      expect(data['revieweeId'], 'user_Y');
      expect(data['bookingId'], 'booking_42');
    });

    test('persists correct rating and comment', () async {
      final review = _makeReview(
        id: 'temp',
        rating: 5,
        comment: 'Excellent service',
      );

      await repo.create(review);

      final snap = await fakeDb.collection('reviews').get();
      final data = snap.docs.first.data();
      expect(data['rating'], 5);
      expect(data['comment'], 'Excellent service');
    });

    test('persists correct reviewerRole', () async {
      final review = _makeReview(
        id: 'temp',
        reviewerRole: ReviewerRole.provider,
      );

      await repo.create(review);

      final snap = await fakeDb.collection('reviews').get();
      final data = snap.docs.first.data();
      expect(data['reviewerRole'], 'provider');
    });

    test('created review appears in watchForBooking stream', () async {
      final review = _makeReview(
        id: 'temp',
        bookingId: 'booking_1',
        reviewerId: 'user_A',
        revieweeId: 'user_B',
      );

      await repo.create(review);

      final list = await repo.watchForBooking('booking_1').first;
      expect(list.length, 1);
      expect(list.first.reviewerId, 'user_A');
      expect(list.first.revieweeId, 'user_B');
    });

    test(
      'before create: watchForBooking returns empty; after: returns review',
      () async {
        // Before
        final before = await repo.watchForBooking('booking_1').first;
        expect(before, isEmpty);

        // Create
        await repo.create(_makeReview(id: 'temp', bookingId: 'booking_1'));

        // After
        final after = await repo.watchForBooking('booking_1').first;
        expect(after.length, 1);
      },
    );
  });
}
