#!/usr/bin/env python3
"""
Runs the Python provider-rating predicate over the shared table of cases.

Two modes, both stdlib only so this works with no service account and no
firebase_admin installed:

  python3 scripts/rating_parity_runner.py            emit the verdicts as JSON
  python3 scripts/rating_parity_runner.py --check    assert them against the
                                                     table, exit 1 on any drift

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
from rating_predicate import counts, usable  # noqa: E402

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


def main():
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
