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
    await countReview('r1', {
      reviewerId: CLIENT,
      bookingId: 'b1',
      rating: 4,
    });
  }

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
});
