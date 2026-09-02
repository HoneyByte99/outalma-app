// The provider-rating predicate exists TWICE: here in TypeScript, and in
// scripts/rating_predicate.py, which the backfill replays against production
// data. Nothing enforced that the two agreed. A divergence does not throw and
// does not log: it just makes the public aggregate disagree with what a replay
// computes, quietly, for whichever slice of reviews falls in the gap.
//
// So this file runs BOTH implementations over one shared table of cases and
// fails on the first case where they part company. The table
// (shared/rating-parity-cases.json) is the only place cases are declared, on
// purpose: two hand-kept lists drift, which is the failure being guarded
// against.
//
// No emulator needed, both predicates are pure.
import { execFileSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

import {
  countsTowardProviderRating,
  isUsableRating,
  type BookingLike,
  type ReviewLike,
} from '../src/provider_rating';

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const CASES_FILE = path.join(REPO_ROOT, 'shared', 'rating-parity-cases.json');
const RUNNER = path.join(REPO_ROOT, 'scripts', 'rating_parity_runner.py');

interface Verdict {
  name: string;
  counts: boolean;
  rating: number | null;
}

interface ParityCase {
  name: string;
  review: Record<string, unknown> | null;
  booking: Record<string, unknown> | null;
  expected: { counts: boolean; rating: number | null };
}

const cases: ParityCase[] = JSON.parse(
  fs.readFileSync(CASES_FILE, 'utf8'),
).cases;

/// The TypeScript verdict for one case, in the same shape the Python runner
/// emits. `rating` is normalised too: agreeing that a review counts while
/// disagreeing on the number would still corrupt the sum.
function typescriptVerdict(c: ParityCase): Verdict {
  const review = (c.review ?? {}) as ReviewLike;
  // A null booking is a bookingId that resolves to nothing. The server reaches
  // the predicate with no booking data at all, which an empty object models.
  const booking = (c.booking ?? {}) as BookingLike;
  const rating = (review as { rating?: unknown }).rating;
  return {
    name: c.name,
    counts: countsTowardProviderRating(review, booking),
    rating: isUsableRating(rating) ? rating : null,
  };
}

function pythonVerdicts(): Verdict[] {
  // Deliberately NOT wrapped in a try that skips. A parity guard that quietly
  // disables itself when python3 is missing is worse than no guard: it would
  // report green over exactly the silent divergence it exists to catch.
  const raw = execFileSync('python3', [RUNNER, CASES_FILE], {
    encoding: 'utf8',
    cwd: REPO_ROOT,
  });
  return JSON.parse(raw) as Verdict[];
}

describe('the shared table of cases', () => {
  // Guards against the table being emptied or gutted, which would leave every
  // assertion below vacuously green.
  it('covers the edge cases the predicate is made of', () => {
    expect(cases.length).toBeGreaterThanOrEqual(25);
    const names = cases.map((c) => c.name);
    expect(new Set(names).size).toBe(names.length);
    // Both verdicts must be represented, in both dimensions.
    expect(cases.some((c) => c.expected.counts)).toBe(true);
    expect(cases.some((c) => !c.expected.counts)).toBe(true);
    expect(cases.some((c) => c.expected.rating !== null)).toBe(true);
    expect(cases.some((c) => c.expected.rating === null)).toBe(true);
  });
});

describe('TypeScript predicate against the shared table', () => {
  it.each(cases.map((c) => [c.name, c] as const))('%s', (_name, c) => {
    const got = typescriptVerdict(c);
    expect({ counts: got.counts, rating: got.rating }).toEqual({
      counts: c.expected.counts,
      rating: c.expected.rating,
    });
  });
});

describe('TypeScript and Python agree, case by case', () => {
  // One spawn for the whole table rather than one per case.
  const fromPython = pythonVerdicts();

  it('the Python side answered for every case, in order', () => {
    expect(fromPython.map((v) => v.name)).toEqual(cases.map((c) => c.name));
  });

  it('no case diverges between the two implementations', () => {
    const mine = cases.map(typescriptVerdict);
    // Compared as whole arrays so the failure output names every case that
    // drifted, not just the first one.
    expect(mine).toEqual(fromPython);
  });

  it('the Python side also matches the table on its own', () => {
    // Runs the runner's own --check. Catches the case where both sides drift
    // together, which comparing them to each other alone would call parity.
    const out = execFileSync('python3', [RUNNER, '--check', CASES_FILE], {
      encoding: 'utf8',
      cwd: REPO_ROOT,
    });
    expect(out).toContain(`matches all ${cases.length} shared cases`);
  });
});

// The registry decision, `is_counted`, is now shared by the backfill's
// transaction AND by its dry run. Before that, the dry run returned before ever
// reading rating_events: already_counted was structurally always 0, so the dry
// run could not tell whether the backfill had already run, and reported reviews
// already counted as work still to do.
//
// Sharing one definition is what makes the dry run's answer the same answer the
// write path would give. This pins the Python side; the TypeScript side of the
// same decision is pinned behaviourally against the emulator in
// provider_rating.test.ts, because there it is one line inside
// ratingDeltaWithin rather than an exported function.
describe('the registry decision, shared by the backfill write path and dry run', () => {
  it('matches its table, malformed entries included', () => {
    const out = execFileSync('python3', [RUNNER, '--check-registry'], {
      encoding: 'utf8',
      cwd: REPO_ROOT,
    });
    expect(out).toContain('registry predicate matches all');
    // The backfill's whole verdict, not just the registry line. Its cases
    // include the one the broken dry run got wrong: an already-counted review
    // reported as work still to do.
    expect(out).toContain('backfill classifier matches all');
  });

  it('exits non-zero when the predicate drifts', () => {
    // A self-check that cannot fail proves nothing. This drives the runner with
    // a deliberately broken predicate and requires a non-zero exit, so the
    // green above is known to mean something.
    const broken = `
import sys, os
sys.path.insert(0, ${JSON.stringify(path.join(REPO_ROOT, 'scripts'))})
import rating_predicate
rating_predicate.is_counted = lambda d: True
import rating_parity_runner
rating_parity_runner.is_counted = rating_predicate.is_counted
sys.exit(rating_parity_runner.check_registry())
`;
    let code = 0;
    try {
      execFileSync('python3', ['-c', broken], { encoding: 'utf8', cwd: REPO_ROOT, stdio: 'pipe' });
    } catch (e) {
      code = (e as { status?: number }).status ?? 0;
    }
    expect(code).toBe(1);
  });
});
