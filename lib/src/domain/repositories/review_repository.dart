import '../models/review.dart';

abstract interface class ReviewRepository {
  Stream<List<Review>> watchForBooking(String bookingId);
  Stream<List<Review>> watchForUser(String userId);

  /// The most recent [limit] reviews received by [userId], newest first.
  ///
  /// A separate method on purpose: [watchForUser] still feeds the screens that
  /// LIST reviews, where loading them is the point, and bounding it there would
  /// truncate those lists in silence.
  Stream<List<Review>> watchRecentForUser(String userId, {required int limit});

  Future<Review> create(Review review);
}
