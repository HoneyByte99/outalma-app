#!/usr/bin/env python3
"""
Fill the `gender` field of the SEEDED `users` corpus, deriving it from the
first name.

Why this exists: `gender` is collected at sign-up from now on, on both paths,
and is drawn as a pictogram on the catalogue card and on the service detail.
Every account that already exists predates the field, so the whole seeded
catalogue would render without a single pictogram, and the feature could not be
seen at all on the corpus the testers actually browse.

This is therefore a BACKFILL of demo data, not a migration of user
declarations. The distinction is load bearing:

  - The declared value always wins. A document that already carries a VALID
    gender is never touched, whatever this script would have derived. That
    keeps it idempotent and keeps it from overwriting a real person.
  - Derivation is by FIRST NAME, from an explicit table, never by guessing.
    A name absent from the table, or listed as ambiguous, is REPORTED and left
    alone. The corpus is small enough to state name by name, and a wrong
    pictogram beside a person's name is worse than no pictogram.
  - `cniSexe`, extracted from an identity document by identity_extraction.ts,
    is NOT read here and must never feed this field. The two answer different
    questions.

The table below is the one validated in ~/clawd/tmp/outalma-gender/seeds-genres.md.
Anything not in it lands in the UNRESOLVED report at the end of the run.

ORDERING CONSTRAINT, and it costs a re-run if broken. `mirrorPublicProfile`
projects `users` into the world-readable `public_profiles`, and the pictogram is
read from THAT collection. The deployed version of the trigger must already know
about `gender` before this script writes, otherwise `projectionsEqual` sees no
difference, skips the write, and the catalogue stays blank while `users` looks
correct. So: deploy functions FIRST, then run this with --apply. If the order
was missed, call the `backfillPublicProfiles` admin callable afterwards to
re-project the whole collection.

Privacy: prints FIRST NAMES, counts and derived values. Never a full name, never
a document id, never an email, never a phone number. The report is meant to be
read and validated by a human, and a first name detached from any identifier is
not one.

Idempotent: a second run reports 0 documents to change. Deterministic: the
output is a pure function of the input corpus and of the table below.

DRY RUN BY DEFAULT. Nothing is written without --apply, and --apply dumps the
`displayName` + `gender` of every document to a timestamped JSON file before the
first write.

Credentials are resolved (in order): --sa=<path>,
$GOOGLE_APPLICATION_CREDENTIALS, then a repo-local scripts/service-account.json.

Usage:
  python3 scripts/backfill-user-gender.py                  # dry run
  python3 scripts/backfill-user-gender.py --apply
  python3 scripts/backfill-user-gender.py --apply --backup-dir=/tmp/gender
"""

import json
import os
import sys
import unicodedata
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

ARGS = sys.argv[1:]
APPLY = "--apply" in ARGS

COLLECTION = "users"
FIELD = "gender"
# The vocabulary, identical to the Dart enum (lib/src/domain/enums/gender.dart),
# to the TypeScript GENDERS (functions/src/public_profiles.ts) and to the
# firestore.rules guard. Four places, one spelling.
VALID = ("male", "female")

# ---------------------------------------------------------------------------
# Derivation table
# ---------------------------------------------------------------------------
#
# Keyed by the accent-folded, lower-cased FIRST token of `displayName`.
# Confidence is stated per name and travels into the report:
#
#   high    the name is unambiguously gendered in Senegalese usage
#   medium  gendered in this corpus and in common usage, but the name exists
#           elsewhere for the other gender, or is a spelling variant
#
# A name that is genuinely used for both is NOT in this table. It belongs in
# AMBIGUOUS below, is never derived, and is reported for a human to settle.

MALE_HIGH = [
    "abdou", "abdoulaye", "alioune", "amath", "assane", "babacar", "bassirou",
    "cheikh", "cheikhou", "elhadji", "ibrahima", "idrissa", "insa", "lamine",
    "malick", "mamadou", "modou", "mohamed", "mouhamed", "mouhamadou",
    "moussa", "ousmane", "oumar", "papa", "pape", "saliou", "samba",
    "serigne", "seydou", "sidy", "souleymane", "tapha", "thierno", "youssou",
    # "doudou": not a derivation, an explicit owner ruling (2026-09-02). The
    # name is genuinely ambiguous (masculine Senegalese diminutive of
    # Mamadou/Ahmadou, but also a genderless French term of endearment); the
    # owner settled the one live account by hand rather than the table
    # guessing.
    "doudou",
]
MALE_MEDIUM = [
    # French / European given names present in the corpus. Unambiguous as
    # names, flagged medium only because they are not Senegalese usage and a
    # seeded persona could have been meant otherwise.
    "thomas", "pierre", "jean", "paul", "marc", "nicolas", "julien",
    # Arabic spellings that also travel as surnames in Senegal.
    "ahmed", "ahmadou", "abdoul", "omar",
]

FEMALE_HIGH = [
    "aicha", "aissatou", "aminata", "astou", "awa", "bineta", "bintou",
    "coumba", "dieynaba", "fatim", "fatima", "fatou", "fatoumata", "khadija",
    "khady", "mame", "mariama", "marieme", "mbene", "ndeye", "nogaye",
    "penda", "rokhaya", "safietou", "seynabou", "sokhna", "soukeyna",
]
FEMALE_MEDIUM = [
    "aby", "diouly", "maimouna", "oumou", "ramatoulaye", "yaye",
    # French / European given names present in the corpus.
    "marie", "sophie", "claire", "isabelle", "camille",
]

# Names genuinely used for BOTH in Senegal, or whose usage the corpus itself
# contradicts. NEVER derived, always reported. Each entry says why, because the
# reason is what lets a human settle it in one reading.
AMBIGUOUS = {
    "adama": "used for both in Senegal (male in Mali and Burkina, female here "
             "as often as not)",
    "yacine": "female in Senegal, male (Yassine) across the Maghreb",
    "ousseynou": "male, but paired with Assane/Adja in twin naming, check the "
                 "persona before deriving",
    "khadim": "male, occasionally given to girls in Mouride families",
    "dominique": "used for both in French",
    "claude": "used for both in French",
}

TABLE = {}
for _n in MALE_HIGH:
    TABLE[_n] = ("male", "high")
for _n in MALE_MEDIUM:
    TABLE[_n] = ("male", "medium")
for _n in FEMALE_HIGH:
    TABLE[_n] = ("female", "high")
for _n in FEMALE_MEDIUM:
    TABLE[_n] = ("female", "medium")


def _arg(name, default=None):
    for a in ARGS:
        if a.startswith(f"--{name}="):
            return a.split("=", 1)[1]
    return default


def _script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def _service_account_path():
    return (
        _arg("sa")
        or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        or os.path.join(_script_dir(), "service-account.json")
    )


def fold(text):
    """Lower-case and strip accents, so 'Ndeye' and 'Ndeye' key the same entry.

    The corpus carries both spellings of the same names: the seeds were written
    with accents, the FlutterFlow export without.
    """
    decomposed = unicodedata.normalize("NFD", text)
    stripped = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
    return stripped.strip().lower()


def first_name(display_name):
    """The first token of a display name, folded. Empty string when there is none."""
    if not isinstance(display_name, str):
        return ""
    parts = [p for p in display_name.replace("-", " ").split() if p]
    return fold(parts[0]) if parts else ""


def derive(display_name):
    """Return (gender, confidence, note) for one display name.

    `gender` is None whenever the script refuses to decide, and `note` then says
    why. Refusing is a normal outcome here, not an error.
    """
    name = first_name(display_name)
    if not name:
        return None, None, "no first name on the document"
    if name in AMBIGUOUS:
        return None, None, f"ambiguous: {AMBIGUOUS[name]}"
    if name in TABLE:
        gender, confidence = TABLE[name]
        return gender, confidence, None
    return None, None, "not in the derivation table"


def write_backup(rows, backup_dir):
    """Dump displayName + current gender per document id, before any write."""
    os.makedirs(backup_dir, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
    path = os.path.join(backup_dir, f"users-gender-backup-{stamp}.json")
    payload = {
        doc_id: {"displayName": display, FIELD: current}
        for doc_id, display, current, _ in rows
    }
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2, default=str)
    return path


def main():
    cred = credentials.Certificate(_service_account_path())
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    mode = "APPLY (writes)" if APPLY else "DRY RUN (writes nothing)"
    print("=" * 72)
    print(f"backfill-user-gender  {mode}")
    print("=" * 72)

    # (doc_id, displayName, current gender, derivation)
    rows = []
    for snap in db.collection(COLLECTION).stream():
        data = snap.to_dict() or {}
        display = data.get("displayName") or ""
        current = data.get(FIELD)
        rows.append((snap.id, display, current, derive(display)))

    already = [r for r in rows if r[2] in VALID]
    # A value present but outside the vocabulary: the 2024 FlutterFlow export
    # used this exact key with another one. Reported, never silently rewritten.
    foreign = [r for r in rows if r[2] is not None and r[2] not in VALID]
    candidates = [r for r in rows if r[2] is None]

    to_write = [r for r in candidates if r[3][0] is not None]
    unresolved = [r for r in candidates if r[3][0] is None]

    print(f"documents in `{COLLECTION}`                      : {len(rows)}")
    print(f"already carrying a valid `{FIELD}` (untouched)  : {len(already)}")
    print(f"carrying a value outside the vocabulary       : {len(foreign)}")
    print(f"derivable, would be written                   : {len(to_write)}")
    print(f"NOT derivable, left alone                     : {len(unresolved)}")
    print()

    # Aggregated by first name. No document ids, no full names: the point of
    # this listing is for a human to validate the DERIVATION, and the derivation
    # only ever looked at the first name.
    by_name = {}
    for _, display, _, (gender, confidence, _note) in to_write:
        key = (first_name(display), gender, confidence)
        by_name[key] = by_name.get(key, 0) + 1

    if by_name:
        print("  derived, first name -> gender (confidence) x count :")
        for (name, gender, confidence), count in sorted(by_name.items()):
            print(f"      {name:<14} -> {gender:<7} ({confidence}) x{count}")

    if unresolved:
        by_reason = {}
        for _, display, _, (_g, _c, note) in unresolved:
            by_reason.setdefault(note, []).append(first_name(display) or "(none)")
        print()
        print(f"  UNRESOLVED, nothing written ({len(unresolved)}) :")
        for note, names in sorted(by_reason.items()):
            print(f"      {note}")
            for name in sorted(set(names)):
                print(f"        - {name}")

    if foreign:
        print()
        print(f"  FOREIGN VALUES, nothing written ({len(foreign)}) :")
        for _, display, current, _ in foreign:
            print(f"      {first_name(display) or '(none)'}: {current!r}")

    if not to_write:
        print()
        print("Nothing to change. Every derivable document already has a value.")
        return 0

    if not APPLY:
        print()
        print(f"DRY RUN: {len(to_write)} document(s) would be written. "
              "Re-run with --apply to write.")
        return 0

    backup_dir = _arg("backup-dir") or os.path.join(_script_dir(), "backups")
    path = write_backup(rows, backup_dir)
    print()
    print(f"backup written: {path}")

    written = 0
    col = db.collection(COLLECTION)
    for doc_id, display, _, (gender, _c, _n) in to_write:
        # update(), not set(merge): the document must already exist, and a
        # single-field update cannot resurrect a deleted account.
        col.document(doc_id).update({FIELD: gender})
        written += 1
        print(f"  WROTE {first_name(display)} -> {gender}")

    print()
    print(f"done: {written} document(s) written, "
          f"{len(rows) - written} left untouched.")
    print("Reminder: the pictogram reads `public_profiles`, not `users`. If the "
          "deployed mirrorPublicProfile predates this field, call "
          "backfillPublicProfiles now.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
