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

  /// [hidden] null means the key is ABSENT from the document.
  ///
  /// The default is `false`, not null, and that matters: every write path in
  /// production puts the key there (the client serializer writes the literal
  /// false, `onReviewCreated` backfills), so a seed without it describes a
  /// document that no longer exists. Defaulting to absent made most of the
  /// cases below pass on a corpus shape the app cannot produce.
  Future<void> seed(
    String id, {
    required int rating,
    required int day,
    bool? hidden = false,
  }) => db.collection('reviews').doc(id).set({
    'id': id,
    'bookingId': 'b_$id',
    'reviewerId': 'client_1',
    'revieweeId': 'target',
    'reviewerRole': 'client',
    'rating': rating,
    'comment': '',
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

    test('a review with NO hidden key is INVISIBLE to these two queries', () async {
      // This test asserted the opposite until the filter moved from Dart into
      // the query, and the reversal is deliberate rather than a regression that
      // slipped through.
      //
      // A visitor with no account cannot list this collection at all without
      // `where('hidden', '==', false)`: the public rule is
      // `resource.data.hidden == false`, and for a `list` Firestore evaluates
      // rules against the fields the QUERY constrains. So the filter has to be
      // in the query, and an equality query matches no document that LACKS the
      // field. The cost is exactly this case.
      //
      // Accepted on measurement, not on hope. All 36 production reviews carry
      // `hidden` (checked 2026-09-01, 0 missing): scripts/normalize-review-hidden.py
      // cleared the corpus the old comment described, the client serializer
      // writes the literal `false` on every create, and `onReviewCreated`
      // backfills the field for clients already in the wild. The remedy if one
      // ever reappears is to re-run that script, not to drop the filter, which
      // would make every reviews list unreadable to visitors again.
      //
      // Note this was ALREADY the truth for a guest before this change: the rule
      // refuses a `get` on such a document too (emulator test "a review with NO
      // hidden field is UNREADABLE by a visitor"). The change aligns the
      // signed-in path with it instead of leaving the two divergent.
      //
      // Keep this case: it is also the only assertion that can tell a QUERY
      // filter from a Dart filter. `Review.hidden` defaults to false when the
      // key is absent, so a list filtered in Dart would KEEP this document.
      // Moving the filter back out of the query turns this test red, which is
      // what protects the guest read path from a well-meaning simplification.
      await seed('legacy', rating: 4, day: 1, hidden: null);

      expect(await repo.watchForUser('target').first, isEmpty);
      expect(await repo.watchRecentForUser('target', limit: 50).first, isEmpty);
    });

    test('watchForBooking still sees a review with no hidden key', () async {
      // The one query that must NOT filter also must not lose the corpus: it
      // drives hasReviewedProvider, and a false "you have not reviewed yet"
      // sends the user to a form whose write the rules refuse.
      await seed('legacy', rating: 4, day: 1, hidden: null);
      expect((await repo.watchForBooking('b_legacy').first).map((r) => r.id), [
        'legacy',
      ]);
    });

    test('create() writes hidden FALSE, and only ever false', () async {
      // This test used to assert the opposite, that no `hidden` key was
      // written, on the grounds that the create rule carried no field allowlist
      // and a client able to write the field could stamp its own verdict.
      //
      // Two things changed together. The rule now carries an allowlist of one
      // value: `hidden` is accepted on create only when it equals false. And
      // reviews became publicly readable through `resource.data.hidden ==
      // false`, a rule an ABSENT field cannot satisfy and a query cannot match,
      // so a review written without the key would be invisible to every visitor
      // for ever.
      //
      // What the original test protected is protected still, one layer down:
      // the serializer writes the LITERAL false, never review.hidden, so a
      // Review built with hidden: true cannot smuggle a verdict through. That
      // is asserted in test/data/review_hidden_serialization_test.dart.
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
        raw.data()!['hidden'],
        false,
        reason:
            'an absent key cannot satisfy the public read rule, and a value '
            'other than false would be the client owning a moderation verdict',
      );
    });
  });
}
