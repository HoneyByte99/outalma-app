import '../enums/category_id.dart';
import '../enums/reviewer_role.dart';

class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.reviewerRole,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.categoryId,
  });

  final String id;
  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final ReviewerRole reviewerRole;

  /// Rating from 1 to 5 inclusive.
  final int rating;
  final String? comment;

  /// Service category the review concerns — captured from the booking's service
  /// at review time. Lets a rating be read in context (a provider may be great
  /// at one category and weak at another). Null for legacy reviews.
  final CategoryId? categoryId;

  final DateTime createdAt;

  Review copyWith({
    String? bookingId,
    String? reviewerId,
    String? revieweeId,
    ReviewerRole? reviewerRole,
    int? rating,
    String? comment,
    CategoryId? categoryId,
    DateTime? createdAt,
  }) {
    return Review(
      id: id,
      bookingId: bookingId ?? this.bookingId,
      reviewerId: reviewerId ?? this.reviewerId,
      revieweeId: revieweeId ?? this.revieweeId,
      reviewerRole: reviewerRole ?? this.reviewerRole,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
