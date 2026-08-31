#!/usr/bin/env python3
"""
Backfill `provider_ratings/{uid}` from the existing reviews.

Without this, every provider in the catalogue reads as "Nouveau" the day the
aggregate ships, because the trigger only sees reviews created after it.

It does NOT recompute an absolute value. An absolute write, computed from a
read taken earlier, erases the increment of a review that arrived in between,
and the pass meant to conclude "no drift" can be the very one that loses the
data. Instead this replays the trigger's own deduplicated transaction, one
review at a time, keyed by rating_events/{reviewId}. Trigger and script then
serialise on that document: nothing is double counted, nothing is lost, and
the script is safe to run while the trigger is live.

It replays ONLY the increment. Never the notifications: "replay the trigger"
must not become "call the handler", which would push a "Nouvel avis" for every
review written since June.

The author's role is resolved from the BOOKING, exactly as the server does:
`reviewerRole` is written by the client, no rule constrains it, and it is
absent from the seeded corpus.

Privacy: reads ids and rating integers only. Never a comment, never a name.

Credentials are resolved (in order): $GOOGLE_APPLICATION_CREDENTIALS,
a --sa=<path> argument, then a repo-local scripts/service-account.json.

Usage:
  python3 scripts/backfill-provider-ratings.py            # dry run
  python3 scripts/backfill-provider-ratings.py --apply    # write
"""

import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore

APPLY = "--apply" in sys.argv[1:]


def _service_account_path():
    for arg in sys.argv[1:]:
        if arg.startswith("--sa="):
            return arg.split("=", 1)[1]
    env = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if env:
        return env
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "service-account.json")


cred = credentials.Certificate(_service_account_path())
firebase_admin.initialize_app(cred)
db = firestore.client()

_bookings = {}


def booking_of(booking_id):
    if not booking_id:
        return None
    if booking_id not in _bookings:
        snap = db.collection("bookings").document(booking_id).get()
        _bookings[booking_id] = snap.to_dict() if snap.exists else None
    return _bookings[booking_id]


def counts(review, booking):
    """Mirror of countsTowardProviderRating in functions/src/provider_rating.ts."""
    if not booking:
        return False
    customer = booking.get("customerId")
    provider = booking.get("providerId")
    if not customer or not provider or customer == provider:
        return False
    if review.get("hidden") is True:
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


@firestore.transactional
def count_once(tx, event_ref, agg_ref, rating):
    """The trigger's transaction, verbatim in intent: count exactly once."""
    event = event_ref.get(transaction=tx)
    if event.exists and event.to_dict().get("counted") is True:
        return False
    tx.set(
        agg_ref,
        {
            "ratingSum": firestore.Increment(rating),
            "ratingCount": firestore.Increment(1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    tx.set(event_ref, {"counted": True, "updatedAt": firestore.SERVER_TIMESTAMP})
    return True


def main():
    counted = skipped_role = skipped_hidden = skipped_booking = skipped_rating = 0
    already = 0

    for snap in db.collection("reviews").stream():
        review = snap.to_dict() or {}
        rating = usable(review.get("rating"))
        if rating is None:
            skipped_rating += 1
            continue
        booking = booking_of(review.get("bookingId"))
        if booking is None:
            skipped_booking += 1
            continue
        if review.get("hidden") is True:
            skipped_hidden += 1
            continue
        if not counts(review, booking):
            skipped_role += 1
            continue

        if not APPLY:
            counted += 1
            continue

        event_ref = db.collection("rating_events").document(snap.id)
        agg_ref = db.collection("provider_ratings").document(booking["providerId"])
        if count_once(db.transaction(), event_ref, agg_ref, rating):
            counted += 1
        else:
            already += 1

    mode = "APPLIED" if APPLY else "DRY RUN"
    print(f"[{mode}] counted={counted} already_counted={already}")
    print(
        f"  ignored: not_by_customer={skipped_role} hidden={skipped_hidden} "
        f"booking_missing={skipped_booking} unusable_rating={skipped_rating}"
    )
    if not APPLY:
        print("  re-run with --apply to write")


if __name__ == "__main__":
    main()
