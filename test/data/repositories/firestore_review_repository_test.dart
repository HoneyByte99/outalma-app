import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_review_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreReviewRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreReviewRepository(db);
  });

  Future<void> seed(String id, {required int rating, required int day}) =>
      db.collection('reviews').doc(id).set({
        'id': id,
        'bookingId': 'b_$id',
        'reviewerId': 'client_1',
        'revieweeId': 'target',
        'reviewerRole': 'client',
        'rating': rating,
        'comment': '',
        'createdAt': DateTime.utc(2026, 8, day),
      });

  group('watchRecentForUser', () {
    test('returns the newest reviews first, bounded by the limit', () async {
      await seed('a', rating: 5, day: 1);
      await seed('b', rating: 4, day: 2);
      await seed('c', rating: 3, day: 3);

      final recent = await repo.watchRecentForUser('target', limit: 2).first;

      expect(recent, hasLength(2), reason: 'the bound must actually bind');
      expect(
        recent.map((r) => r.id),
        ['c', 'b'],
        reason: 'newest first, so the window is the RECENT one',
      );
    });

    test('a limit larger than the corpus returns everything', () async {
      await seed('a', rating: 5, day: 1);
      expect(
        await repo.watchRecentForUser('target', limit: 50).first,
        hasLength(1),
      );
    });

    test(
      'someone with no reviews yields an empty list, not an error',
      () async {
        expect(
          await repo.watchRecentForUser('nobody', limit: 50).first,
          isEmpty,
        );
      },
    );

    test('it does not leak reviews received by someone else', () async {
      await seed('a', rating: 5, day: 1);
      await db.collection('reviews').doc('other').set({
        'id': 'other',
        'bookingId': 'b2',
        'reviewerId': 'client_2',
        'revieweeId': 'someone_else',
        'reviewerRole': 'client',
        'rating': 1,
        'comment': '',
        'createdAt': DateTime.utc(2026, 8, 9),
      });

      final recent = await repo.watchRecentForUser('target', limit: 50).first;
      expect(recent.map((r) => r.id), ['a']);
    });
  });
}
