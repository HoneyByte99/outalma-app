// What the client writes into `hidden` when it creates a review.
//
// This is not a formality. Reviews are now publicly readable through
// `allow read: if signedIn() || resource.data.hidden == false`, and Firestore
// makes an ABSENT field fail that rule twice over: the rule cannot evaluate on
// a single read, and a query on an absent field matches nothing. A review
// created without the field would be invisible to every visitor, for ever, with
// no error anywhere to say so.
//
// So the field being present, and being exactly `false`, is a load-bearing part
// of the public read. The emulator side of the same contract lives in
// functions/test/firestore_rules.test.ts.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_review_repository.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/review.dart';

Review _review({bool hidden = false}) => Review(
  id: '',
  bookingId: 'b1',
  reviewerId: 'alice',
  revieweeId: 'bob',
  reviewerRole: ReviewerRole.client,
  rating: 5,
  comment: 'Tres bien',
  categoryId: CategoryId.menage,
  hidden: hidden,
  createdAt: DateTime.utc(2026, 9, 1),
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreReviewRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreReviewRepository(db);
  });

  Future<Map<String, dynamic>> rawDoc(String id) async {
    final snap = await db.collection('reviews').doc(id).get();
    return snap.data()!;
  }

  test('a created review carries hidden false in the DOCUMENT', () async {
    await repo.create(_review());

    final raw = await rawDoc('b1_alice');
    expect(
      raw.containsKey('hidden'),
      isTrue,
      reason:
          'an absent field cannot satisfy resource.data.hidden == false and '
          'cannot be matched by the visitor query: the review would be '
          'invisible to every visitor, for ever',
    );
    expect(raw['hidden'], false);
  });

  test('the field is the LITERAL false, never the model value', () async {
    // A caller building a Review with hidden: true must not be able to smuggle
    // a moderation verdict into its own document. The rule refuses the write
    // too; this makes the client refuse to compose it in the first place.
    await repo.create(_review(hidden: true));

    expect(await rawDoc('b1_alice'), containsPair('hidden', false));
  });

  test('the round trip still reads hidden back', () async {
    await repo.create(_review());

    final reviews = await repo.watchForBooking('b1').first;
    expect(reviews, hasLength(1));
    expect(reviews.first.hidden, isFalse);
  });

  test(
    'a document with NO hidden field still deserialises as visible',
    () async {
      // The historical corpus, until scripts/normalize-review-hidden.py runs.
      // Absence means visible by convention, and the client must keep honouring
      // that: the read side has to survive the window before normalisation.
      await db.collection('reviews').doc('legacy').set({
        'bookingId': 'b9',
        'reviewerId': 'dave',
        'revieweeId': 'bob',
        'reviewerRole': 'client',
        'rating': 4,
        'createdAt': DateTime.utc(2026, 1, 1),
      });

      final reviews = await repo.watchForBooking('b9').first;
      expect(reviews.single.hidden, isFalse);
    },
  );

  test('a moderated document deserialises as hidden', () async {
    await db.collection('reviews').doc('masked').set({
      'bookingId': 'b8',
      'reviewerId': 'carol',
      'revieweeId': 'bob',
      'reviewerRole': 'client',
      'rating': 1,
      'hidden': true,
      'createdAt': DateTime.utc(2026, 1, 1),
    });

    final reviews = await repo.watchForBooking('b8').first;
    expect(reviews.single.hidden, isTrue);
  });
}
