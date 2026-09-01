#!/usr/bin/env python3
"""
The provider-rating predicate, in Python.

Mirror of `countsTowardProviderRating` and `isUsableRating` in
functions/src/provider_rating.ts. The two are two implementations of ONE rule,
and a divergence would make the aggregate disagree with what a replay computes,
silently and with nothing raising an alarm.

It lives in its own module, importing NOTHING beyond the standard library, for
one reason: backfill-provider-ratings.py opens a service account at import time,
so the predicate could not be exercised by a test while it lived there. Both the
backfill and the parity runner import it from here.

The shared table of cases is shared/rating-parity-cases.json, checked against
this file and against the TypeScript by functions/test/rating_parity.test.ts.
"""


def counts(review, booking):
    """Whether a review counts toward the PUBLIC rating of a provider.

    The author's role is established by the BOOKING, never by the review's own
    `reviewerRole`: that field is written by the client and no rule constrains
    it, so a provider could claim to be the customer. It is also absent from
    every historical review, so filtering on it would drop them all.
    """
    if not booking:
        return False
    customer = booking.get("customerId")
    provider = booking.get("providerId")
    if not customer or not provider or customer == provider:
        return False
    if review.get("hidden") is True:
        return False
    if not review.get("reviewerId"):
        return False
    return review.get("reviewerId") == customer


def usable(rating):
    """Returns the normalised int rating, or None. Returning the value rather
    than a boolean keeps a float 4.0 from reaching Increment() as a double."""
    # Firestore may hand back an integer as a float. The TypeScript side uses
    # Number.isInteger, which accepts 4.0; this must accept it too, or the two
    # implementations disagree on the same document.
    if isinstance(rating, bool):
        # A bool is an int in Python. Returning False here would pass the
        # caller's `is None` guard and reach Increment(False): +1 on the count,
        # +0 on the sum, marked counted, and no re-run could repair it.
        return None
    if isinstance(rating, float):
        if not rating.is_integer():
            return None
        rating = int(rating)
    if isinstance(rating, int) and 1 <= rating <= 5:
        return rating
    return None
