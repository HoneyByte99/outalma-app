// ---------------------------------------------------------------------------
// Identity document extraction
// ---------------------------------------------------------------------------
//
// Everything that depends on the physical layout of the card lives here, behind
// pure functions and one injectable seam. That isolation is deliberate: the MRZ
// structure of the CEDEAO card is an ASSUMPTION until real cards are checked
// (open question Q1 of the spec). If the real layout differs, or if the 17-digit
// national number turns out not to be in the MRZ at all, the fix lands in this
// file only, and not in the callables, the rules, the deletion path or the
// export.
//
// No decision is ever derived from what is computed here. `mrzValid` and the
// duplicate key are review aids shown to a human, never approval conditions
// (decision D1).

/// Characters allowed in a machine readable zone.
const MRZ_CHARSET = /^[A-Z0-9<]+$/;

/// TD1 is the three-line, 30-character-per-line format.
export const TD1_LINE_LENGTH = 30;
export const TD1_LINE_COUNT = 3;

/// Weights of the ICAO 9303 check digit, applied cyclically.
const CHECK_WEIGHTS: readonly [number, number, number] = [7, 3, 1];

/// Object names are imposed by the server. The client never sends a path.
export const IDENTITY_OBJECT_NAMES = ['recto.jpg', 'verso.jpg', 'selfie.jpg'] as const;

export interface Td1Fields {
  documentCode: string;
  issuingState: string;
  documentNumber: string;
  optionalData1: string;
  birthDate: string;
  sex: string;
  expiryDate: string;
  nationality: string;
  optionalData2: string;
  primaryName: string;
  secondaryName: string;
}

export interface Td1Result {
  fields: Td1Fields;
  /// True only when every check digit present in the MRZ verifies, including
  /// the composite one. A false here never rejects a submission.
  valid: boolean;
  /// Which check digits failed, for diagnosis in the review screen.
  invalidChecks: string[];
}

/// Numeric value of one MRZ character: digits are themselves, letters are
/// 10..35, the filler `<` is 0.
export function charValue(c: string): number {
  if (c >= '0' && c <= '9') return c.charCodeAt(0) - 48;
  if (c >= 'A' && c <= 'Z') return c.charCodeAt(0) - 55;
  if (c === '<') return 0;
  return Number.NaN;
}

/// ICAO 9303 check digit over a field, weights 7-3-1 cycling.
/// Returns NaN when the input carries a character outside the MRZ charset,
/// which makes an unreadable field fail its check rather than pass silently.
export function checkDigit(value: string): number {
  let sum = 0;
  for (let i = 0; i < value.length; i++) {
    const v = charValue(value.charAt(i));
    if (Number.isNaN(v)) return Number.NaN;
    sum += v * CHECK_WEIGHTS[(i % 3) as 0 | 1 | 2];
  }
  return sum % 10;
}

/// True when `digit` is the correct check digit for `value`.
export function checkDigitMatches(value: string, digit: string): boolean {
  const expected = checkDigit(value);
  if (Number.isNaN(expected)) return false;
  if (!/^[0-9]$/.test(digit)) return false;
  return expected === Number(digit);
}

/// Picks the MRZ lines out of raw OCR output.
///
/// The zone is recognisable without knowing the card: a restricted charset
/// (uppercase, digits, `<`) and a fixed line length. Everything else the OCR
/// returned (headings, printed labels, the holder's photo caption) is dropped.
/// Whitespace inside a line is stripped first, since OCR routinely inserts it.
export function isolateMrzLines(rawLines: string[]): string[] {
  const candidates = rawLines
    .map(line => line.replace(/\s+/g, '').toUpperCase())
    .filter(
      line => line.length === TD1_LINE_LENGTH && MRZ_CHARSET.test(line)
    );

  // Keep the LAST three: the MRZ sits at the bottom of the card, and a stray
  // 30-character uppercase run elsewhere would otherwise shift the window.
  return candidates.length >= TD1_LINE_COUNT
    ? candidates.slice(-TD1_LINE_COUNT)
    : [];
}

/// Parses three TD1 lines into fields and verifies every check digit.
/// Throws nothing: an unparsable input yields `valid: false` with empty fields,
/// because a submission is never blocked by a failed extraction (AC-02).
export function parseTd1(lines: string[]): Td1Result {
  const empty: Td1Fields = {
    documentCode: '',
    issuingState: '',
    documentNumber: '',
    optionalData1: '',
    birthDate: '',
    sex: '',
    expiryDate: '',
    nationality: '',
    optionalData2: '',
    primaryName: '',
    secondaryName: '',
  };

  if (
    lines.length !== TD1_LINE_COUNT ||
    lines.some(l => l.length !== TD1_LINE_LENGTH || !MRZ_CHARSET.test(l))
  ) {
    return { fields: empty, valid: false, invalidChecks: ['format'] };
  }

  // Defaults keep TypeScript's strict index checks happy; the length and
  // charset guard above already rules out a missing line.
  const [l1 = '', l2 = '', l3 = ''] = lines;

  const documentNumber = l1.slice(5, 14);
  const documentNumberCheck = l1.slice(14, 15);
  const optionalData1 = l1.slice(15, 30);

  const birthDate = l2.slice(0, 6);
  const birthDateCheck = l2.slice(6, 7);
  const expiryDate = l2.slice(8, 14);
  const expiryDateCheck = l2.slice(14, 15);
  const optionalData2 = l2.slice(18, 29);
  const compositeCheck = l2.slice(29, 30);

  const [primaryRaw, secondaryRaw] = l3.split('<<');

  const fields: Td1Fields = {
    documentCode: strip(l1.slice(0, 2)),
    issuingState: strip(l1.slice(2, 5)),
    documentNumber: strip(documentNumber),
    optionalData1: strip(optionalData1),
    birthDate,
    sex: strip(l2.slice(7, 8)),
    expiryDate,
    nationality: strip(l2.slice(15, 18)),
    optionalData2: strip(optionalData2),
    primaryName: humanName(primaryRaw ?? ''),
    secondaryName: humanName(secondaryRaw ?? ''),
  };

  // Composite check covers the upper part of line 1 plus the dated fields and
  // the second optional data block of line 2 (ICAO 9303 part 5).
  const composite =
    l1.slice(5, 30) + l2.slice(0, 7) + l2.slice(8, 15) + l2.slice(18, 29);

  const invalidChecks: string[] = [];
  if (!checkDigitMatches(documentNumber, documentNumberCheck)) {
    invalidChecks.push('documentNumber');
  }
  if (!checkDigitMatches(birthDate, birthDateCheck)) {
    invalidChecks.push('birthDate');
  }
  if (!checkDigitMatches(expiryDate, expiryDateCheck)) {
    invalidChecks.push('expiryDate');
  }
  if (!checkDigitMatches(composite, compositeCheck)) {
    invalidChecks.push('composite');
  }

  return { fields, valid: invalidChecks.length === 0, invalidChecks };
}

function strip(value: string): string {
  return value.replace(/</g, '').trim();
}

function humanName(value: string): string {
  return value.replace(/</g, ' ').trim();
}

/// Normalised form used as the exact duplicate-search key.
///
/// Uppercases and drops every character that is not a letter or a digit, so
/// that spacing, dashes and MRZ filler characters cannot make two records of
/// the same card look different. Returns an empty string when nothing is left:
/// callers must never store or search an empty key, otherwise every record
/// without a readable number would be flagged as a duplicate of the previous
/// one, pointing at a stranger's file.
export function normalizeCniNumber(raw: string | null | undefined): string {
  if (!raw) return '';
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

/// Picks the national card number out of parsed MRZ fields.
///
/// ASSUMPTION (open question Q1): the Senegalese CEDEAO card carries a 17-digit
/// number. The TD1 arithmetic constrains where it can possibly be: the document
/// number field is 9 characters, optional data 1 is 15 and optional data 2 is
/// 11. A 17-digit number therefore fits in NEITHER field alone: it must straddle
/// the two optional blocks, or it is simply not in the MRZ and is only printed
/// on the face of the card. This function searches the concatenated optional
/// data for a 17-digit run and falls back to the document number.
///
/// If real cards show the number is absent from the MRZ, the duplicate key has
/// to come from OCR of the printed text instead, which is less reliable. That
/// change lands here and in extractionFromLines, nowhere else.
export function pickCniNumber(fields: Td1Fields): string {
  const haystack = normalizeCniNumber(
    `${fields.optionalData1}${fields.optionalData2}`
  );
  const seventeen = haystack.match(/\d{17}/);
  if (seventeen) return seventeen[0];
  return normalizeCniNumber(fields.documentNumber);
}

// ---------------------------------------------------------------------------
// Storage object paths
// ---------------------------------------------------------------------------

/// A batch identifier names a Storage prefix, so it is checked by length plus a
/// strict character allowlist rather than a regular expression: in JavaScript
/// `$` also matches before a trailing newline, and an object name may contain
/// one. The allowlist makes `..`, `/` and control characters impossible by
/// construction, without relying on a startsWith check.
export function isValidBatchId(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  if (value.length < 8 || value.length > 64) return false;
  return value.replace(/[A-Za-z0-9_-]/g, '') === '';
}

/// Builds the three object paths from the AUTHENTICATED uid and a validated
/// batch id. The client never supplies a path: it supplies only the batch id,
/// and the prefix is reconstructed here.
export function buildObjectPaths(
  uid: string,
  batchId: string
): { recto: string; verso: string; selfie: string } {
  const prefix = `private/identity/${uid}/${batchId}`;
  return {
    recto: `${prefix}/recto.jpg`,
    verso: `${prefix}/verso.jpg`,
    selfie: `${prefix}/selfie.jpg`,
  };
}

// ---------------------------------------------------------------------------
// Text extraction seam
// ---------------------------------------------------------------------------

/// The only external, billed dependency of the increment, behind an interface
/// so tests can substitute a double that counts its calls. Without this seam,
/// "exactly one extraction per file" and "no extraction beyond the rate limit"
/// are claims that cannot be observed.
export interface TextExtractor {
  detect(gcsUri: string): Promise<string[]>;
}

export interface ExtractionOutcome {
  status: 'ok' | 'partial' | 'failed';
  mrzValid: boolean;
  mrzRaw: string | null;
  cniNumber: string | null;
  cniNumberKey: string | null;
  cniNom: string | null;
  cniPrenom: string | null;
  cniDateNaissance: string | null;
  cniDateExpiration: string | null;
  cniSexe: string | null;
}

export const FAILED_EXTRACTION: ExtractionOutcome = {
  status: 'failed',
  mrzValid: false,
  mrzRaw: null,
  cniNumber: null,
  cniNumberKey: null,
  cniNom: null,
  cniPrenom: null,
  cniDateNaissance: null,
  cniDateExpiration: null,
  cniSexe: null,
};

/// Turns raw OCR lines into the fields stored on a file.
///
/// `partial` means the MRZ was found and parsed but at least one check digit
/// failed: the reviewer still gets the fields, flagged as unverified. `failed`
/// means no MRZ could be isolated at all. Neither blocks anything.
export function extractionFromLines(rawLines: string[]): ExtractionOutcome {
  const mrzLines = isolateMrzLines(rawLines);
  if (mrzLines.length !== TD1_LINE_COUNT) return { ...FAILED_EXTRACTION };

  const parsed = parseTd1(mrzLines);
  const cniNumber = pickCniNumber(parsed.fields);
  const key = normalizeCniNumber(cniNumber);

  return {
    status: parsed.valid ? 'ok' : 'partial',
    mrzValid: parsed.valid,
    mrzRaw: mrzLines.join('\n'),
    cniNumber: cniNumber || null,
    // An empty key is never stored, so it can never be searched for.
    cniNumberKey: key.length > 0 ? key : null,
    cniNom: parsed.fields.primaryName || null,
    cniPrenom: parsed.fields.secondaryName || null,
    cniDateNaissance: parsed.fields.birthDate || null,
    cniDateExpiration: parsed.fields.expiryDate || null,
    cniSexe: parsed.fields.sex || null,
  };
}
