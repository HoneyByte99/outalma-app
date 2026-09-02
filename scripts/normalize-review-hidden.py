#!/usr/bin/env python3
"""
Write `hidden: false` on every `reviews/{id}` that lacks the field.

Reviews became publicly readable so a visitor can read them before creating an
account. The rule that opens them is:

    allow read: if signedIn() || resource.data.hidden == false;

and the exact shape is load bearing. Two facts about Firestore make this script
a HARD PREREQUISITE rather than a tidy-up:

  - A document that has no `hidden` field cannot satisfy `resource.data.hidden
    == false`: the rule fails to evaluate and the read is refused outright.
  - A query on an absent field matches NOTHING. So even the correct visitor
    query, `where('hidden', '==', false)`, silently skips every document written
    before the field existed. Not an error, just an empty result.

The historical corpus carries no `hidden` at all (absent means visible by
convention, see docs/domain-model-canonical.md). Deploying the rule before this
script has run makes every one of those reviews invisible to visitors, with no
error anywhere to say so.

Order of operations, and it does not commute:

    1. this script with --apply
    2. deploy firestore.rules
    3. ship the client

Going forward the field is written twice over: by the Dart serializer at
creation, and by the `onReviewCreated` trigger as a net under the clients
already installed on phones.

Scope: touches the `hidden` field and nothing else. Never a rating, never a
comment, never `createdAt`. It never changes a value that is already there, so
a moderated review (hidden: true) is left strictly alone: the field is written
only where it is ABSENT.

Idempotent: a second run finds nothing to do and reports 0 written. Safe to run
while the app is live, since it never touches a document another writer is
contending for on this field.

Privacy: reads document ids and the `hidden` field. Never a comment, never a
name. Nothing about a review is printed beyond its id.

Credentials are resolved (in order): $GOOGLE_APPLICATION_CREDENTIALS,
a --sa=<path> argument, then a repo-local scripts/service-account.json.

Usage:
  python3 scripts/normalize-review-hidden.py            # dry run
  python3 scripts/normalize-review-hidden.py --apply    # write
"""

import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore

APPLY = "--apply" in sys.argv[1:]

# Batched rather than one write per document: 85 documents today, but the corpus
# only grows and a per-document round trip is the kind of thing that turns a
# 3-second script into a 10-minute one without anybody deciding to.
BATCH_SIZE = 400


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


def needs_normalisation(review):
    """True when `hidden` is ABSENT.

    Deliberately not `not review.get("hidden")`: that would also catch
    `hidden: false`, which is already correct, and it would report every
    document as pending work on every run. Absence is the only condition, and
    `None` cannot be a stored value for this field.
    """
    return "hidden" not in review


def main():
    total = already_visible = already_hidden = to_write = 0
    batch = db.batch()
    pending = 0
    written = 0

    for snap in db.collection("reviews").stream():
        total += 1
        review = snap.to_dict() or {}

        if not needs_normalisation(review):
            # Counted separately so the dry run can say what the corpus looks
            # like, not merely how much is left to do.
            if review.get("hidden") is True:
                already_hidden += 1
            else:
                already_visible += 1
            continue

        to_write += 1
        if not APPLY:
            continue

        # update(), not set(merge=True): update fails loudly if the document
        # vanished between the stream and here, where a merge would recreate it
        # as a one-field orphan that no reader can make sense of.
        batch.update(snap.reference, {"hidden": False})
        pending += 1
        if pending >= BATCH_SIZE:
            batch.commit()
            written += pending
            batch = db.batch()
            pending = 0

    if APPLY and pending:
        batch.commit()
        written += pending

    mode = "APPLIED" if APPLY else "DRY RUN"
    print(f"[{mode}] reviews={total} missing_hidden={to_write} written={written}")
    print(
        f"  already correct: visible={already_visible} hidden={already_hidden}"
    )
    if not APPLY:
        if to_write:
            print(
                f"  {to_write} review(s) are invisible to a visitor until this runs "
                f"with --apply"
            )
        else:
            print("  nothing to do: every review already carries the field")
    elif written != to_write:
        # Not decoration: a mismatch means documents disappeared mid-run, and
        # the operator needs to re-run rather than assume the corpus is clean.
        print(
            f"  WARNING: expected to write {to_write} but wrote {written}, re-run to confirm",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
