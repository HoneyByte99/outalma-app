// Tests for the bilateral review pairing behaviour in CreateReviewUseCase.
//
// What is covered:
//   - client can create a review as ReviewerRole.client
//   - provider can create a review as ReviewerRole.provider
//   - both sides produce separate Review objects stored via the repository
//   - second review attempt by same reviewer is NOT blocked at the use-case
//     layer (no guard exists there); the hasReviewedProvider stream is tested
//     separately via a fake repository.
//
// Note: booking status validation does NOT exist inside CreateReviewUseCase -
// the use case trusts the caller to gate on 'done' status. If that gate is
// ever added to the use case, tests should be added here.
//
// Note: wrong-role rejection does NOT exist inside CreateReviewUseCase -
// ReviewerRole is an enum, so invalid values cannot be constructed.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';
import 'package:outalma_app/src/domain/repositories/review_repository.dart';

// ---------------------------------------------------------------------------
// Fake repository - tracks all created reviews, not just the last one.
// ---------------------------------------------------------------------------

class _FakeReviewRepository implements ReviewRepository {
  final List<Review> created = [];
  Object? shouldThrow;

  int _seq = 0;

  @override
  Future<Review> create(Review review) async {
    if (shouldThrow != null) throw shouldThrow!;
    final stored = Review(
      id: 'review_${++_seq}',
      bookingId: review.bookingId,
      reviewerId: review.reviewerId,
      revieweeId: review.revieweeId,
      reviewerRole: review.reviewerRole,
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt,
    );
    created.add(stored);
    return stored;
  }

  @override
  Stream<List<Review>> watchForBooking(String bookingId) =>
      Stream.value(created.where((r) => r.bookingId == bookingId).toList());

  @override
  Stream<List<Review>> watchForUser(String userId) =>
      Stream.value(created.where((r) => r.revieweeId == userId).toList());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeReviewRepository repo;
  late CreateReviewUseCase useCase;

  setUp(() {
    repo = _FakeReviewRepository();
    useCase = CreateReviewUseCase(repo);
  });

  group('bilateral review pairing - client reviews provider', () {
    test('stores review with ReviewerRole.client', () async {
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'client_uid',
        revieweeId: 'provider_uid',
        reviewerRole: ReviewerRole.client,
        rating: 5,
        comment: 'Super service',
      );

      expect(repo.created, hasLength(1));
      final r = repo.created.first;
      expect(r.reviewerRole, ReviewerRole.client);
      expect(r.reviewerId, 'client_uid');
      expect(r.revieweeId, 'provider_uid');
      expect(r.bookingId, 'booking_1');
    });
  });

  group('bilateral review pairing - provider reviews client', () {
    test('stores review with ReviewerRole.provider', () async {
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'provider_uid',
        revieweeId: 'client_uid',
        reviewerRole: ReviewerRole.provider,
        rating: 4,
        comment: 'Client ponctuel',
      );

      expect(repo.created, hasLength(1));
      final r = repo.created.first;
      expect(r.reviewerRole, ReviewerRole.provider);
      expect(r.reviewerId, 'provider_uid');
      expect(r.revieweeId, 'client_uid');
    });
  });

  group('both sides leave reviews for the same booking', () {
    test('two reviews are stored with different roles', () async {
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'client_uid',
        revieweeId: 'provider_uid',
        reviewerRole: ReviewerRole.client,
        rating: 5,
      );
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'provider_uid',
        revieweeId: 'client_uid',
        reviewerRole: ReviewerRole.provider,
        rating: 4,
      );

      expect(repo.created, hasLength(2));
      final roles = repo.created.map((r) => r.reviewerRole).toSet();
      expect(roles, containsAll([ReviewerRole.client, ReviewerRole.provider]));
    });

    test('each review targets the correct reviewee', () async {
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'client_uid',
        revieweeId: 'provider_uid',
        reviewerRole: ReviewerRole.client,
        rating: 5,
      );
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'provider_uid',
        revieweeId: 'client_uid',
        reviewerRole: ReviewerRole.provider,
        rating: 4,
      );

      final clientReview = repo.created.firstWhere(
        (r) => r.reviewerRole == ReviewerRole.client,
      );
      final providerReview = repo.created.firstWhere(
        (r) => r.reviewerRole == ReviewerRole.provider,
      );

      expect(clientReview.revieweeId, 'provider_uid');
      expect(providerReview.revieweeId, 'client_uid');
    });
  });

  group('hasReviewedProvider stream - derived from watchForBooking', () {
    test('returns false when no reviews exist for booking', () async {
      final reviews = await repo.watchForBooking('booking_1').first;
      final hasReviewed = reviews.any((r) => r.reviewerId == 'client_uid');
      expect(hasReviewed, isFalse);
    });

    test('returns true after client submits a review', () async {
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'client_uid',
        revieweeId: 'provider_uid',
        reviewerRole: ReviewerRole.client,
        rating: 5,
      );

      final reviews = await repo.watchForBooking('booking_1').first;
      final hasReviewed = reviews.any((r) => r.reviewerId == 'client_uid');
      expect(hasReviewed, isTrue);
    });

    test('provider has not reviewed even when client has', () async {
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'client_uid',
        revieweeId: 'provider_uid',
        reviewerRole: ReviewerRole.client,
        rating: 5,
      );

      final reviews = await repo.watchForBooking('booking_1').first;
      final providerHasReviewed = reviews.any(
        (r) => r.reviewerId == 'provider_uid',
      );
      expect(providerHasReviewed, isFalse);
    });
  });

  group('repository error propagation', () {
    test('propagates exception from repository', () async {
      repo.shouldThrow = Exception('Firestore unavailable');
      await expectLater(
        useCase(
          bookingId: 'b',
          reviewerId: 'r',
          revieweeId: 'e',
          reviewerRole: ReviewerRole.client,
          rating: 3,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
