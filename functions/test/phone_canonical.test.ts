// canonicalPhone, pinned to the declaration the app is pinned to as well
// (shared/phone-normalisation-cases.json, read by
// test/shared/phone_normalisation_parity_test.dart on the Dart side). A case
// that passed here and failed there would be a number the app sends in one
// form and the server stores in another.
import { readFileSync } from 'fs';
import { join } from 'path';
import { canonicalPhone } from '../src/phone_canonical';
import { TRUNK_ZERO_PREFIXES } from '../src/otp_rate_limit';

type Declaration = {
  trunkZeroPrefixes: string[];
  cases: Array<{ dialCode: string; national: string; e164: string }>;
  rejected: string[];
};

const declaration: Declaration = JSON.parse(
  readFileSync(join(__dirname, '../../shared/phone-normalisation-cases.json'), 'utf8')
);

describe('canonicalPhone', () => {
  it('drops the trunk zero for exactly the declared dial codes', () => {
    expect([...TRUNK_ZERO_PREFIXES].sort()).toEqual([...declaration.trunkZeroPrefixes].sort());
  });

  it.each(declaration.cases.map((c) => [`${c.dialCode} ${c.national}`, c]))(
    'turns %s into its canonical form',
    (_label, c) => {
      const typed = c as Declaration['cases'][number];
      expect(canonicalPhone(`${typed.dialCode}${typed.national}`)).toBe(typed.e164);
    }
  );

  it.each(declaration.cases.map((c) => [c.e164]))('leaves %s as it is', (e164) => {
    // Idempotent: the quota key is computed again on the canonical number.
    expect(canonicalPhone(e164)).toBe(e164);
  });

  it.each(declaration.rejected.map((r) => [r]))(
    'refuses %s, which the dropped zeros make too short',
    (raw) => {
      expect(() => canonicalPhone(raw)).toThrow(
        expect.objectContaining({ code: 'invalid-argument' })
      );
    }
  );

  it.each([
    ['a number', 33612345678],
    ['nothing', undefined],
    ['an object', { phone: '+33612345678' }],
  ])('refuses %s', (_label, value) => {
    expect(() => canonicalPhone(value)).toThrow(
      expect.objectContaining({ code: 'invalid-argument' })
    );
  });

  it.each([
    ['a dot', '+33.6.39.98.12.34'],
    ['parentheses', '+33(0)639981234'],
    ['no plus sign', '0639981234'],
    ['letters', '+33 6 39 98 12 AB'],
  ])('keeps refusing %s, a separator PhoneField never lets through', (_label, raw) => {
    expect(() => canonicalPhone(raw)).toThrow(
      expect.objectContaining({ code: 'invalid-argument' })
    );
  });

  it('trims the ends as before', () => {
    expect(canonicalPhone('  +33639981234 ')).toBe('+33639981234');
  });
});
