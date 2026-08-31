import '../models/provider_rating.dart';

abstract interface class ProviderRatingRepository {
  /// Watches the public rating aggregate of [uid].
  ///
  /// Emits [ProviderRating.none] when the document does not exist, which is
  /// the "nobody has rated them yet" state and not an error.
  Stream<ProviderRating> watch(String uid);
}
