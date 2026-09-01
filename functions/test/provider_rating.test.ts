// The public rating aggregate. Two things are load-bearing here and both were
// found by review rather than by writing code: the author's role comes from the
// BOOKING (never from the client-written `reviewerRole`), and every transition
// is decided on the RECORDED STATE rather than by re-evaluating the predicate.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

// The default app is initialized by importing ../src/index, the convention the
// other server tests follow.
import '../src/index';
import * as admin from 'firebase-admin';
import {
  RATINGS,
  RATING_EVENTS,
  countsTowardProviderRating,
  isUsableRating,
  countReview,
  discountReview,
  recountReview,
} from '../src/provider_rating';
import * as fns from '../src/index';
import { clearFirestore, createAuthUser } from './helpers';

const tfWrap = tf.wrap;

const db = () => admin.firestore();

const CLIENT = 'client_1';
const PROVIDER = 'provider_1';

async function seedBooking(id: string, customerId = CLIENT, providerId = PROVIDER) {
  await db().collection('bookings').doc(id).set({ customerId, providerId });
}

async function agg(uid = PROVIDER) {
  const snap = await db().collection(RATINGS).doc(uid).get();
  return snap.exists ? snap.data() : null;
}

const ADMIN = { uid: 'boss', token: { admin: true, moderator: true } };

async function seedCountedReview() {
  await seedBooking('b1');
  await db().collection('reviews').doc('r1').set({
    reviewerId: CLIENT,
    revieweeId: PROVIDER,
    bookingId: 'b1',
    rating: 4,
    hidden: false,
  });
  await countReview('r1', { reviewerId: CLIENT, bookingId: 'b1', rating: 4 });
}

afterAll(() => tf.cleanup());
beforeEach(clearFirestore);

describe('countsTowardProviderRating', () => {
  const booking = { customerId: CLIENT, providerId: PROVIDER };

  it('counts a review written by the customer of the booking', () => {
    expect(countsTowardProviderRating({ reviewerId: CLIENT }, booking)).toBe(true);
  });

  it('does NOT count a review written by the provider', () => {
    expect(countsTowardProviderRating({ reviewerId: PROVIDER }, booking)).toBe(false);
  });

  it('ignores reviewerRole entirely, since the client writes it', () => {
    // A provider claiming to be the client must not be believed.
    const forged = { reviewerId: PROVIDER, reviewerRole: 'client' } as never;
    expect(countsTowardProviderRating(forged, booking)).toBe(false);
    // And a legacy review with NO reviewerRole is still attributed correctly.
    expect(countsTowardProviderRating({ reviewerId: CLIENT }, booking)).toBe(true);
  });

  it('does not count a hidden review', () => {
    expect(
      countsTowardProviderRating({ reviewerId: CLIENT, hidden: true }, booking),
    ).toBe(false);
  });

  it('does not count a self-review', () => {
    expect(
      countsTowardProviderRating(
        { reviewerId: CLIENT },
        { customerId: CLIENT, providerId: CLIENT },
      ),
    ).toBe(false);
  });
});

describe('isUsableRating', () => {
  it('accepts 1 to 5 and rejects everything else', () => {
    for (const ok of [1, 2, 3, 4, 5]) expect(isUsableRating(ok)).toBe(true);
    for (const ko of [0, 6, 3.5, -1, '4', null, undefined, NaN]) {
      expect(isUsableRating(ko)).toBe(false);
    }
  });
});

describe('countReview', () => {
  it('creates the aggregate and adds the rating', async () => {
    await seedBooking('b1');
    await countReview('r1', { reviewerId: CLIENT, bookingId: 'b1', rating: 4 });
    expect(await agg()).toMatchObject({ ratingSum: 4, ratingCount: 1 });
  });

  it('is idempotent: the same review replayed adds nothing (D5)', async () => {
    await seedBooking('b1');
    const review = { reviewerId: CLIENT, bookingId: 'b1', rating: 4 };
    await countReview('r1', review);
    await countReview('r1', review);
    await countReview('r1', review);
    expect(await agg()).toMatchObject({ ratingSum: 4, ratingCount: 1 });
  });

  it('sums two distinct reviews', async () => {
    await seedBooking('b1');
    await seedBooking('b2');
    await countReview('r1', { reviewerId: CLIENT, bookingId: 'b1', rating: 4 });
    await countReview('r2', { reviewerId: CLIENT, bookingId: 'b2', rating: 2 });
    expect(await agg()).toMatchObject({ ratingSum: 6, ratingCount: 2 });
  });

  it('creates NO document for a provider-authored review', async () => {
    await seedBooking('b1');
    await countReview('r1', { reviewerId: PROVIDER, bookingId: 'b1', rating: 5 });
    expect(await agg()).toBeNull();
    expect(await agg(CLIENT)).toBeNull();
  });

  it('ignores a review whose booking is missing, and writes nothing', async () => {
    await countReview('r1', { reviewerId: CLIENT, bookingId: 'gone', rating: 5 });
    expect(await agg()).toBeNull();
  });

  it('ignores a review with no bookingId', async () => {
    await countReview('r1', { reviewerId: CLIENT, rating: 5 });
    expect(await agg()).toBeNull();
  });

  it('ignores an unusable rating value', async () => {
    await seedBooking('b1');
    await countReview('r1', { reviewerId: CLIENT, bookingId: 'b1', rating: 9 });
    expect(await agg()).toBeNull();
  });
});

describe('moderation transitions', () => {
  const review = { reviewerId: CLIENT, bookingId: 'b1', rating: 4 };

  it('hiding a counted review lowers the public rating', async () => {
    await seedBooking('b1');
    await countReview('r1', review);
    await discountReview('r1', { ...review, hidden: true });
    expect(await agg()).toMatchObject({ ratingSum: 0, ratingCount: 0 });
  });

  it('hiding a review that was never counted subtracts nothing', async () => {
    await seedBooking('b1');
    // Provider-authored, so never counted.
    await countReview('r1', { ...review, reviewerId: PROVIDER });
    await discountReview('r1', { ...review, reviewerId: PROVIDER, hidden: true });
    expect(await agg()).toBeNull();
  });

  it('unhiding restores what hiding removed', async () => {
    await seedBooking('b1');
    await countReview('r1', review);
    await discountReview('r1', { ...review, hidden: true });
    await recountReview('r1', { ...review, hidden: true });
    expect(await agg()).toMatchObject({ ratingSum: 4, ratingCount: 1 });
  });

  it('hiding twice subtracts once', async () => {
    await seedBooking('b1');
    await countReview('r1', review);
    await discountReview('r1', { ...review, hidden: true });
    await discountReview('r1', { ...review, hidden: true });
    expect(await agg()).toMatchObject({ ratingSum: 0, ratingCount: 0 });
  });

  it('never resurrects an aggregate behind a deleted account', async () => {
    await seedBooking('b1');
    await countReview('r1', review);
    // The account is deleted: the aggregate goes with it.
    await db().collection(RATINGS).doc(PROVIDER).delete();
    await discountReview('r1', { ...review, hidden: true });
    expect(await agg()).toBeNull();
    // And the state is recorded, so a replay cannot bring it back either.
    const ev = await db().collection(RATING_EVENTS).doc('r1').get();
    expect(ev.data()?.counted).toBe(false);
  });
});

describe('wiring into the account lifecycle', () => {
  const review = { reviewerId: CLIENT, bookingId: 'b1', rating: 4 };

  it('deleteMyAccount removes the aggregate, even with no identity file', async () => {
    await createAuthUser(PROVIDER);
    await seedBooking('b1');
    await countReview('r1', review);
    expect(await agg()).not.toBeNull();

    await tfWrap(fns.deleteMyAccount)({
      data: {},
      auth: { uid: PROVIDER },
    } as never);

    expect(await agg()).toBeNull();
  });

  it('exportMyData carries the aggregate (S10: erasure AND export)', async () => {
    await createAuthUser(PROVIDER);
    await seedBooking('b1');
    await countReview('r1', review);

    const out = (await tfWrap(fns.exportMyData)({
      data: {},
      auth: { uid: PROVIDER },
    } as never)) as Record<string, unknown>;

    expect(out.providerRating).toMatchObject({ ratingSum: 4, ratingCount: 1 });
  });
});

describe('the review trigger', () => {
  it('keeps the rating when the push fails', async () => {
    // The push is the one leg allowed to fail: the rating and the in-app
    // notification must both survive it.
    await createAuthUser(PROVIDER);
    await seedBooking('b1');
    const messaging = jest
      .spyOn(admin.messaging(), 'sendEachForMulticast')
      .mockRejectedValue(new Error('push down'));

    try {
      await tfWrap(fns.onReviewCreated)({
        data: tf.firestore.makeDocumentSnapshot(
          { reviewerId: CLIENT, revieweeId: PROVIDER, bookingId: 'b1', rating: 4 },
          'reviews/r1',
        ),
        params: { reviewId: 'r1' },
      } as never);
    } finally {
      messaging.mockRestore();
    }

    expect(await agg()).toMatchObject({ ratingSum: 4, ratingCount: 1 });
  });
});

describe('the moderation callables, through the callable itself', () => {
  // Calling discountReview directly proves the module. It does NOT prove the
  // callable is wired to it: a mutation removing the call inside hideReview
  // left every test green until these were written.

  it('hideReview lowers the public rating', async () => {
    await seedCountedReview();
    await tfWrap(fns.hideReview)({
      data: { reviewId: 'r1' },
      auth: ADMIN,
    } as never);
    expect(await agg()).toMatchObject({ ratingSum: 0, ratingCount: 0 });
  });

  it('unhideReview restores it', async () => {
    await seedCountedReview();
    await tfWrap(fns.hideReview)({
      data: { reviewId: 'r1' },
      auth: ADMIN,
    } as never);
    await tfWrap(fns.unhideReview)({
      data: { reviewId: 'r1' },
      auth: ADMIN,
    } as never);
    expect(await agg()).toMatchObject({ ratingSum: 4, ratingCount: 1 });
  });

  it('deleteReview lowers the public rating', async () => {
    await seedCountedReview();
    await tfWrap(fns.deleteReview)({
      data: { reviewId: 'r1' },
      auth: { uid: 'boss', token: { admin: true } },
    } as never);
    expect(await agg()).toMatchObject({ ratingSum: 0, ratingCount: 0 });
  });

  it('records the staff action in admin_logs', async () => {
    await seedCountedReview();
    await tfWrap(fns.hideReview)({
      data: { reviewId: 'r1' },
      auth: ADMIN,
    } as never);
    const logs = await db()
      .collection('admin_logs')
      .where('action', '==', 'hide_review')
      .get();
    expect(logs.size).toBe(1);
    expect(logs.docs[0]?.data()).toMatchObject({
      actorUid: 'boss',
      targetType: 'review',
      targetId: 'r1',
    });
  });
});

describe('the moderation callables are ATOMIC', () => {
  // The regression these exist for: the delta on the aggregate used to run in
  // its OWN transaction, after the review had already been mutated. A delta
  // that threw left the review hidden everywhere while it was still counted in
  // the public rating, and the backfill only ever COUNTS, so no replay could
  // repair the missing decrement.
  //
  // Each test below breaks exactly that leg. If any of the other legs survives
  // the failure, the transaction was not one transaction.

  /// Makes every write to `provider_ratings/*` throw, and nothing else.
  /// Returns the undo.
  function breakAggregateWrites(): () => void {
    const proto = admin.firestore.Transaction.prototype as unknown as Record<
      string,
      unknown
    >;
    const realSet = proto.set as (...args: unknown[]) => unknown;
    proto.set = function (this: unknown, ...args: unknown[]) {
      const ref = args[0] as { path?: string } | undefined;
      if (typeof ref?.path === 'string' && ref.path.startsWith(`${RATINGS}/`)) {
        throw new Error('aggregate write down');
      }
      return realSet.apply(this, args);
    };
    return () => {
      proto.set = realSet;
    };
  }

  async function reviewDoc(id = 'r1') {
    return db().collection('reviews').doc(id).get();
  }

  async function ratingEvent(id = 'r1') {
    const snap = await db().collection(RATING_EVENTS).doc(id).get();
    return snap.exists ? snap.data() : null;
  }

  async function adminLogsFor(action: string) {
    return db().collection('admin_logs').where('action', '==', action).get();
  }

  it('hideReview applies NOTHING when the aggregate write fails', async () => {
    await seedCountedReview();
    const restore = breakAggregateWrites();
    try {
      await expect(
        tfWrap(fns.hideReview)({ data: { reviewId: 'r1' }, auth: ADMIN } as never),
      ).rejects.toThrow('aggregate write down');
    } finally {
      restore();
    }

    // The review is NOT hidden. Under the old split, it would be: this single
    // assertion is the bug, expressed.
    expect((await reviewDoc()).data()?.hidden).toBe(false);
    // The aggregate still holds the review, consistent with a visible review.
    expect(await agg()).toMatchObject({ ratingSum: 4, ratingCount: 1 });
    // The register still says counted, so nothing has drifted out of step.
    expect(await ratingEvent()).toMatchObject({ counted: true });
    // And no staff log claims a hiding that never happened.
    expect((await adminLogsFor('hide_review')).empty).toBe(true);
  });

  it('hideReview succeeds fully once the aggregate write recovers', async () => {
    // The point of the atomicity: recovery is now a plain retry, instead of a
    // moderator unhiding and re-hiding to repair the aggregate by hand.
    await seedCountedReview();
    const restore = breakAggregateWrites();
    try {
      await expect(
        tfWrap(fns.hideReview)({ data: { reviewId: 'r1' }, auth: ADMIN } as never),
      ).rejects.toThrow('aggregate write down');
    } finally {
      restore();
    }

    await tfWrap(fns.hideReview)({ data: { reviewId: 'r1' }, auth: ADMIN } as never);

    expect((await reviewDoc()).data()?.hidden).toBe(true);
    expect(await agg()).toMatchObject({ ratingSum: 0, ratingCount: 0 });
    expect(await ratingEvent()).toMatchObject({ counted: false });
    expect((await adminLogsFor('hide_review')).size).toBe(1);
  });

  it('unhideReview applies NOTHING when the aggregate write fails', async () => {
    await seedCountedReview();
    await tfWrap(fns.hideReview)({ data: { reviewId: 'r1' }, auth: ADMIN } as never);
    expect(await agg()).toMatchObject({ ratingSum: 0, ratingCount: 0 });

    const restore = breakAggregateWrites();
    try {
      await expect(
        tfWrap(fns.unhideReview)({ data: { reviewId: 'r1' }, auth: ADMIN } as never),
      ).rejects.toThrow('aggregate write down');
    } finally {
      restore();
    }

    // Still hidden, still discounted, still marked uncounted: coherent.
    expect((await reviewDoc()).data()?.hidden).toBe(true);
    expect(await agg()).toMatchObject({ ratingSum: 0, ratingCount: 0 });
    expect(await ratingEvent()).toMatchObject({ counted: false });
    expect((await adminLogsFor('unhide_review')).empty).toBe(true);
  });

  it('deleteReview does not delete the review when the delta fails', async () => {
    // The worst of the three under the old split: the review was already gone,
    // so its rating could never be subtracted from anything afterwards.
    await seedCountedReview();
    const restore = breakAggregateWrites();
    try {
      await expect(
        tfWrap(fns.deleteReview)({
          data: { reviewId: 'r1' },
          auth: { uid: 'boss', token: { admin: true } },
        } as never),
      ).rejects.toThrow('aggregate write down');
    } finally {
      restore();
    }

    expect((await reviewDoc()).exists).toBe(true);
    expect(await agg()).toMatchObject({ ratingSum: 4, ratingCount: 1 });
    expect(await ratingEvent()).toMatchObject({ counted: true });
    expect((await adminLogsFor('delete_review')).empty).toBe(true);
  });

  it('still reports a missing review as not-found', async () => {
    // The existence check moved inside the transaction; it must still surface
    // as the callable error clients handle, not as an internal failure.
    await expect(
      tfWrap(fns.hideReview)({ data: { reviewId: 'ghost' }, auth: ADMIN } as never),
    ).rejects.toThrow(/not found/i);
  });
});

// The registry decision on the SERVER side of the shared rule.
//
// `const counted = eventSnap.exists && eventSnap.data()?.counted === true;` is
// one line inside ratingDeltaWithin, not an exported function, so it is pinned
// behaviourally here rather than by the parity table. Its Python mirror,
// `is_counted` in scripts/rating_predicate.py, is pinned in rating_parity.test
// against the same case list.
//
// The strictness is the subtle part. Anything other than the boolean true must
// read as NOT counted: a malformed registry entry treated as counted would
// suppress a legitimate count for ever, and no re-run could repair it, because
// every path decides on the recorded state and never re-evaluates.
describe('the registry decision is strict about `counted`', () => {
  async function attemptCount(registry: Record<string, unknown> | null) {
    await seedBooking('b1');
    if (registry) {
      await db().collection(RATING_EVENTS).doc('r1').set(registry);
    }
    await countReview('r1', { reviewerId: CLIENT, bookingId: 'b1', rating: 4 });
    return agg();
  }

  it('counts when the registry document is ABSENT', async () => {
    expect(await attemptCount(null)).toMatchObject({ ratingCount: 1, ratingSum: 4 });
  });

  it('SKIPS when counted is the boolean true', async () => {
    expect(await attemptCount({ counted: true })).toBeNull();
  });

  it('counts when counted is the boolean false', async () => {
    expect(await attemptCount({ counted: false })).toMatchObject({ ratingCount: 1 });
  });

  it('counts when counted is absent from an existing document', async () => {
    expect(await attemptCount({ updatedAt: 1 })).toMatchObject({ ratingCount: 1 });
  });

  it('counts when counted is the NUMBER 1, not the boolean', async () => {
    // Truthiness would skip here and lose the rating with no repair path.
    expect(await attemptCount({ counted: 1 })).toMatchObject({ ratingCount: 1 });
  });

  it('counts when counted is the STRING "true"', async () => {
    expect(await attemptCount({ counted: 'true' })).toMatchObject({ ratingCount: 1 });
  });

  it('counts when counted is null', async () => {
    expect(await attemptCount({ counted: null })).toMatchObject({ ratingCount: 1 });
  });
});
