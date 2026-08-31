import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../data/repositories/firestore_provider_rating_repository.dart';
import '../../data/repositories/firestore_review_repository.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/reviewer_role.dart';
import '../../domain/models/review.dart';
import '../../domain/repositories/provider_rating_repository.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/review/rating_display.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return FirestoreReviewRepository(ref.watch(firestoreProvider));
});

/// Watches all reviews received by [userId] (as reviewee).
final reviewsForUserProvider = StreamProvider.autoDispose
    .family<List<Review>, String>((ref, userId) {
      return ref.watch(reviewRepositoryProvider).watchForUser(userId);
    });

/// Watches all reviews for a given booking (at most 2 — one per role).
final reviewsForBookingProvider = StreamProvider.autoDispose
    .family<List<Review>, String>((ref, bookingId) {
      return ref.watch(reviewRepositoryProvider).watchForBooking(bookingId);
    });

final providerRatingRepositoryProvider = Provider<ProviderRatingRepository>((
  ref,
) {
  return FirestoreProviderRatingRepository(ref.watch(firestoreProvider));
});

/// The PUBLIC rating of a provider, read from the server-owned aggregate.
///
/// One document per provider, shared by every card showing them. Use this for
/// provider-facing surfaces: the card, the service detail, the public profile
/// and the provider dashboard.
final providerRatingProvider = StreamProvider.autoDispose
    .family<RatingDisplay, String>((ref, uid) {
      return ref
          .watch(providerRatingRepositoryProvider)
          .watch(uid)
          .map((r) => ratingDisplay(sum: r.sum, count: r.count));
    });

/// The reputation of a CLIENT, shown to a provider deciding whether to accept.
///
/// Deliberately NOT the aggregate: no `provider_ratings/{clientUid}` will ever
/// exist, since only reviews received as a provider are aggregated. Reading the
/// aggregate here would show "Nouveau" for every client, for ever, on the very
/// screen where the provider decides.
///
/// Bounded, and ordered: without the order the average would cover an arbitrary
/// slice ordered by document id, which is worse than unbounded. The composite
/// index it needs already exists.
final clientReputationProvider = StreamProvider.autoDispose
    .family<RatingDisplay, String>((ref, userId) {
      return ref
          .watch(reviewRepositoryProvider)
          .watchRecentForUser(userId, limit: kClientReputationWindow)
          .map((reviews) {
            final sum = reviews.fold<int>(0, (acc, r) => acc + r.rating);
            return ratingDisplay(sum: sum, count: reviews.length);
          });
    });

/// How many recent reviews a client's reputation is computed over. Beyond it
/// the count is displayed as "50+" rather than as a number that is not true.
const int kClientReputationWindow = 50;

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
    CategoryId? categoryId,
  }) async {
    final review = Review(
      id: '', // will be replaced by repo with Firestore doc id
      bookingId: bookingId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      reviewerRole: reviewerRole,
      rating: rating,
      comment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      categoryId: categoryId,
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
final hasReviewedProvider = StreamProvider.autoDispose.family<bool, String>((
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
