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

# The predicate is NOT redefined here. It lives in rating_predicate.py, which
# imports nothing beyond the standard library so a test can exercise it without
# a service account, and it is checked against the TypeScript on every run of
# the functions test suite.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rating_predicate import classify_review, is_counted, usable  # noqa: E402

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


def _registry_data(snap):
    """The registry document as a dict, or None when it does not exist."""
    return snap.to_dict() if snap.exists else None


@firestore.transactional
def count_once(tx, event_ref, agg_ref, rating):
    """The trigger's transaction, verbatim in intent: count exactly once."""
    event = event_ref.get(transaction=tx)
    # is_counted, not classify_review: inside the transaction the only open
    # question is the RECORDED STATE. The rest of the classification was settled
    # before we got here, and feeding a synthetic review back through the full
    # predicate would answer a different question (it has no reviewerId, so it
    # would classify as not_by_customer and this would never return False,
    # double counting every review).
    if is_counted(_registry_data(event)):
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
        event_ref = db.collection("rating_events").document(snap.id)

        # The registry is read for EVERY candidate review, in BOTH modes.
        #
        # This is the correction. The dry run used to `continue` before this
        # point, so it never consulted rating_events: already_counted was
        # structurally always 0, it could not tell whether the backfill had
        # already run, and it presented reviews already counted as work still to
        # do. A dry run that cannot answer that question is worse than none,
        # because it reads as an answer.
        #
        # classify_review takes the registry state as a VALUE, so it has to be
        # in hand before the verdict. The rating gate is repeated here only to
        # keep the cheapest rejection free of a read; a review that clears the
        # rating but fails on its booking or its author does now cost one read
        # it did not cost before. Measured against the real corpus that is about
        # 60 extra reads on a one-off operational script, which is not a price
        # worth an extra code path.
        registry = None
        if usable(review.get("rating")) is not None:
            registry = _registry_data(event_ref.get())

        verdict = classify_review(
            review, booking_of(review.get("bookingId")), registry
        )
        if verdict == "unusable_rating":
            skipped_rating += 1
            continue
        if verdict == "booking_missing":
            skipped_booking += 1
            continue
        if verdict == "hidden":
            skipped_hidden += 1
            continue
        if verdict == "not_by_customer":
            skipped_role += 1
            continue

        if not APPLY:
            # Same verdict the write path would reach, because it is the same
            # function reading the same registry document.
            if verdict == "already_counted":
                already += 1
            else:
                counted += 1
            continue

        booking = booking_of(review.get("bookingId"))
        rating = usable(review.get("rating"))
        agg_ref = db.collection("provider_ratings").document(booking["providerId"])
        # The transaction remains authoritative: the classification above is
        # taken outside it and can be stale by the time the write lands.
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
        if counted:
            print(f"  re-run with --apply to count {counted} review(s)")
        else:
            print(
                "  nothing to count: every eligible review is already in the registry"
            )


if __name__ == "__main__":
    main()
