// Pure decision logic of the OTP rate limit. No emulator, no network, no
// Twilio: every rule below is a table of inputs and an expected verdict, which
// is what makes them killable by mutation.
import * as fs from 'fs';
import * as path from 'path';
import {
  ALLOWED_PREFIXES,
  TRUNK_ZERO_PREFIXES,
  DEFAULT_LIMITS,
  OTP_ERROR,
  OTP_STATE_TTL_MS,
  dayKey,
  decideOtpRequest,
  isAllowedPrefix,
  normalisePhone,
  phoneHash,
  readState,
  resolveLimits,
} from '../src/otp_rate_limit';

const L = DEFAULT_LIMITS;
const T0 = Date.UTC(2026, 8, 12, 10, 0, 0); // 2026-09-12 12:00 Europe/Paris
const SN = '+221771234567';

/** A state holding `n` credits, the most recent one `lastAgoMs` ago. */
function stateWith(n: number, lastAgoMs: number, spacingMs = 10 * 60 * 1000) {
  const ts: number[] = [];
  for (let i = 0; i < n; i++) ts.push(T0 - lastAgoMs - (n - 1 - i) * spacingMs);
  return { creditTimestampsMs: ts, updatedAtMs: T0 };
}

describe('dial code allowlist', () => {
  it('matches the shared declaration exactly', () => {
    const file = path.join(__dirname, '..', '..', 'shared', 'allowed-phone-prefixes.json');
    const shared = JSON.parse(fs.readFileSync(file, 'utf8')) as { prefixes: string[] };
    expect([...ALLOWED_PREFIXES].sort()).toEqual([...shared.prefixes].sort());
  });

  it.each(['+221771234567', '+33612345678', '+15551234567', '+237691234567'])(
    'accepts %s',
    (p) => expect(isAllowedPrefix(p)).toBe(true)
  );

  it.each(['+99912345678', '+79123456789', '+8613800138000', '+2409912345'])(
    'refuses %s',
    (p) => expect(isAllowedPrefix(p)).toBe(false)
  );

  it('prefers the longest match so +221 is not shadowed', () => {
    // +22 is not in the list; +221 is. A shortest-match implementation would
    // have to fall through, a buggy one could match nothing at all.
    expect(isAllowedPrefix('+221771234567')).toBe(true);
    expect(isAllowedPrefix('+22912345678')).toBe(true); // Benin
  });
});

describe('normalisePhone (quota key only)', () => {
  it.each(TRUNK_ZERO_PREFIXES)('strips the trunk zero for %s', (prefix) => {
    const national = '612345678';
    expect(normalisePhone(`${prefix}0${national}`)).toBe(`${prefix}${national}`);
  });

  it('collapses stacked zeros onto the same key', () => {
    expect(normalisePhone('+3300612345678')).toBe('+33612345678');
    expect(normalisePhone('+330612345678')).toBe('+33612345678');
    expect(normalisePhone('+33612345678')).toBe('+33612345678');
  });

  it('KEEPS the leading zero for +39, where it is part of the number', () => {
    // A Rome landline is +39 06... Stripping it would put two distinct
    // subscribers on one quota key.
    expect(normalisePhone('+390612345678')).toBe('+390612345678');
  });

  it.each(['+221771234567', '+22312345678', '+237691234567', '+34612345678', '+351912345678', '+15551234567'])(
    'leaves %s untouched (no trunk prefix in that plan)',
    (p) => expect(normalisePhone(p)).toBe(p)
  );

  it('never collapses a number down to a bare dial code', () => {
    expect(normalisePhone('+3300000')).toBe('+3300000');
  });
});

describe('dayKey', () => {
  it('formats YYYY-MM-DD in Europe/Paris', () => {
    expect(dayKey(Date.UTC(2026, 8, 12, 10, 0, 0))).toBe('2026-09-12');
  });

  it('rolls over at Paris midnight, not UTC midnight', () => {
    // 22:30 UTC on 12 Sept is 00:30 Paris on 13 Sept (CEST, UTC+2).
    expect(dayKey(Date.UTC(2026, 8, 12, 22, 30, 0))).toBe('2026-09-13');
    expect(dayKey(Date.UTC(2026, 8, 12, 21, 30, 0))).toBe('2026-09-12');
  });

  it('handles a winter date (CET, UTC+1)', () => {
    expect(dayKey(Date.UTC(2026, 0, 15, 23, 30, 0))).toBe('2026-01-16');
  });
});

describe('readState tolerance', () => {
  it.each([
    ['undefined', undefined],
    ['null', null],
    ['empty object', {}],
    ['wrong type', { creditTimestampsMs: 'nope' }],
    ['array of junk', { creditTimestampsMs: ['a', null, NaN] }],
  ])('reads %s as an EMPTY state, never as an authorisation', (_label, raw) => {
    expect(readState(raw).creditTimestampsMs).toEqual([]);
  });

  it('keeps only finite numbers', () => {
    expect(readState({ creditTimestampsMs: [1, 'x', 2, Infinity] }).creditTimestampsMs).toEqual([1, 2]);
  });
});

describe('resolveLimits', () => {
  it('falls back to defaults when the document is absent', () => {
    expect(resolveLimits(undefined)).toEqual(DEFAULT_LIMITS);
    expect(resolveLimits(null)).toEqual(DEFAULT_LIMITS);
  });

  it('accepts a sane override', () => {
    const r = resolveLimits({ alertAt: 100, stopAt: 400 });
    expect(r.alertAt).toBe(100);
    expect(r.stopAt).toBe(400);
  });

  it.each([
    ['zero', { stopAt: 0 }],
    ['negative', { stopAt: -5 }],
    ['absurdly high', { stopAt: 1e9 }],
    ['a string', { stopAt: '600' }],
    ['NaN', { stopAt: NaN }],
  ])('refuses an aberrant stopAt (%s) and keeps the default', (_l, doc) => {
    expect(resolveLimits(doc).stopAt).toBe(DEFAULT_LIMITS.stopAt);
  });

  it('restores BOTH defaults when alertAt >= stopAt', () => {
    const r = resolveLimits({ alertAt: 500, stopAt: 400 });
    expect(r.alertAt).toBe(DEFAULT_LIMITS.alertAt);
    expect(r.stopAt).toBe(DEFAULT_LIMITS.stopAt);
  });

  it('keeps the TTL strictly above the day window, or the purge hands back quota', () => {
    expect(OTP_STATE_TTL_MS).toBeGreaterThan(DEFAULT_LIMITS.dayWindowMs);
  });
});

describe('decideOtpRequest', () => {
  it('allows a first request on a fresh number', () => {
    const d = decideOtpRequest(undefined, 0, SN, L, T0);
    expect(d.allowed).toBe(true);
    if (d.allowed) {
      expect(d.nextState.creditTimestampsMs).toEqual([T0]);
      expect(d.globalAfter).toBe(1);
    }
  });

  it('refuses a dial code outside the allowlist, before anything else', () => {
    const d = decideOtpRequest(undefined, 0, '+99912345678', L, T0);
    expect(d).toMatchObject({ allowed: false, code: OTP_ERROR.prefixNotAllowed });
  });

  it('refuses on the global stop even for a fresh number', () => {
    const d = decideOtpRequest(undefined, L.stopAt, SN, L, T0);
    expect(d).toMatchObject({ allowed: false, code: OTP_ERROR.globalCap });
  });

  it('lets the request through one below the global stop', () => {
    expect(decideOtpRequest(undefined, L.stopAt - 1, SN, L, T0).allowed).toBe(true);
  });

  describe('backoff', () => {
    it('refuses a second send inside 60 s and says how long to wait', () => {
      const d = decideOtpRequest(stateWith(1, 10_000), 0, SN, L, T0);
      expect(d).toMatchObject({ allowed: false, code: OTP_ERROR.backoff });
      if (!d.allowed) expect(d.retryAfterMs).toBe(50_000);
    });

    it('allows it once 60 s have passed', () => {
      expect(decideOtpRequest(stateWith(1, 60_000), 0, SN, L, T0).allowed).toBe(true);
    });

    it('grows to 120 s at rank 2 and 300 s at rank 3', () => {
      const r2 = decideOtpRequest(stateWith(2, 90_000), 0, SN, L, T0);
      expect(r2).toMatchObject({ allowed: false, code: OTP_ERROR.backoff });
      const r3 = decideOtpRequest(stateWith(3, 200_000), 0, SN, L, T0);
      expect(r3).toMatchObject({ allowed: false, code: OTP_ERROR.backoff });
      expect(decideOtpRequest(stateWith(3, 300_000), 0, SN, L, T0).allowed).toBe(true);
    });

    it('stays at 300 s beyond the last rank', () => {
      const d = decideOtpRequest(stateWith(5, 299_000, 60_000), 0, SN, L, T0);
      expect(d).toMatchObject({ allowed: false, code: OTP_ERROR.backoff });
    });
  });

  describe('window cap', () => {
    it('refuses the 7th send inside the hour', () => {
      const d = decideOtpRequest(stateWith(6, 400_000, 5 * 60 * 1000), 0, SN, L, T0);
      expect(d).toMatchObject({ allowed: false, code: OTP_ERROR.windowCap });
    });

    it('allows again once the window slides past the oldest credit', () => {
      const ts = [];
      for (let i = 0; i < 6; i++) ts.push(T0 - L.windowMs - 1000 - i * 1000);
      const d = decideOtpRequest({ creditTimestampsMs: ts, updatedAtMs: T0 }, 0, SN, L, T0);
      expect(d.allowed).toBe(true);
    });
  });

  describe('day cap', () => {
    it('refuses beyond 15 credits in 24 rolling hours', () => {
      const ts: number[] = [];
      for (let i = 0; i < 15; i++) ts.push(T0 - 2 * 60 * 60 * 1000 - i * 60 * 60 * 1000);
      const d = decideOtpRequest({ creditTimestampsMs: ts, updatedAtMs: T0 }, 0, SN, L, T0);
      expect(d).toMatchObject({ allowed: false, code: OTP_ERROR.dayCap });
    });

    it('is a ROLLING window, so midnight does not hand back a quota', () => {
      const ts: number[] = [];
      for (let i = 0; i < 15; i++) ts.push(T0 - 23 * 60 * 60 * 1000 + i * 1000);
      const d = decideOtpRequest({ creditTimestampsMs: ts, updatedAtMs: T0 }, 0, SN, L, T0);
      expect(d).toMatchObject({ allowed: false, code: OTP_ERROR.dayCap });
    });
  });

  it('drops credits older than 24 h from the state it writes back', () => {
    const stale = T0 - 30 * 60 * 60 * 1000;
    const d = decideOtpRequest(
      { creditTimestampsMs: [stale], updatedAtMs: stale },
      0,
      SN,
      L,
      T0
    );
    expect(d.allowed).toBe(true);
    if (d.allowed) expect(d.nextState.creditTimestampsMs).toEqual([T0]);
  });

  it.each([
    ['prefix', '+99912345678', 0, undefined],
    ['global cap', SN, L.stopAt, undefined],
    ['backoff', SN, 0, 'backoff'],
  ])('a refusal on %s writes NO state and consumes no credit', (_label, phone, global, kind) => {
    const state = kind === 'backoff' ? stateWith(1, 1000) : undefined;
    const d = decideOtpRequest(state, global as number, phone as string, L, T0);
    expect(d.allowed).toBe(false);
    expect(d).not.toHaveProperty('nextState');
  });
});

describe('phoneHash', () => {
  it('hashes the NORMALISED form, so both spellings share one key', () => {
    expect(phoneHash('+330612345678', 'k')).toBe(phoneHash('+33612345678', 'k'));
  });

  it('separates distinct subscribers', () => {
    expect(phoneHash('+221771234567', 'k')).not.toBe(phoneHash('+221771234568', 'k'));
  });

  it('is keyed, so the same number differs under another key', () => {
    expect(phoneHash(SN, 'k1')).not.toBe(phoneHash(SN, 'k2'));
  });

  it('never leaks the number itself', () => {
    expect(phoneHash(SN, 'k')).not.toContain('771234567');
  });

  it.each([
    ['empty', ''],
    ['blank', '   '],
    ['absent', undefined as unknown as string],
  ])('THROWS on a %s key rather than degrading to an unkeyed digest', (_l, key) => {
    expect(() => phoneHash(SN, key)).toThrow(/OTP_HASH_KEY/);
  });
});
