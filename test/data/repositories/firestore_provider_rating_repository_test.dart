import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_provider_rating_repository.dart';
import 'package:outalma_app/src/domain/models/provider_rating.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreProviderRatingRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreProviderRatingRepository(db);
  });

  Future<void> write(Map<String, Object?> data) =>
      db.collection('provider_ratings').doc('p1').set(data);

  test('a provider nobody has rated reads as none, not as an error', () async {
    expect(await repo.watch('p1').first, const ProviderRating.none());
  });

  test('reads the aggregate the server maintains', () async {
    await write({'ratingSum': 12, 'ratingCount': 3});
    expect(
      await repo.watch('p1').first,
      const ProviderRating(sum: 12, count: 3),
    );
  });

  test('a partial document degrades to zero rather than throwing', () async {
    // The server always writes both fields together, but a document read
    // mid-write must not crash a listing screen.
    await write({'ratingSum': 7});
    expect(
      await repo.watch('p1').first,
      const ProviderRating(sum: 7, count: 0),
    );
  });

  test('tolerates a double where an int is expected', () async {
    await write({'ratingSum': 12.0, 'ratingCount': 3.0});
    expect(
      await repo.watch('p1').first,
      const ProviderRating(sum: 12, count: 3),
    );
  });

  test('an empty uid yields nothing at all, and opens no listener', () async {
    expect(await repo.watch('').isEmpty, isTrue);
  });

  test('follows updates, since the aggregate moves under moderation', () async {
    await write({'ratingSum': 12, 'ratingCount': 3});
    final seen = <ProviderRating>[];
    final sub = repo.watch('p1').listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await write({'ratingSum': 8, 'ratingCount': 2});
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen.last, const ProviderRating(sum: 8, count: 2));
  });

  group('ProviderRating value semantics', () {
    test('compares and hashes by value, and prints itself', () {
      const a = ProviderRating(sum: 12, count: 3);
      expect(a, const ProviderRating(sum: 12, count: 3));
      expect(a.hashCode, const ProviderRating(sum: 12, count: 3).hashCode);
      expect(a, isNot(const ProviderRating(sum: 12, count: 4)));
      // ignore: unrelated_type_equality_checks
      expect(a == 'not a rating', isFalse);
      expect(a.toString(), contains('12'));
      expect(
        const ProviderRating.none(),
        const ProviderRating(sum: 0, count: 0),
      );
    });
  });
}
