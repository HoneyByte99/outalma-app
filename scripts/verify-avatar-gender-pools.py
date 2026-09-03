#!/usr/bin/env python3
"""
Guard against re-introducing the two seed-avatar defects fixed on
fix/ui-wave-before-build32 (see ~/clawd/tmp/outalma-wave-ui/report.md):

  - `maskProbability` missing from the DiceBear query (defaults to 5%,
    which is how "Ousmane" ended up wearing a surgical mask).
  - `head` styles split by ENUM NAME instead of by the rendered art:
    `turban`/`cornrows` draw feminine (headwrap, long ponytail) but were
    male-only; `twists`/`bantuKnots` draw a masculine short fade but were
    reachable by female accounts; `noHair1` is a plain bald head with no
    gendered cue and was forced male-only instead of neutral.

Reads `scripts/align-seed-data.py` as text and evaluates only the constant
definitions (AVATAR_API, _HEAD_NEUTRAL, _HEAD_FEMALE, _HEAD_MALE), never
importing the module: importing it talks to Firebase at module load time,
which this check must not require.

Usage: python3 scripts/verify-avatar-gender-pools.py
Exit 0 = all assertions hold, 1 = at least one regressed.
"""
import sys
from pathlib import Path

TARGET = Path(__file__).parent / "align-seed-data.py"


def load_pools(path):
    src = path.read_text()
    start = src.index("AVATAR_STYLE")
    end = src.index("# Facial hair")
    ns = {}
    exec(compile(src[start:end], str(path), "exec"), ns)  # noqa: S102
    return ns["AVATAR_API"], ns["_HEAD_NEUTRAL"], ns["_HEAD_FEMALE"], ns["_HEAD_MALE"]


def main():
    api, neutral, female, male = load_pools(TARGET)
    checks = [
        ("maskProbability=0 present in AVATAR_API", "maskProbability=0" in api),
        ("turban assigned female, not male",
         "turban" in female and "turban" not in male),
        ("cornrows assigned female, not male",
         "cornrows" in female and "cornrows" not in male),
        ("noHair1 neutral, not male-only",
         "noHair1" in neutral and "noHair1" not in (set(male) - set(neutral))),
        ("twists assigned male, not female",
         "twists" in male and "twists" not in female),
        ("bantuKnots assigned male, not female",
         "bantuKnots" in male and "bantuKnots" not in female),
    ]
    failed = [name for name, ok in checks if not ok]
    for name, ok in checks:
        print(f"[{'OK' if ok else 'FAIL'}] {name}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
