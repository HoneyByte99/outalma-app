// Pure validation/authorization helpers — the guard rails every callable relies
// on. No emulator needed, but runs in the same suite.
import {
  assertAuthenticated,
  requireString,
  requireBoolean,
  assertAdminClaim,
  assertAdminOrModeratorClaim,
  assertMinSupportClaim,
} from '../src/common';

describe('assertAuthenticated', () => {
  it('throws unauthenticated when uid is missing', () => {
    expect(() => assertAuthenticated(undefined)).toThrow(/Authentication required/);
  });
  it('passes when uid is present', () => {
    expect(() => assertAuthenticated('u1')).not.toThrow();
  });
});

describe('requireString', () => {
  it('returns a trimmed string', () => {
    expect(requireString('  hi  ', 'f')).toBe('hi');
  });
  it.each([undefined, null, 42, '', '   '])('rejects %p', (v) => {
    expect(() => requireString(v, 'f')).toThrow(/must be a non-empty string/);
  });
});

describe('requireBoolean', () => {
  it('returns the boolean', () => {
    expect(requireBoolean(false, 'f')).toBe(false);
    expect(requireBoolean(true, 'f')).toBe(true);
  });
  it.each([undefined, 'true', 0, 1, null])('rejects %p', (v) => {
    expect(() => requireBoolean(v, 'f')).toThrow(/must be a boolean/);
  });
});

describe('claim assertions', () => {
  it('assertAdminClaim only passes for exactly true', () => {
    expect(() => assertAdminClaim(true)).not.toThrow();
    expect(() => assertAdminClaim(false)).toThrow(/Admin privileges/);
    expect(() => assertAdminClaim(undefined)).toThrow(/Admin privileges/);
    expect(() => assertAdminClaim('true')).toThrow(/Admin privileges/);
  });

  it('assertAdminOrModeratorClaim passes for admin or moderator', () => {
    expect(() => assertAdminOrModeratorClaim({ admin: true })).not.toThrow();
    expect(() => assertAdminOrModeratorClaim({ moderator: true })).not.toThrow();
    expect(() => assertAdminOrModeratorClaim({ support: true })).toThrow();
    expect(() => assertAdminOrModeratorClaim(undefined)).toThrow();
  });

  it('assertMinSupportClaim passes for admin, moderator or support', () => {
    expect(() => assertMinSupportClaim({ support: true })).not.toThrow();
    expect(() => assertMinSupportClaim({ moderator: true })).not.toThrow();
    expect(() => assertMinSupportClaim({ admin: true })).not.toThrow();
    expect(() => assertMinSupportClaim({ readonly: true })).toThrow();
    expect(() => assertMinSupportClaim(undefined)).toThrow();
  });
});
