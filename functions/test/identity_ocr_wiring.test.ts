/**
 * Pure-function suite for the pieces that wire the in-process recogniser to the
 * stored image. No emulator, no network, no WebAssembly: what is tested here is
 * the URI split every recognition depends on, and the log summary that made the
 * 2026-09 outage visible in the first place.
 */
import {
  errorSummary,
  parseGcsUri,
  readCard,
} from '../src/identity_verification';
import {
  normalizeOcrLines,
  OCR_TRUNCATED_SUFFIX,
} from '../src/identity_extraction';

describe('parseGcsUri', () => {
  it('splits a bucket from its object path', () => {
    expect(parseGcsUri('gs://my-bucket/private/identity/u1/b1/recto.jpg')).toEqual({
      bucket: 'my-bucket',
      objectPath: 'private/identity/u1/b1/recto.jpg',
    });
  });

  it('keeps every segment of a deep path', () => {
    expect(parseGcsUri('gs://b/a/b/c/d.jpg').objectPath).toBe('a/b/c/d.jpg');
  });

  it('throws rather than guessing on a malformed URI', () => {
    for (const bad of ['', 'my-bucket/obj.jpg', 'https://b/o.jpg', 'gs://bucket-only', 'gs:///obj']) {
      expect(() => parseGcsUri(bad)).toThrow(/Malformed/);
    }
  });
});

describe('errorSummary', () => {
  it('keeps the code and the message, which is what names a cause', () => {
    const e = Object.assign(new Error('Vision API has not been used'), { code: 7 });
    expect(errorSummary(e)).toBe('7: Vision API has not been used');
  });

  it('keeps the message when the error carries no code', () => {
    expect(errorSummary(new Error('socket hang up'))).toBe('socket hang up');
  });

  it('survives a thrown value that is not an Error', () => {
    expect(errorSummary('boom')).toBe('boom');
    expect(errorSummary(undefined)).toBe('undefined');
  });

  it('redacts the private prefix, which carries the provider uid', () => {
    // Budget line S12: a storage error routinely quotes the object path, and
    // that path names the provider. The cause stays, the identity goes.
    const out = errorSummary(
      new Error('No such object: bkt/private/identity/UID123/batch9/recto.jpg')
    );
    expect(out).toContain('No such object');
    expect(out).not.toContain('UID123');
    expect(out).toContain('[redacted]');
  });

  it('caps a stack-shaped message so one entry cannot flood the log', () => {
    expect(errorSummary(new Error('x'.repeat(5000)))).toHaveLength(300);
  });
});

describe('readCard', () => {
  const FACES = { recto: 'p/recto.jpg', verso: 'p/verso.jpg' };

  // Canonical ICAO 9303 part 5 TD1 specimen, same fixture as the parsing suite.
  const MRZ_OK = [
    'I<UTOD231458907<<<<<<<<<<<<<<<',
    '7408122F1204159UTO<<<<<<<<<<<6',
    'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
  ];

  // Same zone with the document-number check digit broken: read, unverified.
  const MRZ_PARTIAL = [
    'I<UTOD231458917<<<<<<<<<<<<<<<',
    '7408122F1204159UTO<<<<<<<<<<<6',
    'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
  ];

  /// Answers with an MRZ only for the face it is told to, so which face was
  /// read is observable rather than assumed.
  function detector(mrzOn: string | null, printed = ['REPUBLIQUE DU SENEGAL']) {
    const calls: string[] = [];
    return {
      calls,
      detect: async (objectPath: string) => {
        calls.push(objectPath);
        return objectPath === mrzOn ? MRZ_OK : printed;
      },
    };
  }

  it('reads the BACK first, where the CEDEAO card prints its MRZ', async () => {
    // The regression this locks down: reading only the front returned an empty
    // file for every real card, with no error anywhere to say why.
    const d = detector(FACES.verso);
    const { outcome } = await readCard(FACES, d.detect);

    expect(outcome.status).toBe('ok');
    expect(outcome.cniNom).toBe('ERIKSSON');
    expect(d.calls).toEqual([FACES.verso]);
  });

  it('falls back to the front when the back carries no MRZ', async () => {
    // Other documents do print the zone on the front; a wrong assumption in
    // this file is what cost the previous attempt, so both are tried.
    const d = detector(FACES.recto);
    const { outcome } = await readCard(FACES, d.detect);

    expect(outcome.status).toBe('ok');
    expect(d.calls).toEqual([FACES.verso, FACES.recto]);
  });

  it('skips the second face ONLY on a perfect read', async () => {
    // That text is never stored, so reading it would be CPU spent on a result
    // the caller throws away one step later.
    const d = detector(FACES.verso);
    await readCard(FACES, d.detect);
    expect(d.calls).toEqual([FACES.verso]);
  });

  it('still reads the front when the back is only PARTIAL', async () => {
    // A zone with a failed check digit is precisely the case where a reviewer
    // wants the printed text of both sides to compare against.
    const calls: string[] = [];
    const { outcome, ocr } = await readCard(FACES, async (p) => {
      calls.push(p);
      return p === FACES.verso ? MRZ_PARTIAL : ['CARTE NATIONALE'];
    });

    expect(outcome.status).toBe('partial');
    expect(calls).toEqual([FACES.verso, FACES.recto]);
    expect(ocr.recto).toEqual(['CARTE NATIONALE']);
  });

  it('keeps the outcome of the face that carried the zone', async () => {
    // The front is read for its TEXT, never to silently replace the outcome.
    const { outcome } = await readCard(FACES, async (p) =>
      p === FACES.verso ? MRZ_PARTIAL : MRZ_OK
    );

    expect(outcome.status).toBe('partial');
    expect(outcome.mrzValid).toBe(false);
    expect(outcome.cniNom).toBe('ERIKSSON');
  });

  it('returns the text of every face it read', async () => {
    const { ocr } = await readCard(FACES, async (p) =>
      p === FACES.verso ? ['Nom: DIOP'] : ['Prenom: Amath']
    );

    expect(ocr.verso).toEqual(['Nom: DIOP']);
    expect(ocr.recto).toEqual(['Prenom: Amath']);
  });

  it('leaves the unread face empty after a perfect read', async () => {
    const { ocr } = await readCard(FACES, async (p) =>
      p === FACES.verso ? MRZ_OK : ['jamais lu']
    );

    expect(ocr.recto).toEqual([]);
  });

  it('reports a failure when neither face carries an MRZ', async () => {
    const d = detector(null);
    const { outcome } = await readCard(FACES, d.detect);

    expect(outcome.status).toBe('failed');
    expect(outcome.cniNumber).toBeNull();
    expect(d.calls).toEqual([FACES.verso, FACES.recto]);
    // Text WAS read, so this is "no zone found", not "not a document".
    expect(outcome.noReadableText).toBe(false);
  });

  it('flags "no text at all" only when BOTH faces are blank', async () => {
    // One blank side is ordinary. Deriving the signal from a single face would
    // accuse a perfectly good card of not being a document.
    const blankBack = async (p: string) =>
      p === FACES.verso ? [''] : ['CARTE NATIONALE'];
    expect((await readCard(FACES, blankBack)).outcome.noReadableText).toBe(false);

    const bothBlank = async () => ['', '  '];
    expect((await readCard(FACES, bothBlank)).outcome.noReadableText).toBe(true);
  });

  it('propagates a detector throw instead of swallowing it', async () => {
    // The caller turns that throw into "no face answered", which is what stops
    // an infrastructure failure from erasing text read on an earlier pass. And
    // the warning it logs is what made the September outage visible.
    await expect(
      readCard(FACES, async () => {
        throw new Error('vision down');
      })
    ).rejects.toThrow('vision down');
  });
});

describe('normalizeOcrLines', () => {
  it('keeps casing, inner spaces and reading order', () => {
    // The exact opposite of the MRZ path, and the reason this function exists:
    // a reviewer copies these values, so they must survive as printed.
    expect(
      normalizeOcrLines(['Nom: Amadou Ba', 'REPUBLIQUE', 'Ne le 15/01/1990'])
    ).toEqual(['Nom: Amadou Ba', 'REPUBLIQUE', 'Ne le 15/01/1990']);
  });

  it('keeps short lines, which carry the values a reviewer needs most', () => {
    // A first name, a date or a sex are all shorter than any MRZ line. The
    // diagnostic this replaces dropped everything under 15 characters.
    expect(normalizeOcrLines(['M', 'Awa', '15/01/1990'])).toEqual([
      'M',
      'Awa',
      '15/01/1990',
    ]);
  });

  it('drops blank lines and trims the edges', () => {
    expect(normalizeOcrLines(['  DIOP  ', '', '   '])).toEqual(['DIOP']);
  });

  it('marks a line cut at the character cap', () => {
    const [out] = normalizeOcrLines(['A'.repeat(200)], 200, 120);
    expect(out).toBe('A'.repeat(120) + OCR_TRUNCATED_SUFFIX);
  });

  it('keeps head AND tail past the line cap, with a sentinel', () => {
    // The machine zone sits at the BOTTOM of the card: keeping only the first
    // N lines would drop exactly the useful part.
    const many = Array.from({ length: 250 }, (_, i) => `ligne${i}`);
    const out = normalizeOcrLines(many, 10);

    expect(out).toHaveLength(11);
    expect(out[0]).toBe('ligne0');
    expect(out[4]).toBe('ligne4');
    expect(out[5]).toBe('[... 240 lignes omises ...]');
    expect(out[out.length - 1]).toBe('ligne249');
  });

  it('returns nothing for an empty read', () => {
    expect(normalizeOcrLines([])).toEqual([]);
    expect(normalizeOcrLines(['', '  '])).toEqual([]);
  });
});
