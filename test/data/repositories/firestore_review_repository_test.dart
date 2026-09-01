import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_review_repository.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreReviewRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreReviewRepository(db);
  });

  Future<void> seed(
    String id, {
    required int rating,
    required int day,
    bool? hidden,
  }) => db.collection('reviews').doc(id).set({
    'id': id,
    'bookingId': 'b_$id',
    'reviewerId': 'client_1',
    'revieweeId': 'target',
    'reviewerRole': 'client',
    'rating': rating,
    'comment': '',
    // null means the key is ABSENT, which is the historical corpus.
    if (hidden != null) 'hidden': hidden,
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

  // hideReview sets `hidden: true` server-side. Nothing on this side used to
  // read it, so a moderated review stayed fully visible on every list while the
  // aggregate had already stopped counting it: the header said 3, the list
  // showed 4, and moderation was cosmetic.
  group('moderation: hidden reviews', () {
    test('watchForUser EXCLUDES a hidden review', () async {
      await seed('visible', rating: 5, day: 1);
      await seed('moderated', rating: 1, day: 2, hidden: true);

      final all = await repo.watchForUser('target').first;

      expect(all.map((r) => r.id), ['visible']);
    });

    test('watchRecentForUser EXCLUDES a hidden review', () async {
      await seed('visible', rating: 5, day: 1);
      await seed('moderated', rating: 1, day: 2, hidden: true);

      final recent = await repo.watchRecentForUser('target', limit: 50).first;

      expect(recent.map((r) => r.id), ['visible']);
    });

    test('watchForBooking INCLUDES a hidden review, deliberately', () async {
      // hasReviewedProvider reads this stream. Filtering here would offer the
      // review form a second time and the write would be refused, the document
      // id being deterministic and the rule create-only: a visible dead end.
      await seed('moderated', rating: 1, day: 1, hidden: true);

      final onBooking = await repo.watchForBooking('b_moderated').first;

      expect(onBooking.map((r) => r.id), ['moderated']);
      expect(onBooking.single.hidden, isTrue);
    });

    test('hidden: false is kept, like any visible review', () async {
      await seed('unhidden', rating: 4, day: 1, hidden: false);
      expect(await repo.watchForUser('target').first, hasLength(1));
    });

    test('a review with NO hidden key is visible (historical corpus)', () async {
      // 85 reviews in production carry no such key. Treating absence as hidden
      // would empty the whole catalogue.
      await seed('legacy', rating: 4, day: 1);
      final all = await repo.watchForUser('target').first;
      expect(all, hasLength(1));
      expect(all.single.hidden, isFalse);
    });

    test('create() writes NO hidden key', () async {
      // `hidden` is a moderation verdict. The create rule carries no field
      // allowlist, so a client able to write it could unhide its own bad review.
      final written = await repo.create(
        Review(
          id: '',
          bookingId: 'b_new',
          reviewerId: 'client_1',
          revieweeId: 'target',
          reviewerRole: ReviewerRole.client,
          rating: 5,
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      );

      final raw = await db.collection('reviews').doc(written.id).get();
      expect(
        raw.data()!.containsKey('hidden'),
        isFalse,
        reason: 'the client must never write its own moderation flag',
      );
    });
  });
}
