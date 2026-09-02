import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/provider_rating.dart';
import '../../domain/repositories/provider_rating_repository.dart';

/// Reads `provider_ratings/{uid}`: one document, by id, no query.
///
/// That is the whole point of the collection. The card used to open a live
/// unbounded query per provider to average their reviews client-side; this
/// reads a single document the server keeps up to date.
class FirestoreProviderRatingRepository implements ProviderRatingRepository {
  FirestoreProviderRatingRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<ProviderRating> watch(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return _db.collection('provider_ratings').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return const ProviderRating.none();
      final data = snap.data();
      return ProviderRating(
        sum: (data?['ratingSum'] as num?)?.toInt() ?? 0,
        count: (data?['ratingCount'] as num?)?.toInt() ?? 0,
      );
    });
  }
}
