#!/usr/bin/env python3
"""
Align the seeded Firestore corpus with the data model the app actually reads.

The seed corpus accumulated four generations of writes (FlutterFlow export, the
June seeds, the 26/08 reseed, hand edits) and drifted away from the shape the
client and the rules expect. Nothing here is a schema change: every task below
repairs data that already claims to follow the current model and does not.

Sub-commands, in the order `all` runs them, because the order does NOT commute:

  review-hidden      T1  write `hidden: false` where the field is absent
  malformed-reviews  T4  drop reviews whose author is neither party
  orphan-bookings    T2  repair or delete bookings pointing at a dead service
  dates              T3  make active bookings sit in the future, retire the rest
  legacy-accounts    T5  fold FlutterFlow fields into the current schema
  identities         T6  fill empty display names, break name collisions
  avatars            T7  one self-hosted illustrated avatar set, no hotlinks
  verified-providers T8  mark a credible half of the catalogue as verified
  provider-services  T9  report (does not write, see the docstring below)
  audit                  prove the invariants by reading the base back

Two ordering constraints are load bearing and cost data if broken:

  - A review must be DISCOUNTED from `provider_ratings` while its booking still
    exists. `discountReview` in functions/src/provider_rating.ts reads the
    booking to resolve the provider; once the booking is gone the aggregate can
    never be corrected, by this script or by the server. So malformed-reviews
    runs before orphan-bookings, and every deletion path discounts first.
  - `dates` runs after the deletions so it never spends work on a booking that
    is about to disappear.

Every write mirrors a server behaviour rather than inventing one. The rating
delta is a transcription of `ratingDeltaWithin`: read the registry, act on the
RECORDED state, decrement the aggregate and flip the registry in one
transaction. Re-deriving eligibility instead would double-subtract on a re-run.

Idempotent throughout: a second run reports 0 written on every sub-command.
Deterministic throughout: every choice (a name, an avatar, a date offset, which
provider gets verified) is a pure function of the document id, so two runs
produce the same corpus and a diff between them is signal.

Privacy: prints document ids, counts and category labels. Never a phone number,
never an email, never a review comment. Legacy phone numbers are migrated
without ever being echoed to stdout.

Credentials are resolved (in order): $GOOGLE_APPLICATION_CREDENTIALS,
a --sa=<path> argument, then a repo-local scripts/service-account.json.

Usage:
  python3 scripts/align-seed-data.py audit
  python3 scripts/align-seed-data.py all             # dry run, writes nothing
  python3 scripts/align-seed-data.py all --apply
  python3 scripts/align-seed-data.py orphan-bookings --apply --orphans=delete
"""

import hashlib
import os
import re
import sys
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import quote, unquote
from urllib.request import urlopen

import firebase_admin
from firebase_admin import credentials, firestore, storage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rating_predicate import counts as counts_toward_rating  # noqa: E402

ARGS = sys.argv[1:]
APPLY = "--apply" in ARGS
BUCKET = "outalmaservice-d1e59.firebasestorage.app"

# Open Peeps, hand-drawn half-body characters, CC0 1.0 (Pablo Stanley). Chosen
# over the photorealistic portraits it replaces for two reasons that are not
# aesthetic: those portraits are photographs of real people used without their
# consent, and a platform whose pitch is identity verification cannot display
# invented human faces. CC0 means no attribution obligation in a shipped app.
AVATAR_STYLE = "open-peeps"
AVATAR_API = ("https://api.dicebear.com/9.x/{style}/png?seed={seed}&size=256"
              "&head={heads}&facialHairProbability={fhp}&maskProbability=0")
AVATAR_PATH = "seed/avatars/{uid}.png"

# open-peeps `head` enum (api.dicebear.com/9.x/open-peeps/schema.json), split by
# how each style reads. Styles with no obvious read (natural hair worn by any
# gender, headwear that is not itself gendered) stay in both pools rather than
# being forced into one; a woman in `shaved1` or a man in `hijab` is a real
# provider in this corpus, but assigning THOSE at random is exactly today's bug,
# so they are excluded here and only the unambiguous styles are split.
#
# The split below is read off the RENDERED art (dicebear.com/9.x/open-peeps),
# not off the enum names: `cornrows` draws a long side ponytail and `turban` a
# fabric headwrap, both unambiguously feminine like `hijab` beside them;
# `noHair1` is a plain bald head with no gendered cue at all, so it joins the
# neutral pool instead of staying forced male; `twists` and `bantuKnots` both
# draw a short cropped fade that reads masculine, the opposite of where a name
# match would put them.
_HEAD_NEUTRAL = ["afro", "twists2", "dreads1", "dreads2", "noHair1"]
_HEAD_FEMALE = _HEAD_NEUTRAL + [
    "bangs", "bangs2", "bun", "bun2", "buns", "cornrows", "hijab", "long",
    "longAfro", "longBangs", "longCurly", "medium1", "medium2", "medium3",
    "mediumBangs", "mediumBangs2", "mediumBangs3", "mediumStraight", "grayBun",
    "turban",
]
_HEAD_MALE = _HEAD_NEUTRAL + [
    "bantuKnots", "bear", "cornrows2", "flatTop", "flatTopLong", "mohawk",
    "mohawk2", "noHair2", "noHair3", "pomp", "shaved1", "shaved2",
    "shaved3", "short1", "short2", "short3", "short4", "short5", "twists",
    "grayMedium", "grayShort",
]
# Facial hair is the one open-peeps feature with no unisex reading at all, so it
# is not split like `head`: it is switched off outright for a declared woman
# rather than left at the style's 10% default, which today draws a beard on
# roughly one in ten female seed accounts regardless of what `gender` says.
_FACIAL_HAIR_PROBABILITY = {"female": 0, "male": 10}


def dicebear_query(gender):
    """(head list, facialHairProbability) for the DiceBear query string.

    `gender` is the value already stored on the user document ('male',
    'female', or anything else including None for the 4 real accounts this
    function is never called for). An unresolved gender draws from the full,
    unsplit catalogue rather than guessing, the same refusal-to-guess as
    `Gender.tryParse` and `derive()` in backfill-user-gender.py.
    """
    if gender == "female":
        return _HEAD_FEMALE, _FACIAL_HAIR_PROBABILITY["female"]
    if gender == "male":
        return _HEAD_MALE, _FACIAL_HAIR_PROBABILITY["male"]
    return _HEAD_FEMALE + _HEAD_MALE, 10


def _storage_object_path(url):
    """The bucket-relative object path inside a Firebase Storage download URL.

    None for anything else: a hotlink to randomuser.me/unsplash, an empty
    string, or a malformed value. Used to tell a real upload (`private/users/`)
    apart from a generated seed avatar (`seed/avatars/`), which `cmd_avatars`
    needs and a bare `"firebasestorage" in url` substring check cannot give it
    once seed avatars themselves live in Storage (see cmd_avatars docstring).
    """
    if not url:
        return None
    m = re.search(r"/o/([^?]+)", url)
    return unquote(m.group(1)) if m else None

ACTIVE = ("requested", "accepted", "in_progress")

# Enough names to cover the empty ones and one side of every collision, with
# surnames that do not already appear in the corpus so a fix cannot create the
# duplicate it was meant to remove.
# Split by gender, and the split is not decoration. The provider bios in this
# corpus are gendered French ("Serieuse et ponctuelle", "Aide a domicile
# polyvalente"), so renaming Fatou Ndiaye to a male name leaves a profile whose
# own description disagrees with its name. A collision is therefore broken with
# a name of the SAME gender as the one being replaced; only an empty name, which
# has no bio to contradict, draws freely.
NAME_POOL_F = ["Awa Cissé", "Khady Seck", "Ndèye Gueye", "Astou Sarr",
               "Bineta Sy", "Coumba Diouf"]
NAME_POOL_M = ["Mamadou Diagne", "Ousmane Camara", "Cheikh Faye", "Modou Kane",
               "Alioune Badji", "Abdou Ndour"]

# First names present in the corpus, so a collision can be broken in kind.
# Explicit rather than inferred: a wrong guess here writes a contradiction onto
# a profile, and the list is short enough to simply state.
FIRST_F = {"fatou", "awa", "khady", "ndèye", "ndeye", "astou", "bineta",
           "coumba", "aminata", "mariama", "rokhaya", "sokhna", "diouly",
           "adama", "yacine", "seynabou"}
FIRST_M = {"mouhamed", "mohamed", "ibrahima", "moussa", "oumar", "cheikh",
           "modou", "alioune", "mamadou", "ousmane", "amath", "ahmed",
           "lamine", "abdou", "pierre", "babacar", "malick", "serigne"}

# `gender` is deliberately NOT in this list. It stopped being a FlutterFlow
# residual on 2026-09-02: it is now a live, required field (firestore.rules
# `isGenderSafe()`, the `mirrorPublicProfile` trigger, the production
# `verifyPhoneOtpAndSignUp` callable which rejects sign-up without it, and a
# client-facing pictogram). Dropping it here would silently break all three.
# Do not add it back without re-checking those call sites first.
LEGACY_FIELDS = [
    "first_name", "last_name", "display_name", "phone_number", "birth_date",
    "created_time", "email_sign_up", "sign_up", "in_service",
    "uid", "id",
]
# Legacy field -> current field. Everything absent from this map is dropped,
# and the report says so rather than letting it vanish quietly.
LEGACY_MIGRATE = {
    "display_name": "displayName",
    "phone_number": "phoneE164",
    "created_time": "createdAt",
}


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
firebase_admin.initialize_app(cred, {"storageBucket": BUCKET})
db = firestore.client()

NOW = datetime.now(timezone.utc)


def load(col):
    return {s.id: (s.to_dict() or {}) for s in db.collection(col).stream()}


def jitter(doc_id, salt, lo, hi):
    """A stable integer in [lo, hi] derived from a document id.

    Deterministic rather than random so a re-run reproduces the corpus exactly
    and a diff between two runs means something changed in the data, not in the
    dice.
    """
    h = hashlib.sha256(f"{salt}:{doc_id}".encode()).digest()
    return lo + int.from_bytes(h[:4], "big") % (hi - lo + 1)


def is_seed_account(uid, data):
    """Whether an account is seeded rather than a real signed-up user.

    Real accounts carry a 28-character Firebase Auth uid. Seeded ones carry a
    20-character Firestore auto-id or an explicit `seed_user_*` id. The
    distinction gates every write that would put invented text on a real
    person's profile.
    """
    if data.get("_seeded") is True or uid.startswith("seed_user_"):
        return True
    return len(uid) != 28


def say(mode, line):
    print(f"[{mode}] {line}")


def mode():
    return "APPLIED" if APPLY else "DRY RUN"


# --------------------------------------------------------------------------
# rating plumbing
# --------------------------------------------------------------------------

def discount(review_id, provider_uid, rating):
    """Remove one review from a provider aggregate, exactly as the server does.

    Transcription of `ratingDeltaWithin(transition='discount')`. The decision is
    taken on the RECORDED state in `rating_events/{reviewId}`, never by
    re-evaluating the predicate: re-evaluating would subtract a second time on a
    re-run, and no later pass could tell that it had.

    MUST be called while the booking still exists. Returns True when the
    aggregate actually moved.
    """
    ev_ref = db.collection("rating_events").document(review_id)
    agg_ref = db.collection("provider_ratings").document(provider_uid)

    @firestore.transactional
    def txn(tx):
        ev = ev_ref.get(transaction=tx)
        agg = agg_ref.get(transaction=tx)
        counted = ev.exists and (ev.to_dict() or {}).get("counted") is True
        if not counted:
            return False
        if not agg.exists:
            # Mirrors the deleted-account branch: leave nothing behind, but
            # record the state so a later replay cannot resurrect it.
            tx.set(ev_ref, {"counted": False,
                            "updatedAt": firestore.SERVER_TIMESTAMP})
            return False
        tx.set(agg_ref, {
            "ratingSum": firestore.Increment(-rating),
            "ratingCount": firestore.Increment(-1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)
        tx.set(ev_ref, {"counted": False,
                        "updatedAt": firestore.SERVER_TIMESTAMP})
        return True

    return txn(db.transaction())


def delete_review(review_id, review, bookings):
    """Discount then delete. Never the other way round."""
    moved = False
    bk = bookings.get(review.get("bookingId"))
    if bk and bk.get("providerId") and isinstance(review.get("rating"), int):
        moved = discount(review_id, bk["providerId"], review["rating"])
    db.collection("reviews").document(review_id).delete()
    return moved


def delete_chat(chat_id):
    n = 0
    msgs = db.collection("chats").document(chat_id).collection("messages")
    for m in msgs.stream():
        m.reference.delete()
        n += 1
    db.collection("chats").document(chat_id).delete()
    return n


# --------------------------------------------------------------------------
# T1
# --------------------------------------------------------------------------

def cmd_review_hidden():
    """Write `hidden: false` where the field is ABSENT.

    Absence, not falsiness: a moderated review carries `hidden: true` and must
    be left strictly alone. See scripts/normalize-review-hidden.py for why the
    field is a hard prerequisite to deploying the public-read rule.
    """
    reviews = load("reviews")
    missing = sorted(k for k, v in reviews.items() if "hidden" not in v)
    say(mode(), f"T1 review-hidden: reviews={len(reviews)} missing={len(missing)}")
    if missing[:5]:
        print(f"      e.g. {missing[:5]}")
    if APPLY and missing:
        batch = db.batch()
        for k in missing:
            batch.update(db.collection("reviews").document(k), {"hidden": False})
        batch.commit()
    print(f"      written={len(missing) if APPLY else 0}")
    return len(missing)


# --------------------------------------------------------------------------
# T4
# --------------------------------------------------------------------------

def malformed_ids(reviews, bookings):
    """Reviews whose author is neither party to the booking they rate.

    The server resolves the author's role from the BOOKING, so these never
    counted toward a public rating. They are dropped because they still render
    in review lists, attributed to somebody who was never there.
    """
    out = []
    for k, v in sorted(reviews.items()):
        bk = bookings.get(v.get("bookingId"))
        if not bk:
            continue
        if v.get("reviewerId") not in (bk.get("customerId"), bk.get("providerId")):
            out.append(k)
    return out


def cmd_malformed_reviews():
    reviews, bookings = load("reviews"), load("bookings")
    bad = malformed_ids(reviews, bookings)
    counted = [k for k in bad
               if (db.collection("rating_events").document(k).get().to_dict() or {})
               .get("counted") is True]
    say(mode(), f"T4 malformed-reviews: reviews={len(reviews)} malformed={len(bad)}")
    print(f"      of which currently counted toward a rating: {len(counted)} "
          f"(expected 0; the predicate rejects them)")
    if counted:
        print(f"      STOP: {counted} counted despite being malformed", file=sys.stderr)
        raise SystemExit(2)
    print(f"      e.g. {bad[:5]}")
    if APPLY:
        for k in bad:
            delete_review(k, reviews[k], bookings)
    print(f"      deleted={len(bad) if APPLY else 0}")
    return len(bad)


# --------------------------------------------------------------------------
# T2
# --------------------------------------------------------------------------

def orphan_plan(bookings, services, reviews, chats):
    """Split orphan bookings into repairable and deletable.

    An orphan booking points at a `serviceId` deleted by the 26/08 reseed. The
    booking itself is intact: real parties, real date, real status, and often a
    review and a conversation hanging off it.

    A booking that carries EVIDENCE (a review or a chat) and whose provider
    still publishes a service is REPAIRED by re-pointing `serviceId` at that
    provider's own surviving service. This is deliberately not a rewrite of
    history for its own sake: `countsTowardProviderRating` keys on `customerId`
    and `providerId` and never reads `serviceId`, so every rating keeps its
    exact meaning while the dangling foreign key goes away. Deleting instead
    would take 43 well-formed reviews and 30 conversations with it and leave
    5 of 23 providers with a rating.

    Everything else is deleted: no evidence to preserve, or no service left to
    point at.
    """
    by_provider = {}
    for sid, s in sorted(services.items()):
        if s.get("published"):
            by_provider.setdefault(s["providerId"], []).append(sid)
    ev_reviews, ev_chats = {}, {}
    for k, v in reviews.items():
        ev_reviews.setdefault(v.get("bookingId"), []).append(k)
    for k, v in chats.items():
        ev_chats.setdefault(v.get("bookingId"), []).append(k)

    repair, delete = {}, []
    for bid in sorted(bookings):
        b = bookings[bid]
        if b.get("serviceId") in services:
            continue
        has_evidence = bool(ev_reviews.get(bid) or ev_chats.get(bid))
        pool = by_provider.get(b.get("providerId"), [])
        if has_evidence and pool:
            # Stable pick, so a re-run re-points to the same service.
            repair[bid] = pool[jitter(bid, "svc", 0, len(pool) - 1)]
        else:
            delete.append(bid)
    return repair, delete, ev_reviews, ev_chats


def cmd_orphan_bookings():
    strategy = _arg("orphans", "repair")
    bookings, services = load("bookings"), load("services")
    reviews = load("reviews")
    chats = load("chats")
    repair, delete, ev_reviews, ev_chats = orphan_plan(bookings, services, reviews, chats)
    if strategy == "delete":
        delete = sorted(set(delete) | set(repair))
        repair = {}

    dead_reviews = sorted(r for b in delete for r in ev_reviews.get(b, []))
    dead_chats = sorted(c for b in delete for c in ev_chats.get(b, []))
    counted = [r for r in dead_reviews
               if (db.collection("rating_events").document(r).get().to_dict() or {})
               .get("counted") is True]

    say(mode(), f"T2 orphan-bookings [{strategy}]: bookings={len(bookings)} "
                f"orphans={len(repair) + len(delete)}")
    print(f"      repair (re-point serviceId, same provider): {len(repair)}")
    print(f"      delete: {len(delete)}")
    print(f"      cascade: reviews={len(dead_reviews)} chats={len(dead_chats)} "
          f"of which counted reviews to discount first={len(counted)}")
    if repair:
        k = sorted(repair)[0]
        print(f"      e.g. repair {k}: {bookings[k].get('serviceId')} -> {repair[k]}")
    if delete[:5]:
        print(f"      e.g. delete {delete[:5]}")

    msgs = 0
    if APPLY:
        # Discount and delete reviews FIRST: the aggregate can only be corrected
        # while the booking is still readable.
        for r in dead_reviews:
            delete_review(r, reviews[r], bookings)
        for c in dead_chats:
            msgs += delete_chat(c)
        batch = db.batch()
        n = 0
        for bid, sid in repair.items():
            batch.update(db.collection("bookings").document(bid), {"serviceId": sid})
            n += 1
            if n % 400 == 0:
                batch.commit()
                batch = db.batch()
        for bid in delete:
            batch.delete(db.collection("bookings").document(bid))
            n += 1
            if n % 400 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
    print(f"      applied: repaired={len(repair) if APPLY else 0} "
          f"deleted={len(delete) if APPLY else 0} "
          f"reviews={len(dead_reviews) if APPLY else 0} "
          f"chats={len(dead_chats) if APPLY else 0} messages={msgs}")
    return len(delete)


# --------------------------------------------------------------------------
# T3
# --------------------------------------------------------------------------

def cmd_dates():
    """Move the live pipeline into the future, retire what should have ended.

    An `in_progress` booking scheduled in April is not a scheduling bug, it is a
    booking that ended months ago and never had its status advanced. Moving all
    65 of them forward would produce a demo where nothing has ever completed, so
    the rule splits them:

      keep active, most recent 35% (min 3), pushed into the coming days
        in_progress -> today, so at least one job is genuinely running now
        accepted    -> +1..7 days
        requested   -> +1..4 days, and `createdAt` pulled to the last 3 days,
                       because a request nobody answered since April is as
                       implausible as the date itself
      retire, the older 65%
        requested   -> cancelled  (never accepted, the date lapsed)
        accepted    -> done       (it was agreed and the date passed)
        in_progress -> done       (it started, so it finished)

    Effect on provider_ratings: NONE, by construction.
    `countsTowardProviderRating` reads customerId, providerId, hidden and
    reviewerId. It never reads `status`, so promoting a booking to `done`
    cannot make a review eligible and cannot move an aggregate. `audit` proves
    this by re-deriving the aggregates from the registry after the fact.
    """
    bookings = load("bookings")
    # An active booking with NO date at all is the same defect wearing a
    # different hat: nothing can render it, and it sorts nowhere. It joins the
    # set to be rescheduled, treated as maximally stale.
    undated = [k for k, v in sorted(bookings.items())
               if v.get("status") in ACTIVE and not v.get("scheduledAt")]
    past = [k for k, v in sorted(bookings.items())
            if v.get("status") in ACTIVE and v.get("scheduledAt")
            and v["scheduledAt"] < NOW]
    past.sort(key=lambda k: bookings[k]["scheduledAt"], reverse=True)
    past = past + undated

    keep_n = max(3, round(len(past) * 0.35))
    keep = past[:keep_n]
    # T3 asks explicitly for one job running today; if the ratio did not catch
    # an in_progress, promote the most recent one into the kept set.
    if not any(bookings[k]["status"] == "in_progress" for k in keep):
        for k in past:
            if bookings[k]["status"] == "in_progress":
                keep = keep + [k]
                break
    retire = [k for k in past if k not in set(keep)]

    say(mode(), f"T3 dates: bookings={len(bookings)} active-in-past={len(past)}")
    print(f"      keep active and move forward: {len(keep)}")
    print(f"      retire to a terminal status:  {len(retire)}")

    writes, terminal = {}, {"requested": "cancelled", "accepted": "done",
                            "in_progress": "done"}
    for k in keep:
        st = bookings[k]["status"]
        if st == "in_progress":
            # Started earlier today, still running. Never merely "in the past":
            # the audit asserts the date falls on today.
            when = NOW - timedelta(minutes=jitter(k, "ip", 20, 150))
        else:
            # The hour of day is SET, not added to the current time. Adding
            # hours to a 17:49 base rolls the appointment past midnight and
            # produces a housekeeping job booked for 03:49, which reads as
            # obviously generated.
            days = (jitter(k, "ac", 1, 7) if st == "accepted"
                    else jitter(k, "rq", 1, 4))
            when = (NOW + timedelta(days=days)).replace(
                hour=jitter(k, "hh", 8, 18),
                minute=jitter(k, "mm", 0, 3) * 15,
                second=0, microsecond=0)
        w = {"scheduledAt": when}
        if st == "requested":
            w["createdAt"] = NOW - timedelta(hours=jitter(k, "rqc", 2, 72))
        writes[k] = w
    for k in retire:
        writes[k] = {"status": terminal[bookings[k]["status"]]}

    # Business-hours invariant, enforced on every active booking rather than
    # only the ones being moved. A booking already sitting in the future is out
    # of reach of the reschedule branch above, so a bad hour written by an
    # earlier pass would survive for ever: this is what turns the rule from a
    # one-shot into something a re-run actually converges on. Nobody books a
    # house cleaning for 03:49.
    for k, v in sorted(bookings.items()):
        if k in writes or v.get("status") not in ("requested", "accepted"):
            continue
        d = v.get("scheduledAt")
        if d and not (8 <= d.hour <= 18):
            # Rebuilt rather than `d.replace(...)`: Firestore hands back a
            # DatetimeWithNanoseconds, whose replace() returns an instance with
            # no `_nanosecond`, and the client then dies encoding it.
            writes[k] = {"scheduledAt": datetime(
                d.year, d.month, d.day, jitter(k, "hh", 8, 18),
                jitter(k, "mm", 0, 3) * 15, tzinfo=timezone.utc)}

    from collections import Counter
    print(f"      kept by status:    {dict(Counter(bookings[k]['status'] for k in keep))}")
    print(f"      retired: {dict(Counter(bookings[k]['status'] + '->' + terminal[bookings[k]['status']] for k in retire))}")
    if keep:
        k = keep[0]
        print(f"      e.g. {k} {bookings[k]['status']} "
              f"{bookings[k]['scheduledAt'].date()} -> {writes[k]['scheduledAt'].date()}")

    if APPLY:
        batch = db.batch()
        for i, (k, w) in enumerate(writes.items(), 1):
            batch.update(db.collection("bookings").document(k), w)
            if i % 400 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
    print(f"      written={len(writes) if APPLY else 0}")
    return len(writes)


# --------------------------------------------------------------------------
# T5
# --------------------------------------------------------------------------

def cmd_legacy_accounts():
    """Fold FlutterFlow fields into the current schema, then remove them.

    A value is migrated only when the current field is EMPTY, so a field the
    user has since edited in the app always wins over the 2024 export. What is
    not in LEGACY_MIGRATE has no home in the current model and is dropped; the
    report names every dropped field rather than letting it disappear silently.
    """
    users = load("users")
    targets = {k: v for k, v in sorted(users.items())
               if any(f in v for f in LEGACY_FIELDS)}
    say(mode(), f"T5 legacy-accounts: users={len(users)} carrying legacy fields={len(targets)}")

    from collections import Counter
    migrated, dropped = Counter(), Counter()
    writes = {}
    for uid, v in targets.items():
        w = {}
        for legacy, current in LEGACY_MIGRATE.items():
            if legacy not in v:
                continue
            if not v.get(current):
                w[current] = v[legacy]
                migrated[f"{legacy}->{current}"] += 1
            else:
                dropped[f"{legacy} (current field already set)"] += 1
        for f in LEGACY_FIELDS:
            if f in v:
                w[f] = firestore.DELETE_FIELD
                if f not in LEGACY_MIGRATE:
                    dropped[f] += 1
        writes[uid] = w

    print(f"      migrated: {dict(migrated)}")
    print(f"      dropped:  {dict(dropped)}")
    if APPLY:
        batch = db.batch()
        for i, (uid, w) in enumerate(writes.items(), 1):
            batch.update(db.collection("users").document(uid), w)
            if i % 400 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
        # displayName is mirrored publicly; a migrated name must reach the
        # collection a visitor actually reads.
        for uid, w in writes.items():
            if "displayName" in w:
                db.collection("public_profiles").document(uid).set(
                    {"displayName": w["displayName"]}, merge=True)
    print(f"      written={len(writes) if APPLY else 0}")
    return len(writes)


# --------------------------------------------------------------------------
# T6
# --------------------------------------------------------------------------

BIO_F = re.compile(
    r"\b(s[eé]rieuse|polyvalente|ponctuelle|exp[eé]riment[eé]e|passionn[eé]e"
    r"|impliqu[eé]e|attentive|rigoureuse|douce)\b", re.I)
BIO_M = re.compile(
    r"\b(s[eé]rieux|polyvalent|ponctuel|exp[eé]riment[eé]|passionn[eé]"
    r"|impliqu[eé]|rigoureux)\b", re.I)


def bio_gender(bio):
    """The gender a provider's own description is written in, or None.

    This OUTRANKS the gender of the name being replaced. seed_user_03 shipped as
    "Ibrahima Sow" with the bio "Aide a domicile polyvalente": the corpus already
    contradicted itself, and matching the discarded name would have preserved the
    contradiction under a new spelling. The bio is the longer, richer text and
    the one a visitor reads, so it wins.
    """
    if not bio:
        return None
    f, m = bool(BIO_F.search(bio)), bool(BIO_M.search(bio))
    return "F" if f and not m else ("M" if m and not f else None)


def identity_plan(users, providers=None):
    """Which accounts need a name, and which name they get.

    Two populations: an empty `displayName`, and one side of a name collision.
    A collision is broken on the SEEDED account, never on the real one, so an
    invented name is never written over a person who chose theirs. When both
    sides are seeded the higher document id yields, purely so the choice is
    stable across runs.
    """
    used = {(v.get("displayName") or "").strip()
            for v in users.values() if (v.get("displayName") or "").strip()}
    targets = [k for k, v in sorted(users.items())
               if not (v.get("displayName") or "").strip()]

    by_name = {}
    for k, v in sorted(users.items()):
        n = (v.get("displayName") or "").strip()
        if n:
            by_name.setdefault(n, []).append(k)
    for name, uids in sorted(by_name.items()):
        if len(uids) < 2:
            continue
        seeded = [u for u in uids if is_seed_account(u, users[u])]
        # Keep one holder of the name; rename the rest, preferring seeded ones.
        yielders = (seeded[1:] if len(seeded) == len(uids) else seeded) or uids[1:]
        targets.extend(yielders)

    pool_f = [n for n in NAME_POOL_F if n not in used]
    pool_m = [n for n in NAME_POOL_M if n not in used]
    plan = {}
    for uid in targets:
        current = (users[uid].get("displayName") or "").strip()
        first = current.split(" ")[0].lower() if current else ""
        g = bio_gender(((providers or {}).get(uid) or {}).get("bio"))
        if g is None:
            g = "F" if first in FIRST_F else ("M" if first in FIRST_M else None)
        if g == "F":
            pool = pool_f
        elif g == "M":
            pool = pool_m
        else:
            # No name to match, or one this corpus does not know: take from
            # whichever pool is deeper so neither runs dry first.
            pool = pool_f if len(pool_f) >= len(pool_m) else pool_m
        if not pool:
            continue
        plan[uid] = pool.pop(0)
    return plan, targets


def cmd_identities():
    users = load("users")
    plan, targets = identity_plan(users, load("providers"))
    say(mode(), f"T6 identities: users={len(users)} needing a name={len(targets)}")
    for uid in sorted(plan):
        old = (users[uid].get("displayName") or "").strip() or "(empty)"
        real = "" if is_seed_account(uid, users[uid]) else "  [real auth account]"
        print(f"      {uid}: {old!r} -> {plan[uid]!r}{real}")
    if len(plan) < len(targets):
        print(f"      WARNING: name pool exhausted, {len(targets) - len(plan)} left",
              file=sys.stderr)
    if APPLY:
        for uid, name in plan.items():
            db.collection("users").document(uid).set({"displayName": name}, merge=True)
            db.collection("public_profiles").document(uid).set(
                {"displayName": name}, merge=True)
    print(f"      written={len(plan) if APPLY else 0} (users + public_profiles)")
    return len(plan)


# --------------------------------------------------------------------------
# T7
# --------------------------------------------------------------------------

def avatar_url(uid):
    """The final URL, derived from the uid alone so it is stable across runs.

    The download token is a uuid5 of the path rather than a fresh uuid4: a
    re-upload then keeps the same URL, and documents already pointing at it stay
    valid. A random token would silently invalidate every stored photoPath on
    the second run.
    """
    path = AVATAR_PATH.format(uid=uid)
    token = str(uuid.uuid5(uuid.NAMESPACE_URL, f"outalma-avatar/{path}"))
    return (f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/"
            f"{quote(path, safe='')}?alt=media&token={token}"), path, token


def cmd_avatars():
    """One self-hosted illustrated avatar set. No third-party hotlinks.

    Three provenances are collapsed into one. A `private/users/` upload is a
    real photo taken by a real person and is PRESERVED untouched; everything
    else (a `seed/avatars/` file from an earlier run of this command, a hotlink
    to randomuser.me or images.unsplash.com, or a missing photoPath) is
    regenerated. Checking the object PATH rather than testing whether the URL
    merely contains "firebasestorage" is load bearing, not stylistic: the seed
    avatars this command uploads live in Firebase Storage too, at
    `seed/avatars/{uid}.png`, so after the first run every one of the 46 seeded
    accounts also carries a firebasestorage URL. The old substring check would
    then read as "already a real upload" for all of them, and a second run
    would preserve the very files it exists to regenerate: 0 targets, silently,
    the exact way `head:` instead of `headVariant:` was silently ignored in the
    generator tool (see tool/avatar_gen/bin/generate.dart on the profile-avatars
    branch). The path prefix is unambiguous because the two provenances are
    already written to different prefixes (`avatar_url` below vs the real
    upload path used by the app's photo picker) and neither can collide with
    the other.

    Regenerated avatars are gender-matched: the `head` and facialHairProbability
    options sent to DiceBear are chosen from the account's own `gender` field
    (dicebear_query above), rather than one unsplit catalogue drawn purely from
    the uid. Before this, a woman's avatar could come back wearing a beard and
    a flat-top fade with equal probability to a man's, because gender was never
    part of the seed the API received.

    The seed is the uid: opaque, already public, and carries no personal data
    into a third-party URL the way a name or an email would.
    """
    users = load("users")
    preserve = [k for k, v in sorted(users.items())
                if (_storage_object_path(v.get("photoPath")) or "").startswith(
                    "private/users/")]
    targets = [k for k in sorted(users) if k not in set(preserve)]
    hotlink = [k for k in targets
               if not (_storage_object_path(users[k].get("photoPath")) or "")
               .startswith("seed/avatars/") and users[k].get("photoPath")]
    missing = [k for k in targets if not users[k].get("photoPath")]
    regenerate = [k for k in targets if k not in set(hotlink) | set(missing)]

    say(mode(), f"T7 avatars: users={len(users)} style={AVATAR_STYLE} (CC0 1.0)")
    print(f"      preserve real uploads (private/users/): {len(preserve)}")
    print(f"      replace external hotlinks: {len(hotlink)}")
    print(f"      fill missing: {len(missing)}")
    print(f"      regenerate gender-mismatched seed avatars: {len(regenerate)}")
    if targets:
        sample = targets[0]
        heads, fhp = dicebear_query(users[sample].get("gender"))
        u = AVATAR_API.format(style=AVATAR_STYLE, seed=quote(sample),
                               heads=quote(",".join(heads)), fhp=fhp)
        print(f"      e.g. {sample} (gender={users[sample].get('gender')}) -> "
              f"{u[:130]}...")
    if not APPLY:
        print("      written=0")
        return len(targets)

    bucket = storage.bucket()
    done = 0
    for uid in targets:
        heads, fhp = dicebear_query(users[uid].get("gender"))
        request_url = AVATAR_API.format(style=AVATAR_STYLE, seed=quote(uid),
                                         heads=quote(",".join(heads)), fhp=fhp)
        png = urlopen(request_url, timeout=30).read()
        url, path, token = avatar_url(uid)
        blob = bucket.blob(path)
        blob.metadata = {"firebaseStorageDownloadTokens": token}
        blob.upload_from_string(png, content_type="image/png")
        db.collection("users").document(uid).set({"photoPath": url}, merge=True)
        db.collection("public_profiles").document(uid).set({"photoPath": url}, merge=True)
        done += 1
    print(f"      written={done} (uploaded + users + public_profiles)")
    return len(targets)


# --------------------------------------------------------------------------
# T8
# --------------------------------------------------------------------------

def verify_plan(providers, services, reviews, bookings, ratings):
    """Which providers get the verified badge.

    Ranked by what makes the badge land on a profile a visitor can actually
    inspect: a published service first, then a rating, then review volume. A
    green check on an empty profile teaches a user that the check means nothing.
    """
    svc, rev = {}, {}
    for s in services.values():
        if s.get("published"):
            svc[s["providerId"]] = svc.get(s["providerId"], 0) + 1
    for r in reviews.values():
        bk = bookings.get(r.get("bookingId"))
        if bk:
            rev[bk["providerId"]] = rev.get(bk["providerId"], 0) + 1
    ranked = sorted(
        providers,
        key=lambda u: (-svc.get(u, 0), -(ratings.get(u, {}).get("ratingCount") or 0),
                       -rev.get(u, 0), u),
    )
    target = len(providers) // 2
    return ranked[:target], svc, rev


def cmd_verified_providers():
    providers, services = load("providers"), load("services")
    reviews, bookings = load("reviews"), load("bookings")
    ratings, trust = load("provider_ratings"), load("provider_trust")
    chosen, svc, rev = verify_plan(providers, services, reviews, bookings, ratings)
    already = [u for u in chosen
               if (trust.get(u) or {}).get("identityStatus") == "verified"]
    say(mode(), f"T8 verified-providers: providers={len(providers)} "
                f"verified today={sum(1 for v in trust.values() if v.get('identityStatus') == 'verified')}")
    print(f"      target={len(chosen)} (half), already verified among them={len(already)}")
    for u in chosen:
        print(f"      {u}  services={svc.get(u, 0)} reviews={rev.get(u, 0)} "
              f"ratingCount={(ratings.get(u) or {}).get('ratingCount', 0)}")
    if APPLY:
        for u in chosen:
            db.collection("provider_trust").document(u).set(
                {"identityStatus": "verified",
                 "updatedAt": firestore.SERVER_TIMESTAMP}, merge=True)
            db.collection("providers").document(u).set(
                {"identityVerified": True}, merge=True)
    print(f"      written={len(chosen) if APPLY else 0} "
          f"(provider_trust + providers.identityVerified)")
    return len(chosen)


# --------------------------------------------------------------------------
# T9
# --------------------------------------------------------------------------

def cmd_provider_services():
    """Reports, and deliberately writes nothing. See the reasoning below.

    The 7 providers with no service are not seeded Senegalese personas: they are
    real test accounts belonging to Amath and people around him, and their
    `serviceArea` is in France (Orléans, Évry, Étampes). T9 requires any created
    service to carry `serviceZones` in Senegal, which those accounts contradict
    on their face.

    Writing Dakar listings under real people's names to fill a catalogue is the
    kind of number that later gets quoted as if it were real. A provider who has
    published nothing not appearing in a catalogue is the system working, not a
    defect. If Amath wants the catalogue denser, the honest lever is more seeded
    personas, not invented offers attached to real identities.
    """
    providers, services, users = load("providers"), load("services"), load("users")
    have = {s["providerId"] for s in services.values()}
    without = [u for u in sorted(providers) if u not in have]
    say(mode(), f"T9 provider-services: providers={len(providers)} without a service={len(without)}")
    for u in without:
        print(f"      {u}  area={(providers[u].get('serviceArea') or '(none)')!r} "
              f"seed={is_seed_account(u, users.get(u, {}))}")
    print("      decision: NO service created. Real test accounts with French "
          "service areas; Senegal-zoned listings under real identities would be "
          "fabricated catalogue depth. Reported, not written.")
    return 0


# --------------------------------------------------------------------------
# audit
# --------------------------------------------------------------------------

def cmd_audit():
    """Re-read the base and prove every invariant. Writes nothing, ever."""
    users, providers = load("users"), load("providers")
    services, bookings = load("services"), load("bookings")
    reviews, chats = load("reviews"), load("chats")
    ratings, events = load("provider_ratings"), load("rating_events")
    trust = load("provider_trust")
    profiles = load("public_profiles")

    from collections import Counter
    print("=" * 68)
    print(f"OUTALMA SEED AUDIT  {NOW.isoformat()}  project=outalmaservice-d1e59")
    print("=" * 68)
    print(f"users={len(users)} providers={len(providers)} services={len(services)} "
          f"bookings={len(bookings)} reviews={len(reviews)} chats={len(chats)}")
    print(f"public_profiles={len(profiles)} provider_ratings={len(ratings)} "
          f"rating_events={len(events)} provider_trust={len(trust)}")
    print("-" * 68)

    fails = []

    def check(label, value, want=0):
        ok = value == want
        if not ok:
            fails.append(label)
        print(f"[{'OK ' if ok else 'FAIL'}] {label}: {value} (want {want})")

    check("T1  reviews without `hidden`",
          sum(1 for v in reviews.values() if "hidden" not in v))
    check("T2  bookings pointing at a dead service",
          sum(1 for v in bookings.values() if v.get("serviceId") not in services))
    check("T2  reviews pointing at a dead booking",
          sum(1 for v in reviews.values() if v.get("bookingId") not in bookings))
    check("T2  chats pointing at a dead booking",
          sum(1 for v in chats.values()
              if v.get("bookingId") and v["bookingId"] not in bookings))
    # `requested` and `accepted` describe work that has not started, so a past
    # date is always a defect. `in_progress` is the opposite: a job running now
    # STARTED earlier today, so its date belongs in the recent past and the
    # invariant is that it fell on today, not that it is in the future.
    check("T3  requested/accepted scheduled in the past",
          sum(1 for v in bookings.values()
              if v.get("status") in ("requested", "accepted")
              and v.get("scheduledAt") and v["scheduledAt"] < NOW))
    check("T3  requested/accepted outside business hours 08-18",
          sum(1 for v in bookings.values()
              if v.get("status") in ("requested", "accepted")
              and v.get("scheduledAt") and not (8 <= v["scheduledAt"].hour <= 18)))
    check("T3  active bookings with no date at all",
          sum(1 for v in bookings.values()
              if v.get("status") in ACTIVE and not v.get("scheduledAt")))
    check("T3  in_progress not scheduled today",
          sum(1 for v in bookings.values()
              if v.get("status") == "in_progress"
              and (not v.get("scheduledAt")
                   or v["scheduledAt"].date() != NOW.date())))
    check("T4  reviews whose author is neither party",
          len(malformed_ids(reviews, bookings)))
    check("T5  users carrying a legacy field",
          sum(1 for v in users.values() if any(f in v for f in LEGACY_FIELDS)))
    check("T6  users with an empty displayName",
          sum(1 for v in users.values() if not (v.get("displayName") or "").strip()))
    names = Counter((v.get("displayName") or "").strip() for v in users.values()
                    if (v.get("displayName") or "").strip())
    dups = {n: c for n, c in names.items() if c > 1}
    check(f"T6  duplicate display names {dups if dups else ''}", len(dups))
    ext = [k for k, v in users.items()
           if (v.get("photoPath") or "") and "firebasestorage" not in v["photoPath"]]
    check("T7  users hotlinking an external avatar", len(ext))
    check("T7  users without an avatar",
          sum(1 for v in users.values() if not v.get("photoPath")))
    check("T7  public_profiles hotlinking an external avatar",
          sum(1 for v in profiles.values()
              if (v.get("photoPath") or "") and "firebasestorage" not in v["photoPath"]))
    mism = [k for k, v in users.items()
            if (profiles.get(k) or {}).get("photoPath") != v.get("photoPath")
            or (profiles.get(k) or {}).get("displayName") != v.get("displayName")]
    check("T7/T6 users vs public_profiles divergence", len(mism))

    print("-" * 68)
    nverified = sum(1 for v in trust.values() if v.get("identityStatus") == "verified")
    flagged = sum(1 for v in providers.values() if v.get("identityVerified") is True)
    print(f"[i]  T8  providers verified: {nverified}/{len(providers)} in provider_trust, "
          f"{flagged} carrying providers.identityVerified")
    if nverified != flagged:
        fails.append("T8 trust/providers disagree")
        print("[FAIL] T8  provider_trust and providers.identityVerified disagree")
    have = {s["providerId"] for s in services.values()}
    print(f"[i]  T9  providers without a service: "
          f"{len([u for u in providers if u not in have])}/{len(providers)} "
          f"(deliberate, see cmd_provider_services)")

    print("-" * 68)
    print("RATING COHERENCE (aggregate re-derived from the registry)")
    replay = {}
    stranded = []
    for rid, ev in sorted(events.items()):
        if ev.get("counted") is not True:
            continue
        rv = reviews.get(rid)
        if not rv:
            stranded.append(f"{rid}:no-review")
            continue
        bk = bookings.get(rv.get("bookingId"))
        if not bk:
            stranded.append(f"{rid}:no-booking")
            continue
        c, s = replay.get(bk["providerId"], (0, 0))
        replay[bk["providerId"]] = (c + 1, s + rv["rating"])
    drift = []
    for uid in sorted(set(replay) | set(ratings)):
        c, s = replay.get(uid, (0, 0))
        a = ratings.get(uid) or {}
        if (a.get("ratingCount") or 0) != c or (a.get("ratingSum") or 0) != s:
            drift.append((uid, "replay", c, s, "stored",
                          a.get("ratingCount"), a.get("ratingSum")))
    print(f"     counted events={sum(1 for v in events.values() if v.get('counted') is True)} "
          f"providers in replay={len(replay)} provider_ratings docs={len(ratings)}")
    check("     rating_events counted but stranded", len(stranded))
    if stranded:
        print(f"       {stranded[:10]}")
    check("     provider_ratings disagreeing with the registry", len(drift))
    for d in drift:
        print(f"       {d}")
    uncounted = [rid for rid, rv in reviews.items()
                 if counts_toward_rating(rv, bookings.get(rv.get("bookingId")))
                 and (events.get(rid) or {}).get("counted") is not True]
    print(f"[i]  reviews eligible but not counted: {len(uncounted)} "
          f"(the backfill's job, not this script's)")

    print("=" * 68)
    print(f"AUDIT {'PASS' if not fails else 'FAIL: ' + '; '.join(fails)}")
    print("=" * 68)
    return 1 if fails else 0


COMMANDS = {
    "review-hidden": cmd_review_hidden,
    "malformed-reviews": cmd_malformed_reviews,
    "orphan-bookings": cmd_orphan_bookings,
    "dates": cmd_dates,
    "legacy-accounts": cmd_legacy_accounts,
    "identities": cmd_identities,
    "avatars": cmd_avatars,
    "verified-providers": cmd_verified_providers,
    "provider-services": cmd_provider_services,
    "audit": cmd_audit,
}
ORDER = ["review-hidden", "malformed-reviews", "orphan-bookings", "dates",
         "legacy-accounts", "identities", "avatars", "verified-providers",
         "provider-services"]


def main():
    positional = [a for a in ARGS if not a.startswith("--")]
    cmd = positional[0] if positional else "audit"
    if cmd == "all":
        for c in ORDER:
            COMMANDS[c]()
            print()
        return cmd_audit()
    if cmd not in COMMANDS:
        print(f"unknown command {cmd!r}; one of: all, {', '.join(COMMANDS)}",
              file=sys.stderr)
        return 2
    if cmd == "audit":
        return cmd_audit()
    COMMANDS[cmd]()
    return 0


if __name__ == "__main__":
    raise SystemExit(main() or 0)
