/**
 * Pure-function suite for the pieces that wire the in-process recogniser to the
 * stored image. No emulator, no network, no WebAssembly: what is tested here is
 * the URI split every recognition depends on, and the log summary that made the
 * 2026-09 outage visible in the first place.
 */
import { errorSummary, parseGcsUri } from '../src/identity_verification';

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
