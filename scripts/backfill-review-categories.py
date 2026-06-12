#!/usr/bin/env python3
"""
Backfill `categoryId` on existing reviews.

Each review concerns a service category, but legacy reviews were written
before that field existed. This derives it the same way the app now does at
write time: review -> bookingId -> booking.serviceId -> service.categoryId,
and writes it back onto the review.

Idempotent: reviews that already have a non-empty categoryId are left alone.
Privacy: only document ids and the category enum are read/printed — never
review comments or user names.

Credentials are resolved (in order): $GOOGLE_APPLICATION_CREDENTIALS,
a --sa=<path> argument, then a repo-local scripts/service-account.json
(git-ignored). No machine-specific path is baked in.

Usage:
  python3 scripts/backfill-review-categories.py            # dry run
  python3 scripts/backfill-review-categories.py --apply    # write
  python3 scripts/backfill-review-categories.py --sa=/path/to/sa.json --apply
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

# Small caches so we read each booking / service at most once.
_booking_service = {}   # bookingId -> serviceId | None
_service_category = {}  # serviceId -> categoryId | None


def service_id_for_booking(booking_id):
    if not booking_id:
        return None
    if booking_id in _booking_service:
        return _booking_service[booking_id]
    snap = db.collection("bookings").document(booking_id).get()
    svc = snap.to_dict().get("serviceId") if snap.exists else None
    _booking_service[booking_id] = svc
    return svc


def category_for_service(service_id):
    if not service_id:
        return None
    if service_id in _service_category:
        return _service_category[service_id]
    snap = db.collection("services").document(service_id).get()
    cat = snap.to_dict().get("categoryId") if snap.exists else None
    _service_category[service_id] = cat
    return cat


def main():
    mode = "APPLY" if APPLY else "DRY-RUN"
    print(f"=== Backfill review categories ({mode}) ===")

    counts = {
        "total": 0,
        "already": 0,
        "backfilled": 0,
        "no_booking": 0,
        "booking_missing_service": 0,
        "service_missing_category": 0,
    }

    batch = db.batch()
    pending = 0

    for doc in db.collection("reviews").stream():
        counts["total"] += 1
        data = doc.to_dict()

        existing = data.get("categoryId")
        if existing:  # non-empty -> already set
            counts["already"] += 1
            continue

        booking_id = data.get("bookingId")
        if not booking_id:
            counts["no_booking"] += 1
            print(f"  [SKIP] review/{doc.id}: no bookingId")
            continue

        service_id = service_id_for_booking(booking_id)
        if not service_id:
            counts["booking_missing_service"] += 1
            print(f"  [SKIP] review/{doc.id}: booking {booking_id} has no service")
            continue

        category = category_for_service(service_id)
        if not category:
            counts["service_missing_category"] += 1
            print(f"  [SKIP] review/{doc.id}: service {service_id} has no categoryId")
            continue

        counts["backfilled"] += 1
        print(f"  [SET ] review/{doc.id} -> {category} (svc {service_id})")
        if APPLY:
            batch.update(doc.reference, {"categoryId": category})
            pending += 1
            if pending >= 400:  # Firestore batch limit is 500
                batch.commit()
                batch = db.batch()
                pending = 0

    if APPLY and pending:
        batch.commit()

    print("\n--- Summary ---")
    for k, v in counts.items():
        print(f"  {k:26} {v}")
    if not APPLY and counts["backfilled"]:
        print("\nDry run only. Re-run with --apply to write these changes.")


if __name__ == "__main__":
    main()
