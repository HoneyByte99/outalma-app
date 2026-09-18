/**
 * Pure-function suite for the pieces that wire the in-process recogniser to the
 * stored image. No emulator, no network, no WebAssembly: what is tested here is
 * the URI split every recognition depends on, and the log summary that made the
 * 2026-09 outage visible in the first place.
 */
import {
  errorSummary,
  parseGcsUri,
  readFirstFaceWithMrz,
} from '../src/identity_verification';

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

describe('readFirstFaceWithMrz', () => {
  const FACES = { recto: 'p/recto.jpg', verso: 'p/verso.jpg' };

  // A TD1 with valid check digits, same fixture as the other identity suites.
  const MRZ_OK = [
    'I<UTOD231458907123456789012345',
    '7408122F1204159UTO67<<<<<<<<<9',
    'NDIAYE<<FATOU<<<<<<<<<<<<<<<<<',
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
    const out = await readFirstFaceWithMrz(FACES, d.detect);

    expect(out.status).toBe('ok');
    expect(out.cniNom).toBe('NDIAYE');
    expect(d.calls).toEqual([FACES.verso]);
  });

  it('falls back to the front when the back carries no MRZ', async () => {
    // Other documents do print the zone on the front; a wrong assumption in
    // this file is what cost the previous attempt, so both are tried.
    const d = detector(FACES.recto);
    const out = await readFirstFaceWithMrz(FACES, d.detect);

    expect(out.status).toBe('ok');
    expect(d.calls).toEqual([FACES.verso, FACES.recto]);
  });

  it('stops after one read, so a found MRZ costs a single pass', async () => {
    const d = detector(FACES.verso);
    await readFirstFaceWithMrz(FACES, d.detect);
    expect(d.calls).toHaveLength(1);
  });

  it('reports a failure when neither face carries an MRZ', async () => {
    const d = detector(null);
    const out = await readFirstFaceWithMrz(FACES, d.detect);

    expect(out.status).toBe('failed');
    expect(out.cniNumber).toBeNull();
    expect(d.calls).toEqual([FACES.verso, FACES.recto]);
    // Text WAS read, so this is "no zone found", not "not a document".
    expect(out.noReadableText).toBe(false);
  });

  it('flags "no text at all" only when BOTH faces are blank', async () => {
    // One blank side is ordinary. Deriving the signal from a single face would
    // accuse a perfectly good card of not being a document.
    const blankBack = {
      detect: async (p: string) => (p === FACES.verso ? [''] : ['CARTE NATIONALE']),
    };
    expect((await readFirstFaceWithMrz(FACES, blankBack.detect)).noReadableText).toBe(false);

    const bothBlank = { detect: async () => ['', '  '] };
    expect((await readFirstFaceWithMrz(FACES, bothBlank.detect)).noReadableText).toBe(true);
  });

  it('keeps a partial read instead of discarding it for the other face', async () => {
    // A failed check digit still means the zone was found: replacing those
    // fields with nothing would lose what the reviewer can correct.
    const brokenCheckDigit = [
      'I<UTOD231458907123456789012345',
      '7408122F1204159UTO67<<<<<<<<<0',
      'NDIAYE<<FATOU<<<<<<<<<<<<<<<<<',
    ];
    const calls: string[] = [];
    const out = await readFirstFaceWithMrz(FACES, async (p) => {
      calls.push(p);
      return p === FACES.verso ? brokenCheckDigit : MRZ_OK;
    });

    expect(out.status).toBe('partial');
    expect(out.mrzValid).toBe(false);
    expect(out.cniNom).toBe('NDIAYE');
    expect(calls).toEqual([FACES.verso]);
  });
});
