/// How a rating is presented, decided once for the whole app.
///
/// The rule is a product decision, not a screen detail: an average computed
/// from a single review condemns someone on one bad day, and the catalogue is
/// young enough that most people have one or two. Below the floor we say
/// "Nouveau", which is true and says nothing false.
///
/// Pure and parameterised so every surface can be proved to agree: the card,
/// the service detail, the public profile and the reviews page all pass
/// through this, and a divergence between them is a test failure rather than a
/// discovery in production.
library;

/// The default floor. Three is where an average starts meaning something
/// without keeping most of the catalogue nameless.
const int kMinReviewsForAverage = 3;

/// What a surface should render for a given aggregate.
class RatingDisplay {
  const RatingDisplay._({required this.isNew, this.average, this.count = 0});

  /// Not enough reviews to state an average. The surface shows "Nouveau".
  const RatingDisplay.fresh() : this._(isNew: true);

  final bool isNew;

  /// Null exactly when [isNew].
  final double? average;

  /// Reviews behind the average. Zero when [isNew].
  final int count;

  @override
  bool operator ==(Object other) =>
      other is RatingDisplay &&
      other.isNew == isNew &&
      other.average == average &&
      other.count == count;

  @override
  int get hashCode => Object.hash(isNew, average, count);

  @override
  String toString() =>
      isNew ? 'RatingDisplay.fresh()' : 'RatingDisplay($average, $count)';
}

/// Decides what to show from a rating aggregate.
///
/// [sum] and [count] come from the server-owned aggregate, or from a bounded
/// list of reviews for the client-reputation surfaces. A [count] below
/// [minReviews] yields [RatingDisplay.fresh], whatever the sum.
RatingDisplay ratingDisplay({
  required int sum,
  required int count,
  int minReviews = kMinReviewsForAverage,
}) {
  if (count < minReviews || count <= 0) return const RatingDisplay.fresh();
  return RatingDisplay._(isNew: false, average: sum / count, count: count);
}
