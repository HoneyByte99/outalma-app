#!/usr/bin/env python3
"""
Backfill the `audience` field on notification items written before it existed.

Context: `functions/src/index.ts` (onMessageCreated, ~line 546) writes
`audience: uid === chatCustomerId ? 'client' : 'provider'` on every new
`new_message` notification today, and every `booking_*` notification carries an
explicit audience from `onBookingStatusChange`'s own table. But 344 of the 391
notifications in `notifications/{uid}/items` predate the field (2026-09 audit):
325 `new_message` and 19 `booking_*`. The client fallback
(`notificationAudienceFor` in
lib/src/domain/models/app_notification.dart) renders any `new_message` without
`audience` as `both`, so it shows up under the Client tab and the Provider tab
alike: this is the actual bug Amath is seeing (a provider-mode chat surfacing
in his client notifications).

Deduction rule, a TRANSCRIPTION of the server's, never an approximation:

  new_message  read chats/{chatId}; audience = 'client' if the notification's
               owner (the uid segment of its path) is the chat's `customerId`,
               'provider' otherwise. Exactly
               `uid === chatCustomerId ? 'client' : 'provider'` from
               onMessageCreated. A notification whose chat is gone, or whose
               chat has no `customerId`, is NOT deducible: it is counted and
               left untouched, never guessed.

  booking_*    only the four types whose audience is invariant across every
               call site that creates them (see onBookingStatusChange in
               index.ts, and notificationAudienceFor's own legacy table):
                 booking_requested   -> provider
                 booking_accepted    -> client
                 booking_rejected    -> client
                 booking_in_progress -> client
               Every other booking_* type (booking_done goes to BOTH parties
               as two separate documents, booking_cancelled excludes whoever
               cancelled, booking_reminder goes to every participant) cannot
               be told apart by type alone and is left untouched.

Anything else without `audience` (service_approved, service_rejected,
provider_suspended, review_received, ...) is always provider- or
reviewee-scoped at every call site in index.ts/identity_verification.ts, but
none were found missing `audience` in the 2026-09 audit, so this script does
not touch them: touching a type with zero observed instances would be
unverifiable guesswork dressed as a rule.

Usage:
  python3 scripts/backfill-notification-audience.py            # audit, dry run
  python3 scripts/backfill-notification-audience.py --apply    # write audience

Idempotent: a second run (with or without --apply) finds 0 notifications
missing `audience`, because the target set is recomputed from live data every
time, not cached (same convention as purge-orphan-notifications.py).
Deterministic: the same input always produces the same plan; no randomness.

Privacy: prints notification ids, owner uids, chat ids, types and counts only.
Never a title, a body, a phone number, an email: notification titles/bodies can
carry user-authored chat text and must never reach stdout (same rule as
purge-orphan-notifications.py).

Credentials are resolved (in order): $GOOGLE_APPLICATION_CREDENTIALS,
a --sa=<path> argument, then a repo-local scripts/service-account.json (same
resolution order as align-seed-data.py and purge-orphan-notifications.py).

This script is NEVER run with --apply by an agent. Audit mode against
production is fine; applying the write is Amath's act alone.
"""

import os
import sys
import unittest

ARGS = sys.argv[1:]
APPLY = "--apply" in ARGS

# Firestore batch writes are capped at 500 operations.
BATCH_SIZE = 400

# The only types a value alone can settle, and what it settles to. Every other
# type (including every other booking_* type) is left untouched.
TYPE_AUDIENCE = {
    "booking_requested": "provider",
    "booking_accepted": "client",
    "booking_rejected": "client",
    "booking_in_progress": "client",
}


def resolve_audience(owner_uid, notif_type, chat):
    """The audience for one notification, or None if it cannot be deduced.

    `chat` is the chat document dict for `notif_type == 'new_message'`, or
    None if there is no chatId or the chat no longer exists. Pure function,
    no Firestore access, so it is unit-testable without credentials (see
    `_SelfTest` below) and is exactly what `--selftest` exercises.
    """
    if notif_type == "new_message":
        if not chat:
            return None
        customer_id = chat.get("customerId")
        if not customer_id:
            return None
        return "client" if owner_uid == customer_id else "provider"
    return TYPE_AUDIENCE.get(notif_type)


# --------------------------------------------------------------------------
# Firestore plumbing (only imported/used once resolve_audience is trusted;
# --selftest never touches this section).
# --------------------------------------------------------------------------

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


def _init_db():
    import firebase_admin
    from firebase_admin import credentials, firestore

    cred = credentials.Certificate(_service_account_path())
    firebase_admin.initialize_app(cred)
    return firestore.client()


def say(mode_label, line):
    print(f"[{mode_label}] {line}")


def mode():
    return "APPLIED" if APPLY else "DRY RUN"


def find_plan(db):
    """Scans every notification item missing `audience` and resolves each.

    `createNotification` used to spread `audience` into the write only when it
    was truthy (`...(data.audience ? {audience: data.audience} : {})`), before
    it became a required, guarded field (notify.ts, 2026-09): a notification
    never carries an explicit `null`, the field is either present with a real
    value or absent outright, which is exactly the legacy stock this script
    targets. A Firestore equality filter cannot distinguish "absent" from "any
    other value", so this reads every notification, same as
    purge-orphan-notifications.py's find_orphans, and filters in Python.

    Two passes: collect every distinct chatId referenced by a candidate
    new_message first, then resolve each distinct chat with one get() (a
    chatId is typically shared by several notifications over a conversation's
    lifetime).
    """
    notifs = [
        n for n in db.collection_group("items").stream()
        if "audience" not in (n.to_dict() or {})
    ]

    chat_ids = {
        (n.to_dict() or {}).get("chatId")
        for n in notifs
        if (n.to_dict() or {}).get("type") == "new_message"
        and (n.to_dict() or {}).get("chatId")
    }
    chats = {}
    for cid in chat_ids:
        snap = db.collection("chats").document(cid).get()
        if snap.exists:
            chats[cid] = snap.to_dict() or {}

    resolved, unresolved = [], []
    for n in notifs:
        data = n.to_dict() or {}
        owner_uid = n.reference.parent.parent.id
        notif_type = data.get("type")
        chat = chats.get(data.get("chatId")) if notif_type == "new_message" else None
        audience = resolve_audience(owner_uid, notif_type, chat)
        entry = {
            "ref": n.reference,
            "uid": owner_uid,
            "notif_id": n.id,
            "type": notif_type,
            "chat_id": data.get("chatId"),
            "audience": audience,
        }
        (resolved if audience else unresolved).append(entry)
    return notifs, resolved, unresolved


def main():
    if "--selftest" in ARGS:
        suite = unittest.TestLoader().loadTestsFromTestCase(_SelfTest)
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1

    db = _init_db()
    notifs, resolved, unresolved = find_plan(db)

    say(mode(), f"notifications scanned=(all) missing audience={len(notifs)}")

    by_type = {}
    for e in resolved + unresolved:
        by_type[e["type"]] = by_type.get(e["type"], 0) + 1
    for t in sorted(by_type):
        print(f"      by type: {t}={by_type[t]}")

    resolved_by_target = {}
    for e in resolved:
        resolved_by_target[e["audience"]] = resolved_by_target.get(e["audience"], 0) + 1
    print(f"      deducible: {len(resolved)} {resolved_by_target}")
    print(f"      NOT deducible (left untouched): {len(unresolved)}")

    unresolved_by_reason = {}
    for e in unresolved:
        reason = "no chatId" if e["type"] == "new_message" and not e["chat_id"] else (
            "chat missing/no customerId" if e["type"] == "new_message"
            else "type not in deduction table"
        )
        unresolved_by_reason[reason] = unresolved_by_reason.get(reason, 0) + 1
    for r in sorted(unresolved_by_reason):
        print(f"      not deducible because: {r}: {unresolved_by_reason[r]}")

    for e in resolved[:5]:
        print(f"      e.g. uid={e['uid']} notif={e['notif_id']} type={e['type']} "
              f"-> audience={e['audience']}")

    if not APPLY:
        print(f"      would write: {len(resolved)} (pass --apply to write)")
        return 0

    batch = db.batch()
    n = 0
    for e in resolved:
        batch.update(e["ref"], {"audience": e["audience"]})
        n += 1
        if n % BATCH_SIZE == 0:
            batch.commit()
            batch = db.batch()
    if n % BATCH_SIZE != 0:
        batch.commit()
    print(f"      written={len(resolved)}")
    return 0


# --------------------------------------------------------------------------
# Offline self-test of the deduction rule (no Firestore, no credentials).
# --------------------------------------------------------------------------

class _SelfTest(unittest.TestCase):
    def test_new_message_owner_is_customer(self):
        chat = {"customerId": "cust1", "providerId": "prov1"}
        self.assertEqual(resolve_audience("cust1", "new_message", chat), "client")

    def test_new_message_owner_is_provider(self):
        chat = {"customerId": "cust1", "providerId": "prov1"}
        self.assertEqual(resolve_audience("prov1", "new_message", chat), "provider")

    def test_new_message_no_chat_is_not_deducible(self):
        self.assertIsNone(resolve_audience("cust1", "new_message", None))

    def test_new_message_chat_without_customer_id_is_not_deducible(self):
        self.assertIsNone(
            resolve_audience("cust1", "new_message", {"providerId": "prov1"})
        )

    def test_booking_requested_is_provider(self):
        self.assertEqual(resolve_audience("u1", "booking_requested", None), "provider")

    def test_booking_accepted_rejected_in_progress_are_client(self):
        for t in ("booking_accepted", "booking_rejected", "booking_in_progress"):
            self.assertEqual(resolve_audience("u1", t, None), "client", t)

    def test_booking_done_is_not_deducible_by_type(self):
        # booking_done fans out to BOTH the customer and the provider as two
        # separate documents (index.ts ~line 620): the type alone cannot say
        # which of the two a given document belongs to.
        self.assertIsNone(resolve_audience("u1", "booking_done", None))

    def test_booking_cancelled_is_not_deducible_by_type(self):
        self.assertIsNone(resolve_audience("u1", "booking_cancelled", None))

    def test_booking_reminder_is_not_deducible_by_type(self):
        self.assertIsNone(resolve_audience("u1", "booking_reminder", None))

    def test_unknown_type_is_not_deducible(self):
        self.assertIsNone(resolve_audience("u1", "something_unknown", None))


if __name__ == "__main__":
    raise SystemExit(main() or 0)
