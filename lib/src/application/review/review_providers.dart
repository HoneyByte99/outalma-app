import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../data/repositories/firestore_review_repository.dart';
import '../../domain/enums/reviewer_role.dart';
import '../../domain/models/review.dart';
import '../../domain/repositories/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return FirestoreReviewRepository(ref.watch(firestoreProvider));
});

/// Watches all reviews received by [userId] (as reviewee).
final reviewsForUserProvider = StreamProvider.family<List<Review>, String>((
  ref,
  userId,
) {
  return ref.watch(reviewRepositoryProvider).watchForUser(userId);
});

/// Watches all reviews for a given booking (at most 2 — one per role).
final reviewsForBookingProvider = StreamProvider.family<List<Review>, String>((
  ref,
  bookingId,
) {
  return ref.watch(reviewRepositoryProvider).watchForBooking(bookingId);
});

// ---------------------------------------------------------------------------
// Create review use case
// ---------------------------------------------------------------------------

class CreateReviewUseCase {
  const CreateReviewUseCase(this._repo);

  final ReviewRepository _repo;

  /// Creates a review. Generates a temp id on the client; Firestore assigns
  /// the real document id from [FirestoreReviewRepository.create].
  Future<void> call({
    required String bookingId,
    required String reviewerId,
    required String revieweeId,
    required ReviewerRole reviewerRole,
    required int rating,
    String? comment,
  }) async {
    final review = Review(
      id: '', // will be replaced by repo with Firestore doc id
      bookingId: bookingId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      reviewerRole: reviewerRole,
      rating: rating,
      comment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      createdAt: DateTime.now(),
    );
    await _repo.create(review);
  }
}

final createReviewUseCaseProvider = Provider<CreateReviewUseCase>((ref) {
  return CreateReviewUseCase(ref.watch(reviewRepositoryProvider));
});

/// Whether the current user has already left a review for [bookingId].
/// Returns null while loading.
final hasReviewedProvider = StreamProvider.family<bool, String>((
  ref,
  bookingId,
) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return Stream.value(false);

  final uid = authState.user.id;
  return ref
      .watch(reviewRepositoryProvider)
      .watchForBooking(bookingId)
      .map((reviews) => reviews.any((r) => r.reviewerId == uid));
});
