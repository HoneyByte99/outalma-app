#!/usr/bin/env python3
"""
Purge notification items whose bookingId/chatId points at a document that no
longer exists.

Context: a 2026-09 audit of production found 475 notifications in the
`notifications/{uid}/items` collection group, of which 85 pointed at a
bookingId that no longer existed and 50 at a chatId that no longer existed.
The cause was `onBookingDeleted` (functions/src/index.ts) only decrementing a
stat counter, and no `onChatDeleted` trigger existing at all: deleting a
booking or a chat left every notification that referenced it pointing at the
void, forever. Both triggers now also cascade-delete the notifications that
reference the deleted document (see functions/src/index.ts), so this script
only has pre-existing orphans to clean up: the cascade prevents new ones.

This script never re-derives that count against production; it recomputes it
live, the same way `orphan-bookings` in align-seed-data.py recomputes its own
orphan set rather than trusting a number from an old audit.

Usage:
  python3 scripts/purge-orphan-notifications.py            # audit, dry run
  python3 scripts/purge-orphan-notifications.py --apply    # delete orphans

Idempotent: a second run (with or without --apply) finds 0 orphans once the
first --apply pass has run, because the orphan set is recomputed from live
data every time, not cached.
Deterministic: no randomness anywhere; two audit runs against the same data
produce the same numbers.

Privacy: prints notification ids, recipient uids, notification types, and the
dangling bookingId/chatId (all opaque identifiers, never personal data). Never
a title, a body, a phone number, or an email: notification titles/bodies can
contain user-authored chat text and must never reach stdout.

Credentials are resolved (in order): $GOOGLE_APPLICATION_CREDENTIALS,
a --sa=<path> argument, then a repo-local scripts/service-account.json (same
resolution order as align-seed-data.py).
"""

import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore

ARGS = sys.argv[1:]
APPLY = "--apply" in ARGS

# Firestore batch writes are capped at 500 operations.
BATCH_SIZE = 400


def _arg(name, default=None):
    for a in ARGS:
        if a.startswith(f"--{name}="):
            return a.split("=", 1)[1]
    return default


def _service_account_path():
    p = _arg("sa")
    if p:
        return p
    return os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "service-account.json"
    )


cred = credentials.Certificate(_service_account_path())
firebase_admin.initialize_app(cred)
db = firestore.client()


def say(mode_label, line):
    print(f"[{mode_label}] {line}")


def mode():
    return "APPLIED" if APPLY else "DRY RUN"


def find_orphans():
    """Scans every notification item once and returns the orphaned ones.

    Two passes: first collect every distinct bookingId/chatId referenced by a
    notification, then resolve each distinct id with a single `get()` (a
    reference is typically shared by several notifications: a booking usually
    has more than one notification pointing at it over its lifetime), instead
    of checking existence once per notification.
    """
    notifs = list(db.collection_group("items").stream())

    booking_ids, chat_ids = set(), set()
    for n in notifs:
        data = n.to_dict() or {}
        if data.get("bookingId"):
            booking_ids.add(data["bookingId"])
        if data.get("chatId"):
            chat_ids.add(data["chatId"])

    live_bookings = {
        bid for bid in booking_ids
        if db.collection("bookings").document(bid).get().exists
    }
    live_chats = {
        cid for cid in chat_ids
        if db.collection("chats").document(cid).get().exists
    }

    orphans = []
    for n in notifs:
        data = n.to_dict() or {}
        booking_id = data.get("bookingId")
        chat_id = data.get("chatId")
        reason = None
        if booking_id and booking_id not in live_bookings:
            reason = ("bookingId", booking_id)
        elif chat_id and chat_id not in live_chats:
            reason = ("chatId", chat_id)
        if reason:
            orphans.append({
                "ref": n.reference,
                "uid": n.reference.parent.parent.id,
                "notif_id": n.id,
                "type": data.get("type"),
                "reason_field": reason[0],
                "reason_value": reason[1],
            })
    return len(notifs), orphans


def main():
    total, orphans = find_orphans()
    by_booking = [o for o in orphans if o["reason_field"] == "bookingId"]
    by_chat = [o for o in orphans if o["reason_field"] == "chatId"]

    say(mode(), f"notifications scanned={total} orphans={len(orphans)} "
                f"(bookingId={len(by_booking)} chatId={len(by_chat)})")

    by_type = {}
    for o in orphans:
        by_type[o["type"]] = by_type.get(o["type"], 0) + 1
    for t in sorted(by_type):
        print(f"      by type: {t}={by_type[t]}")

    for o in orphans[:5]:
        print(f"      e.g. uid={o['uid']} notif={o['notif_id']} "
              f"type={o['type']} dangling {o['reason_field']}={o['reason_value']}")

    if not APPLY:
        print(f"      would delete: {len(orphans)} (pass --apply to delete)")
        return 0

    batch = db.batch()
    n = 0
    for o in orphans:
        batch.delete(o["ref"])
        n += 1
        if n % BATCH_SIZE == 0:
            batch.commit()
            batch = db.batch()
    if n % BATCH_SIZE != 0:
        batch.commit()
    print(f"      deleted={len(orphans)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main() or 0)
