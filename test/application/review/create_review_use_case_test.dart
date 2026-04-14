import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';
import 'package:outalma_app/src/domain/repositories/review_repository.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class _FakeReviewRepository implements ReviewRepository {
  Review? lastCreated;
  Object? shouldThrow;

  @override
  Future<Review> create(Review review) async {
    if (shouldThrow != null) throw shouldThrow!;
    lastCreated = review;
    // Simulate Firestore assigning an id
    return Review(
      id: 'review_generated',
      bookingId: review.bookingId,
      reviewerId: review.reviewerId,
      revieweeId: review.revieweeId,
      reviewerRole: review.reviewerRole,
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt,
    );
  }

  @override
  Stream<List<Review>> watchForBooking(String bookingId) =>
      const Stream.empty();

  @override
  Stream<List<Review>> watchForUser(String userId) => const Stream.empty();
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

  group('CreateReviewUseCase', () {
    test('creates review with correct fields', () async {
      await useCase(
        bookingId: 'booking_1',
        reviewerId: 'user_A',
        revieweeId: 'user_B',
        reviewerRole: ReviewerRole.client,
        rating: 5,
        comment: 'Excellent service',
      );

      final review = repo.lastCreated!;
      expect(review.bookingId, 'booking_1');
      expect(review.reviewerId, 'user_A');
      expect(review.revieweeId, 'user_B');
      expect(review.reviewerRole, ReviewerRole.client);
      expect(review.rating, 5);
      expect(review.comment, 'Excellent service');
    });

    test('trims comment whitespace', () async {
      await useCase(
        bookingId: 'b',
        reviewerId: 'r',
        revieweeId: 'e',
        reviewerRole: ReviewerRole.provider,
        rating: 4,
        comment: '  Très bien  ',
      );
      expect(repo.lastCreated!.comment, 'Très bien');
    });

    test('stores null when comment is blank', () async {
      await useCase(
        bookingId: 'b',
        reviewerId: 'r',
        revieweeId: 'e',
        reviewerRole: ReviewerRole.client,
        rating: 3,
        comment: '   ',
      );
      expect(repo.lastCreated!.comment, isNull);
    });

    test('stores null when comment is omitted', () async {
      await useCase(
        bookingId: 'b',
        reviewerId: 'r',
        revieweeId: 'e',
        reviewerRole: ReviewerRole.client,
        rating: 3,
      );
      expect(repo.lastCreated!.comment, isNull);
    });

    test('rating 1 is accepted', () async {
      await useCase(
        bookingId: 'b',
        reviewerId: 'r',
        revieweeId: 'e',
        reviewerRole: ReviewerRole.client,
        rating: 1,
      );
      expect(repo.lastCreated!.rating, 1);
    });

    test('propagates repository exception', () async {
      repo.shouldThrow = Exception('Firestore error');
      await expectLater(
        useCase(
          bookingId: 'b',
          reviewerId: 'r',
          revieweeId: 'e',
          reviewerRole: ReviewerRole.client,
          rating: 5,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
