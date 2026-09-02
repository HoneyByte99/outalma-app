#!/usr/bin/env python3
"""
Runs the Python provider-rating predicate over the shared table of cases.

Three modes, all stdlib only so this works with no service account and no
firebase_admin installed:

  python3 scripts/rating_parity_runner.py            emit the verdicts as JSON
  python3 scripts/rating_parity_runner.py --check    assert them against the
                                                     table, exit 1 on any drift
  python3 scripts/rating_parity_runner.py --check-registry
                                                     assert the registry
                                                     decision and the backfill
                                                     classifier, exit 1 on drift

The JSON mode is what functions/test/rating_parity.test.ts consumes: it runs
the TypeScript predicate over the SAME table and compares case by case, so a
divergence between the two implementations fails a test instead of silently
making the aggregate disagree with what a replay computes.

The table is shared/rating-parity-cases.json and is the only place cases are
declared. Pass a different path as the last argument to point elsewhere.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rating_predicate import classify_review, counts, is_counted, usable  # noqa: E402

# The registry decision, `is_counted`, gets its own small table rather than a
# column in the shared one: it takes a rating_events document, not a review and
# a booking, so it does not fit that schema.
#
# It lives here in the runner instead of in JSON because its TypeScript
# counterpart is not an exported function (it is one line inside
# ratingDeltaWithin), so there is nothing to run the same JSON through. The
# server side of the same decision is pinned behaviourally against the emulator
# in functions/test/provider_rating.test.ts.
REGISTRY_CASES = [
    ("document absent", None, False),
    ("empty document", {}, False),
    ("counted true", {"counted": True}, True),
    ("counted false", {"counted": False}, False),
    ("counted absent from an existing document", {"updatedAt": 1}, False),
    # Everything below is malformed: none of these is a state this system
    # writes. The point of each is that it must NOT read as counted. Treating a
    # malformed entry as counted would suppress a legitimate count for ever,
    # and no re-run could repair it. The TypeScript uses `=== true`.
    ("counted as the number 1", {"counted": 1}, False),
    ("counted as the string true", {"counted": "true"}, False),
    ("counted as the string yes", {"counted": "yes"}, False),
    ("counted as null", {"counted": None}, False),
]

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CASES = os.path.join(REPO_ROOT, "shared", "rating-parity-cases.json")


def cases_path():
    for arg in sys.argv[1:]:
        if not arg.startswith("--"):
            return arg
    return DEFAULT_CASES


def verdicts(cases):
    """One verdict per case, in the table's order.

    `counts` is the predicate. `rating` is the normalised value the aggregate
    would move by, or None. Both matter: agreeing on "this counts" while
    disagreeing on the number would still corrupt the sum.
    """
    out = []
    for case in cases:
        review = case.get("review") or {}
        booking = case.get("booking")
        out.append(
            {
                "name": case["name"],
                "counts": counts(review, booking),
                "rating": usable(review.get("rating")),
            }
        )
    return out


# The backfill's own verdict, one review at a time. `_B` is a booking whose
# customer authored the review, so these cases isolate the registry dimension
# from the authorship dimension already covered by the shared table.
_B = {"customerId": "cust", "providerId": "prov"}
_R = {"reviewerId": "cust", "rating": 4}

CLASSIFY_CASES = [
    # (name, review, booking, registry, expected verdict)
    ("counts on a clean review, empty registry", _R, _B, None, "to_count"),
    ("counts when the registry says not counted", _R, _B, {"counted": False}, "to_count"),
    # THE case the broken dry run got wrong. It reported this as work to do,
    # which is what made "already_counted=0" look like "the backfill has never
    # run" on a database where it had.
    ("already counted is NOT work to do", _R, _B, {"counted": True}, "already_counted"),
    ("a rating out of scale is unusable", {"reviewerId": "cust", "rating": 6}, _B, None, "unusable_rating"),
    ("a null rating is unusable", {"reviewerId": "cust", "rating": None}, _B, None, "unusable_rating"),
    ("a missing booking is reported as such", _R, None, None, "booking_missing"),
    ("a moderated review is skipped", dict(_R, hidden=True), _B, None, "hidden"),
    ("a provider-authored review does not count", {"reviewerId": "prov", "rating": 4}, _B, None, "not_by_customer"),
    # Ordering: an unusable rating is reported BEFORE the registry is even
    # consulted, which is why main() may skip the read for those.
    (
        "an unusable rating wins over an already-counted registry",
        {"reviewerId": "cust", "rating": 0},
        _B,
        {"counted": True},
        "unusable_rating",
    ),
]


def check_classify():
    """Asserts classify_review over CLASSIFY_CASES. Returns an exit code."""
    drift = []
    for name, review, booking, registry, want in CLASSIFY_CASES:
        got = classify_review(review, booking, registry)
        if got != want:
            drift.append(f"  {name}: expected {want}, got {got}")

    if drift:
        print(f"BACKFILL CLASSIFIER DRIFTED on {len(drift)}/{len(CLASSIFY_CASES)} case(s):")
        print("\n".join(drift))
        return 1

    print(f"backfill classifier matches all {len(CLASSIFY_CASES)} cases")
    return 0


def check_registry():
    """Asserts is_counted over REGISTRY_CASES. Returns an exit code."""
    drift = []
    for name, data, want in REGISTRY_CASES:
        got = is_counted(data)
        if got != want:
            drift.append(f"  {name}: expected {want}, got {got}")

    if drift:
        print(f"REGISTRY PREDICATE DRIFTED on {len(drift)}/{len(REGISTRY_CASES)} case(s):")
        print("\n".join(drift))
        return 1

    print(f"registry predicate matches all {len(REGISTRY_CASES)} cases")
    return 0


def main():
    if "--check-registry" in sys.argv[1:]:
        return check_registry() or check_classify()

    path = cases_path()
    with open(path, encoding="utf-8") as fh:
        cases = json.load(fh)["cases"]

    results = verdicts(cases)

    if "--check" not in sys.argv[1:]:
        json.dump(results, sys.stdout)
        return 0

    drift = []
    for case, got in zip(cases, results):
        want = case["expected"]
        if got["counts"] != want["counts"] or got["rating"] != want["rating"]:
            drift.append(
                f"  {case['name']}\n"
                f"    expected counts={want['counts']} rating={want['rating']}\n"
                f"    python   counts={got['counts']} rating={got['rating']}"
            )

    if drift:
        print(f"PYTHON PREDICATE DRIFTED on {len(drift)}/{len(cases)} case(s):")
        print("\n".join(drift))
        return 1

    print(f"python predicate matches all {len(cases)} shared cases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
