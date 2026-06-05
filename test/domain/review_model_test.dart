import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';

Review _base() => Review(
  id: 'r1',
  bookingId: 'b1',
  reviewerId: 'u1',
  revieweeId: 'u2',
  reviewerRole: ReviewerRole.client,
  rating: 5,
  createdAt: DateTime(2024, 6, 1),
);

void main() {
  group('Review.copyWith', () {
    test('unchanged fields are preserved', () {
      final r = _base().copyWith(rating: 3);
      expect(r.id, 'r1');
      expect(r.bookingId, 'b1');
      expect(r.rating, 3);
    });

    test('role can be changed to provider', () {
      final r = _base().copyWith(reviewerRole: ReviewerRole.provider);
      expect(r.reviewerRole, ReviewerRole.provider);
    });

    test('comment defaults to null', () {
      expect(_base().comment, isNull);
    });

    test('comment can be set via copyWith', () {
      final r = _base().copyWith(comment: 'Excellent travail');
      expect(r.comment, 'Excellent travail');
    });
  });

  group('Review rating bounds', () {
    test('rating 1 (minimum) is stored as-is', () {
      final r = _base().copyWith(rating: 1);
      expect(r.rating, 1);
    });

    test('rating 5 (maximum) is stored as-is', () {
      final r = _base().copyWith(rating: 5);
      expect(r.rating, 5);
    });

    test('rating 3 (mid) is stored as-is', () {
      final r = _base().copyWith(rating: 3);
      expect(r.rating, 3);
    });
  });

  group('ReviewerRole.fromString', () {
    test('parses "client"', () {
      expect(ReviewerRole.fromString('client'), ReviewerRole.client);
    });

    test('parses "provider"', () {
      expect(ReviewerRole.fromString('provider'), ReviewerRole.provider);
    });

    test('falls back to client for unknown string', () {
      expect(ReviewerRole.fromString('unknown'), ReviewerRole.client);
    });
  });
}
