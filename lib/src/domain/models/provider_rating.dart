/// The server-owned public rating of a provider.
///
/// Written only by the review trigger and the moderation callables, read by
/// anyone. It replaces the unbounded per-card query that used to load every
/// review of a provider just to average them client-side (budget line D1).
class ProviderRating {
  const ProviderRating({required this.sum, required this.count});

  /// The aggregate for a provider nobody has rated yet.
  const ProviderRating.none() : this(sum: 0, count: 0);

  final int sum;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ProviderRating && other.sum == sum && other.count == count;

  @override
  int get hashCode => Object.hash(sum, count);

  @override
  String toString() => 'ProviderRating($sum, $count)';
}
