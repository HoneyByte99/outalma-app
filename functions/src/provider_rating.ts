// ---------------------------------------------------------------------------
// Public provider rating: the aggregate a client reads before choosing
// ---------------------------------------------------------------------------
//
// Server-authoritative throughout, and deliberately kept OUT of
// `provider_trust`. That document is owned end to end by the identity
// subsystem, which DELETES it on reject and on revoke: an aggregate stored
// there would lose a provider's whole reputation the day a moderator refuses a
// blurry photo. What two values share when they sit in one document is not a
// document, it is a lifecycle.
//
// Reading it costs one document instead of the unbounded per-card reviews
// query it replaces (budget line D1).

import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

const db = () => admin.firestore();

export const RATINGS = 'provider_ratings';

/// Idempotency register for the aggregate. A dedicated collection, NOT
/// `processed_events`: that one is documented as purgeable by a 7 day TTL,
/// and the backfill's safety depends on this register being PERMANENT. Purging
/// it would recount every review older than a week on the next run.
export const RATING_EVENTS = 'rating_events';

export interface ReviewLike {
  reviewerId?: string;
  bookingId?: string;
  rating?: number;
  hidden?: boolean;
}

export interface BookingLike {
  customerId?: string;
  providerId?: string;
}

/// Whether a review counts toward the PUBLIC rating of a provider.
///
/// The author's role is established by the BOOKING, never by the review's own
/// `reviewerRole`. That field is written by the client and no rule constrains
/// it, so a provider could post `reviewerRole: 'client'` and have us publish a
/// world-readable reputation document for a customer (budget line S1: the
/// client may propose, never decide). It is also absent from every historical
/// review, so filtering on it would drop them all.
///
/// `hidden` keeps moderation effective on the number clients read first, and
/// the self-review clause closes a hole the rules leave open: `createBooking`
/// does not forbid booking your own service, and only the UI blocks it.
export function countsTowardProviderRating(
  review: ReviewLike,
  booking: BookingLike,
): boolean {
  if (!review.reviewerId || !booking.customerId || !booking.providerId) {
    return false;
  }
  if (booking.customerId === booking.providerId) return false;
  if (review.hidden === true) return false;
  return review.reviewerId === booking.customerId;
}

/// A rating value we are willing to publish. Anything else is data we do not
/// understand, and silently averaging it would be worse than ignoring it.
export function isUsableRating(rating: unknown): rating is number {
  return typeof rating === 'number' && Number.isInteger(rating)
    && rating >= 1 && rating <= 5;
}

export type RatingTransition = 'count' | 'discount';

/// Applies one rating transition, exactly once, whatever the caller.
///
/// The decision is taken on the RECORDED STATE (`counted`), never by
/// re-evaluating the predicate. Re-evaluating breaks twice: `unhideReview`
/// reads a review that is still hidden and would never restore anything, and a
/// `hideReview` landing before the backfill would subtract from an aggregate
/// that never held the review.
///
/// Returns true when the aggregate actually moved.
export async function applyRatingDelta(params: {
  reviewId: string;
  providerUid: string;
  rating: number;
  transition: RatingTransition;
  /// Only for 'count': the aggregate is created if missing. For 'discount' a
  /// missing aggregate means the account was deleted, and writing would
  /// resurrect a public document holding negative values behind it.
  createIfMissing: boolean;
}): Promise<boolean> {
  const { reviewId, providerUid, rating, transition, createIfMissing } = params;
  if (!isUsableRating(rating) || !providerUid) return false;

  const eventRef = db().collection(RATING_EVENTS).doc(reviewId);
  const aggRef = db().collection(RATINGS).doc(providerUid);
  const wantCounted = transition === 'count';

  return db().runTransaction(async (tx) => {
    const [eventSnap, aggSnap] = await Promise.all([
      tx.get(eventRef),
      tx.get(aggRef),
    ]);
    const counted = eventSnap.exists && eventSnap.data()?.counted === true;
    if (counted === wantCounted) return false; // already in the wanted state

    if (!wantCounted && !aggSnap.exists) {
      // Deleted account: leave nothing behind, but record the state so a later
      // replay cannot resurrect it either.
      tx.set(eventRef, {
        counted: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return false;
    }
    if (wantCounted && !aggSnap.exists && !createIfMissing) return false;

    const sign = wantCounted ? 1 : -1;
    tx.set(
      aggRef,
      {
        ratingSum: admin.firestore.FieldValue.increment(sign * rating),
        ratingCount: admin.firestore.FieldValue.increment(sign),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(eventRef, {
      counted: wantCounted,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });
}

/// Counts a review, resolving its role from the booking.
///
/// Mirrored in Python by scripts/backfill-provider-ratings.py, which replays
/// the same deduplicated transaction. The two must stay aligned: they are two
/// implementations of one predicate, and a divergence would make the aggregate
/// disagree with what a replay computes, silently.
export async function countReview(
  reviewId: string,
  review: ReviewLike,
): Promise<boolean> {
  if (!review.bookingId) {
    logger.warn('rating: review without bookingId, ignored', { reviewId });
    return false;
  }
  const bookingSnap = await db()
    .collection('bookings')
    .doc(review.bookingId)
    .get();
  if (!bookingSnap.exists) {
    logger.warn('rating: booking not found, review ignored', {
      reviewId,
      bookingId: review.bookingId,
    });
    return false;
  }
  const booking = bookingSnap.data() as BookingLike;
  if (!countsTowardProviderRating(review, booking)) return false;

  return applyRatingDelta({
    reviewId,
    providerUid: booking.providerId as string,
    rating: review.rating as number,
    transition: 'count',
    createIfMissing: true,
  });
}

/// Removes a review from the aggregate: moderation hiding it, or deleting it.
/// Ignores `hidden`, since by the time this runs the review is already hidden.
export async function discountReview(
  reviewId: string,
  review: ReviewLike,
): Promise<boolean> {
  if (!review.bookingId) return false;
  const bookingSnap = await db()
    .collection('bookings')
    .doc(review.bookingId)
    .get();
  if (!bookingSnap.exists) return false;
  const booking = bookingSnap.data() as BookingLike;
  if (!booking.providerId) return false;

  return applyRatingDelta({
    reviewId,
    providerUid: booking.providerId,
    rating: review.rating as number,
    transition: 'discount',
    createIfMissing: false,
  });
}

/// Restores a review previously hidden. The `hidden` flag is skipped on
/// purpose: it is still true on the document being unhidden.
export async function recountReview(
  reviewId: string,
  review: ReviewLike,
): Promise<boolean> {
  if (!review.bookingId) return false;
  const bookingSnap = await db()
    .collection('bookings')
    .doc(review.bookingId)
    .get();
  if (!bookingSnap.exists) return false;
  const booking = bookingSnap.data() as BookingLike;
  if (!countsTowardProviderRating({ ...review, hidden: false }, booking)) {
    return false;
  }

  return applyRatingDelta({
    reviewId,
    providerUid: booking.providerId as string,
    rating: review.rating as number,
    transition: 'count',
    // NOT createIfMissing: unhiding a review whose provider has since deleted
    // their account would otherwise recreate a world-readable document behind
    // a deleted account, the mirror of the case the discount path guards.
    createIfMissing: false,
  });
}
