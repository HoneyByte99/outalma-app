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


def classify_review(review, booking, registry_data):
    """What the backfill should do with one review. Returns one of:

        "unusable_rating" | "booking_missing" | "hidden" | "not_by_customer"
        "already_counted" | "to_count"

    ONE decision function for BOTH modes, and `registry_data` is a required
    argument rather than something the caller may look up when it feels like it.
    That signature is the fix for the defect this replaced: the dry run used to
    return before ever reading `rating_events`, so it reported
    already_counted=0 always and presented reviews already counted as work
    still to do. A mode cannot now reach a verdict without supplying the
    registry state, so "the dry run forgot to look" is no longer expressible.

    Order of the checks is deliberately the order the script already used, so
    the counters it prints keep their historical meaning. It differs from the
    server's order (which tests the booking before the rating); that changes
    only which bucket an ignored review is reported under, never whether it
    counts.
    """
    if usable(review.get("rating")) is None:
        return "unusable_rating"
    if not booking:
        return "booking_missing"
    if review.get("hidden") is True:
        return "hidden"
    if not counts(review, booking):
        return "not_by_customer"
    if is_counted(registry_data):
        return "already_counted"
    return "to_count"


def is_counted(event_data):
    """Whether the registry says this review is already counted.

    Mirror of the one line the server decides on:

        const counted = eventSnap.exists && eventSnap.data()?.counted === true;

    Takes the registry document as a dict, or None when it does not exist, so
    the decision can be exercised without a Firestore snapshot.

    Strictly `is True`, never truthiness. `counted: 1` or `counted: "yes"` are
    not states this system writes, and treating them as counted would let a
    malformed registry entry suppress a legitimate count for ever, which no
    re-run could repair. The TypeScript uses `=== true` for the same reason.

    Shared by the backfill's transaction AND by its dry run. That sharing is
    the point: the dry run used to skip the registry entirely, so it always
    reported already_counted=0 and presented reviews already counted as work
    still to do.
    """
    if not event_data:
        return False
    return event_data.get("counted") is True


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
