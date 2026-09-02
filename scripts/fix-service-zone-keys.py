#!/usr/bin/env python3
"""
Rename the drifted `latitude`/`longitude` keys of `services.serviceZones` to the
canonical `lat`/`lng`.

Why this exists: the contract for a zone is `{label, lat, lng, radiusKm}`. It is
the shape `serviceZoneToMap` writes (lib/src/data/firestore/firestore_serialization.dart),
the shape `serviceZoneFromMap` reads, and the shape the `createBooking` callable
reads server-side (functions/src/index.ts, zone coverage check). Three seed
scripts wrote `latitude`/`longitude` instead, and the whole production corpus
carries the drift. Two consequences, both live:

  - every zone parses to (0, 0) in the app, so the distance filter empties the
    catalogue as soon as the client picks a location;
  - `createBooking` finds no zone with numeric `lat`/`lng`, so `inZone` is false
    and any geocoded address on a seeded service is refused with "outside the
    service intervention zones".

So this is a key rename on data that already claims to follow the current model,
not a schema change. Nothing else in the document is read or written: the update
carries the `serviceZones` field alone.

Resolution rules, per zone element:

  - `lat`/`lng` present            -> already canonical, left untouched
  - only `latitude`/`longitude`    -> renamed, value copied verbatim
  - both sets present (mixed)      -> `lat`/`lng` wins, the legacy key is dropped
  - resolved key by key, so a half-migrated zone (`lat` + `longitude`) converges
  - anything else (a zone with neither, a non-map element) -> reported, NOT
    rewritten. A zone with no coordinates at all is a data problem this script
    cannot invent an answer for.

`label`, `radiusKm` and any unknown key are carried through as they are.

Idempotent: a second run reports 0 documents to change. Deterministic: the
output is a pure function of the input document.

DRY RUN BY DEFAULT. Nothing is written without --apply, and --apply dumps every
`serviceZones` field of the collection to a timestamped JSON file before the
first write.

Credentials are resolved (in order): --sa=<path>,
$GOOGLE_APPLICATION_CREDENTIALS, then a repo-local scripts/service-account.json.

Usage:
  python3 scripts/fix-service-zone-keys.py                  # dry run
  python3 scripts/fix-service-zone-keys.py --apply
  python3 scripts/fix-service-zone-keys.py --apply --backup-dir=/tmp/zones
"""

import json
import os
import sys
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

ARGS = sys.argv[1:]
APPLY = "--apply" in ARGS

COLLECTION = "services"
FIELD = "serviceZones"
# (legacy key, canonical key). Order matters only for the report.
RENAMES = (("latitude", "lat"), ("longitude", "lng"))


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


def canonical_zone(zone):
    """Return (new_zone, note) for one zone element.

    `note` is None when nothing changes, otherwise a short human-readable
    reason. `new_zone` is the input object itself when untouched, so the caller
    can compare by value to decide whether the document needs a write.
    """
    if not isinstance(zone, dict):
        return zone, "not a map, left as is"

    out = dict(zone)
    changes = []
    for legacy, canon in RENAMES:
        has_legacy = legacy in out
        has_canon = canon in out
        if has_legacy and has_canon:
            out.pop(legacy)
            changes.append(f"{legacy} dropped ({canon} wins)")
        elif has_legacy:
            out[canon] = out.pop(legacy)
            changes.append(f"{legacy} -> {canon}")

    if not changes:
        if "lat" not in out or "lng" not in out:
            return zone, "no coordinates, left as is"
        return zone, None
    return out, ", ".join(changes)


def zone_label(zone):
    if isinstance(zone, dict):
        return zone.get("label", "(no label)")
    return f"({type(zone).__name__})"


def write_backup(docs, backup_dir):
    """Dump every serviceZones field, keyed by document id, before any write."""
    os.makedirs(backup_dir, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
    path = os.path.join(backup_dir, f"serviceZones-backup-{stamp}.json")
    payload = {doc_id: zones for doc_id, zones, _ in docs}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2, default=str)
    return path


def main():
    cred = credentials.Certificate(_service_account_path())
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    mode = "APPLY (writes)" if APPLY else "DRY RUN (writes nothing)"
    print("=" * 68)
    print(f"fix-service-zone-keys  {mode}")
    print("=" * 68)

    # (doc_id, original_zones, per-zone results) for docs carrying the field.
    docs = []
    skipped_no_field = 0
    for snap in db.collection(COLLECTION).stream():
        zones = (snap.to_dict() or {}).get(FIELD)
        if not isinstance(zones, list):
            skipped_no_field += 1
            continue
        results = [canonical_zone(z) for z in zones]
        docs.append((snap.id, zones, results))

    to_change = []
    anomalies = []
    for doc_id, zones, results in docs:
        new_zones = [z for z, _ in results]
        if new_zones != zones:
            to_change.append((doc_id, zones, new_zones, results))
        for z, note in results:
            if note and "left as is" in note:
                anomalies.append(f"{doc_id}: {zone_label(z)}: {note}")

    total_zones = sum(len(z) for _, z, _ in docs)
    print(f"documents in `{COLLECTION}` with a `{FIELD}` list : {len(docs)}")
    print(f"documents without the field (untouched)           : {skipped_no_field}")
    print(f"zones seen                                        : {total_zones}")
    print(f"documents needing a rewrite                       : {len(to_change)}")
    print()

    for doc_id, _, _, results in to_change:
        print(f"  {doc_id}")
        for z, note in results:
            if note and "left as is" not in note:
                print(f"      {zone_label(z)}: {note}")
                print(f"        -> {json.dumps(z, ensure_ascii=False, default=str)}")

    if anomalies:
        print()
        print(f"  ANOMALIES, not rewritten ({len(anomalies)}) :")
        for a in anomalies:
            print(f"      {a}")

    if not to_change:
        print()
        print("Nothing to change. The corpus is already canonical.")
        return 0

    if not APPLY:
        print()
        print(f"DRY RUN: {len(to_change)} document(s) would be rewritten. "
              "Re-run with --apply to write.")
        return 0

    backup_dir = _arg("backup-dir") or os.path.join(_script_dir(), "backups")
    path = write_backup(docs, backup_dir)
    print()
    print(f"backup written: {path}")

    written = 0
    col = db.collection(COLLECTION)
    for doc_id, _, new_zones, _ in to_change:
        col.document(doc_id).update({FIELD: new_zones})
        written += 1
        print(f"  WROTE {doc_id}")

    print()
    print(f"done: {written} document(s) rewritten, "
          f"{len(docs) - written} left untouched.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
