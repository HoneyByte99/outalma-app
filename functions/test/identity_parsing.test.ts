/**
 * Pure-function suite for identity document extraction. No emulator, no
 * network: these are the deterministic pieces the increment rests on.
 *
 * The TD1 fixture is the canonical ICAO 9303 part 5 sample, which pins the
 * check-digit algorithm to a published reference rather than to our own
 * arithmetic. What remains an assumption is where the SENEGALESE card puts its
 * 17-digit number (open question Q1), and that assumption is confined to
 * pickCniNumber.
 */
import {
  buildObjectPaths,
  charValue,
  checkDigit,
  checkDigitMatches,
  extractionFromLines,
  isolateMrzLines,
  isValidBatchId,
  normalizeCniNumber,
  parseTd1,
  pickCniNumber,
} from '../src/identity_extraction';

// Canonical ICAO 9303 part 5 TD1 specimen.
const L1 = 'I<UTOD231458907<<<<<<<<<<<<<<<';
const L2 = '7408122F1204159UTO<<<<<<<<<<<6';
const L3 = 'ERIKSSON<<ANNA<MARIA<<<<<<<<<<';
const VALID_TD1 = [L1, L2, L3];

/**
 * Builds a well-formed TD1 with correct check digits from the parts that
 * matter, so a test can vary one field without hand-computing the arithmetic.
 * This is also the hook for adjusting to a real CEDEAO card once specimens are
 * available: change the parts here, not the assertions everywhere.
 */
function buildTd1(parts: {
  documentNumber?: string;
  optionalData1?: string;
  birthDate?: string;
  sex?: string;
  expiryDate?: string;
  optionalData2?: string;
  primaryName?: string;
  secondaryName?: string;
}): string[] {
  const pad = (v: string, n: number) => (v + '<'.repeat(n)).slice(0, n);
  const documentNumber = pad(parts.documentNumber ?? '', 9);
  const optionalData1 = pad(parts.optionalData1 ?? '', 15);
  const birthDate = parts.birthDate ?? '740812';
  const sex = parts.sex ?? 'F';
  const expiryDate = parts.expiryDate ?? '120415';
  const optionalData2 = pad(parts.optionalData2 ?? '', 11);

  const l1 =
    'I<UTO' + documentNumber + String(checkDigit(documentNumber)) + optionalData1;
  const head2 =
    birthDate +
    String(checkDigit(birthDate)) +
    sex +
    expiryDate +
    String(checkDigit(expiryDate)) +
    'UTO' +
    optionalData2;
  const composite =
    l1.slice(5, 30) + head2.slice(0, 7) + head2.slice(8, 15) + head2.slice(18, 29);
  const l2 = head2 + String(checkDigit(composite));

  const name = parts.primaryName
    ? `${parts.primaryName}<<${parts.secondaryName ?? ''}`
    : '';
  const l3 = pad(name, 30);

  return [l1, l2, l3];
}

describe('charValue', () => {
  it('maps digits to themselves, letters to 10..35, filler to 0', () => {
    expect(charValue('0')).toBe(0);
    expect(charValue('9')).toBe(9);
    expect(charValue('A')).toBe(10);
    expect(charValue('Z')).toBe(35);
    expect(charValue('<')).toBe(0);
  });

  it('is NaN outside the MRZ charset', () => {
    expect(charValue('a')).toBeNaN();
    expect(charValue(' ')).toBeNaN();
  });
});

describe('checkDigit', () => {
  it('matches the published check digits of the reference specimen', () => {
    expect(checkDigit('D23145890')).toBe(7);
    expect(checkDigit('740812')).toBe(2);
    expect(checkDigit('120415')).toBe(9);
  });

  it('is NaN when the input leaves the MRZ charset', () => {
    // An OCR artefact must fail its check rather than pass by coincidence.
    expect(checkDigit('D2314589 ')).toBeNaN();
  });

  it('rejects a non-digit check character', () => {
    expect(checkDigitMatches('740812', 'X')).toBe(false);
    expect(checkDigitMatches('740812', '')).toBe(false);
  });
});

describe('parseTd1', () => {
  it('parses every field of the reference specimen', () => {
    const { fields, valid, invalidChecks } = parseTd1(VALID_TD1);

    expect(valid).toBe(true);
    expect(invalidChecks).toEqual([]);
    expect(fields.documentCode).toBe('I');
    expect(fields.issuingState).toBe('UTO');
    expect(fields.documentNumber).toBe('D23145890');
    expect(fields.birthDate).toBe('740812');
    expect(fields.sex).toBe('F');
    expect(fields.expiryDate).toBe('120415');
    expect(fields.nationality).toBe('UTO');
    expect(fields.primaryName).toBe('ERIKSSON');
    expect(fields.secondaryName).toBe('ANNA MARIA');
  });

  it('flags the document number when its check digit disagrees', () => {
    const tampered = ['I<UTOD231458917<<<<<<<<<<<<<<<', L2, L3];
    const { valid, invalidChecks } = parseTd1(tampered);

    expect(valid).toBe(false);
    expect(invalidChecks).toContain('documentNumber');
  });

  it('flags the composite check when a covered field is altered', () => {
    // Change the optional data on line 1 without touching any single-field
    // check digit: only the composite can catch it.
    const tampered = ['I<UTOD231458907<<<<<<<<<<<<<<1', L2, L3];
    const { invalidChecks } = parseTd1(tampered);

    expect(invalidChecks).toContain('composite');
  });

  it('reports a format failure rather than throwing on junk input', () => {
    for (const junk of [[], ['too', 'few'], ['x'.repeat(30), L2, L3]]) {
      const res = parseTd1(junk as string[]);
      expect(res.valid).toBe(false);
      expect(res.invalidChecks).toEqual(['format']);
      expect(res.fields.documentNumber).toBe('');
    }
  });
});

describe('isolateMrzLines', () => {
  it('picks the three MRZ lines out of surrounding OCR noise', () => {
    const ocr = [
      'REPUBLIQUE DU SENEGAL',
      'CARTE NATIONALE D IDENTITE',
      L1,
      L2,
      L3,
    ];
    expect(isolateMrzLines(ocr)).toEqual(VALID_TD1);
  });

  it('strips whitespace the OCR inserted inside a line', () => {
    const spaced = [`${L1.slice(0, 10)} ${L1.slice(10)}`, L2, L3];
    expect(isolateMrzLines(spaced)).toEqual(VALID_TD1);
  });

  it('keeps the last three candidates, since the MRZ sits at the bottom', () => {
    const decoy = 'A'.repeat(30);
    expect(isolateMrzLines([decoy, L1, L2, L3])).toEqual(VALID_TD1);
  });

  it('returns nothing when fewer than three lines qualify', () => {
    expect(isolateMrzLines([L1, L2])).toEqual([]);
    expect(isolateMrzLines(['short', 'lines', 'only'])).toEqual([]);
  });
});

describe('normalizeCniNumber', () => {
  it('collapses formatting differences to one key', () => {
    const expected = '1234567890123456A';
    expect(normalizeCniNumber('1234 5678 9012 3456 A')).toBe(expected);
    expect(normalizeCniNumber('1234-5678-9012-3456-a')).toBe(expected);
    expect(normalizeCniNumber('1234567890123456A<<<')).toBe(expected);
  });

  it('returns an empty string for absent or unusable input', () => {
    // Callers rely on this to never store or search an empty key: two files
    // without a readable number would otherwise be duplicates of each other,
    // pointing a provider at a stranger's file.
    expect(normalizeCniNumber(null)).toBe('');
    expect(normalizeCniNumber(undefined)).toBe('');
    expect(normalizeCniNumber('<<<<<')).toBe('');
    expect(normalizeCniNumber('   ')).toBe('');
  });
});

describe('pickCniNumber', () => {
  const base = parseTd1(VALID_TD1).fields;

  it('prefers a 17-digit run carried in the optional data', () => {
    const fields = { ...base, optionalData1: '12345678901234567' };
    expect(pickCniNumber(fields)).toBe('12345678901234567');
  });

  it('finds the run when it straddles the two optional blocks', () => {
    const fields = { ...base, optionalData1: '123456789', optionalData2: '01234567' };
    expect(pickCniNumber(fields)).toBe('12345678901234567');
  });

  it('falls back to the document number when no 17-digit run exists', () => {
    expect(pickCniNumber(base)).toBe('D23145890');
  });
});

describe('isValidBatchId', () => {
  it('accepts a plain identifier of allowed length', () => {
    expect(isValidBatchId('abcd1234')).toBe(true);
    expect(isValidBatchId('a_b-c_d-1234567890')).toBe(true);
    expect(isValidBatchId('x'.repeat(64))).toBe(true);
  });

  it('rejects anything that could escape the prefix', () => {
    expect(isValidBatchId('../../etc')).toBe(false);
    expect(isValidBatchId('aaaa/bbbb')).toBe(false);
    expect(isValidBatchId('aaaa.bbbb')).toBe(false);
  });

  it('rejects a trailing newline, which an anchored regex would accept', () => {
    // /^[A-Za-z0-9_-]{8,64}$/.test('abcdefgh\n') is true in JavaScript, and an
    // object name may contain a newline. The allowlist form has no such hole.
    expect(isValidBatchId('abcdefgh\n')).toBe(false);
    expect(isValidBatchId('abcdefgh\r')).toBe(false);
  });

  it('rejects wrong lengths and non-strings', () => {
    expect(isValidBatchId('short')).toBe(false);
    expect(isValidBatchId('x'.repeat(65))).toBe(false);
    expect(isValidBatchId('')).toBe(false);
    expect(isValidBatchId(42)).toBe(false);
    expect(isValidBatchId(null)).toBe(false);
    expect(isValidBatchId(undefined)).toBe(false);
  });
});

describe('buildObjectPaths', () => {
  it('builds the three paths from the uid and the batch id', () => {
    expect(buildObjectPaths('p1', 'batch1234')).toEqual({
      recto: 'private/identity/p1/batch1234/recto.jpg',
      verso: 'private/identity/p1/batch1234/verso.jpg',
      selfie: 'private/identity/p1/batch1234/selfie.jpg',
    });
  });
});

describe('extractionFromLines', () => {
  it('reports ok and fills the fields on a fully valid MRZ', () => {
    const out = extractionFromLines(['NOISE', ...VALID_TD1]);

    expect(out.status).toBe('ok');
    expect(out.mrzValid).toBe(true);
    expect(out.cniNumber).toBe('D23145890');
    expect(out.cniNumberKey).toBe('D23145890');
    expect(out.cniNom).toBe('ERIKSSON');
    expect(out.cniPrenom).toBe('ANNA MARIA');
    expect(out.cniDateNaissance).toBe('740812');
    expect(out.cniSexe).toBe('F');
    expect(out.mrzRaw).toBe(VALID_TD1.join('\n'));
  });

  it('reports partial and still fills the fields when a check digit fails', () => {
    // The reviewer needs the fields even when they are unverified: mrzValid is
    // an aid, never an approval condition (decision D1).
    const out = extractionFromLines(['I<UTOD231458917<<<<<<<<<<<<<<<', L2, L3]);

    expect(out.status).toBe('partial');
    expect(out.mrzValid).toBe(false);
    expect(out.cniNom).toBe('ERIKSSON');
  });

  it('reports failed with empty fields when no MRZ is found', () => {
    const out = extractionFromLines(['CARTE NATIONALE', 'illisible']);

    expect(out.status).toBe('failed');
    expect(out.mrzValid).toBe(false);
    expect(out.cniNumber).toBeNull();
    expect(out.cniNumberKey).toBeNull();
    expect(out.mrzRaw).toBeNull();
  });

  it('flags noReadableText only when the OCR returned no text at all', () => {
    // A cow photo: the OCR sees nothing, so the reviewer is warned the upload is
    // probably not a document. Still "failed", never auto-rejected (decision D1).
    const cow = extractionFromLines([]);
    expect(cow.status).toBe('failed');
    expect(cow.noReadableText).toBe(true);

    const blankStrings = extractionFromLines(['', '   ', '\n']);
    expect(blankStrings.noReadableText).toBe(true);
  });

  it('does not flag noReadableText when text is present but has no MRZ', () => {
    // An unreadable card still carries printed text: not a "no document" case.
    const out = extractionFromLines(['CARTE NATIONALE', 'illisible']);
    expect(out.status).toBe('failed');
    expect(out.noReadableText).toBe(false);
  });

  it('does not flag noReadableText on a valid MRZ', () => {
    const out = extractionFromLines(['NOISE', ...VALID_TD1]);
    expect(out.noReadableText).toBe(false);
  });

  it('the constructed fixture is itself valid, so later cases mean something', () => {
    const built = buildTd1({ documentNumber: 'D23145890', primaryName: 'DIOP' });
    expect(parseTd1(built).valid).toBe(true);
  });

  it('yields nulls rather than empty strings when the card carries no data', () => {
    // Every optional field falls back to null, so a reviewer sees an empty
    // input to fill in rather than a blank string that looks filled.
    const blank = buildTd1({ documentNumber: '', sex: '<', primaryName: '' });
    const out = extractionFromLines(blank);

    expect(out.status).toBe('ok');
    expect(out.cniNumber).toBeNull();
    expect(out.cniNumberKey).toBeNull();
    expect(out.cniNom).toBeNull();
    expect(out.cniPrenom).toBeNull();
    expect(out.cniSexe).toBeNull();
  });

  it('never stores an empty duplicate key', () => {
    const blank = buildTd1({ documentNumber: '' });
    const out = extractionFromLines(blank);
    expect(out.cniNumberKey).toBeNull();
  });

  it('reads a 17-digit national number out of the optional data', () => {
    // The layout this assumes is open question Q1, to confirm on real cards.
    // The number cannot sit in optional data 1 alone: that field is 15
    // characters and the number is 17, so it necessarily straddles both
    // optional blocks. That arithmetic is what makes Q1 worth confirming on a
    // real card rather than assuming.
    const built = buildTd1({
      documentNumber: 'D23145890',
      optionalData1: '123456789012345',
      optionalData2: '67',
      primaryName: 'NDIAYE',
      secondaryName: 'FATOU',
    });
    const out = extractionFromLines(built);

    expect(out.cniNumber).toBe('12345678901234567');
    expect(out.cniNumberKey).toBe('12345678901234567');
    expect(out.cniNom).toBe('NDIAYE');
    expect(out.cniPrenom).toBe('FATOU');
  });
});
