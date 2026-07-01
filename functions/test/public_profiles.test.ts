// Public profile projection: pure projection logic + the mirrorPublicProfile
// trigger and backfillPublicProfiles admin callable.
//
// The invariant under test: ONLY non-PII display fields (displayName,
// photoPath, country, phoneVerified boolean) reach public_profiles; email and
// phoneE164 must never leak into the world-readable collection.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import {
  projectPublicProfile,
  projectionsEqual,
} from '../src/public_profiles';
import * as admin from 'firebase-admin';
import { clearFirestore } from './helpers';

const db = () => admin.firestore();

type Auth = { uid: string; token?: Record<string, unknown> };

function call(fn: unknown, data: unknown, auth?: Auth): Promise<unknown> {
  return tf.wrap(fn as never)({ data, auth } as never);
}

function userSnapshot(data: Record<string, unknown> | undefined, uid = 'u1') {
  return tf.firestore.makeDocumentSnapshot(data ?? {}, `users/${uid}`);
}

function writeEvent(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
  uid = 'u1'
) {
  const change = tf.makeChange(userSnapshot(before, uid), userSnapshot(after, uid));
  return { data: change, params: { uid }, id: `evt-${uid}` } as never;
}

async function publicProfile(uid: string) {
  return (await db().collection('public_profiles').doc(uid).get()).data();
}

beforeEach(async () => {
  await clearFirestore();
});
afterAll(async () => {
  tf.cleanup();
  await admin.firestore().terminate();
});

// ---------------------------------------------------------------------------
// Pure projection logic
// ---------------------------------------------------------------------------
describe('projectPublicProfile', () => {
  it('keeps only non-PII display fields, dropping email + phoneE164', () => {
    const proj = projectPublicProfile({
      displayName: 'Awa',
      photoPath: 'avatars/a.jpg',
      country: 'SN',
      email: 'awa@example.com',
      phoneE164: '+221770000000',
      pushToken: 'tok',
    });
    expect(proj).toEqual({
      displayName: 'Awa',
      photoPath: 'avatars/a.jpg',
      country: 'SN',
      phoneVerified: true,
    });
  });

  it('phoneVerified is false when no phone number is on file', () => {
    expect(projectPublicProfile({ displayName: 'Awa' })).toEqual({
      displayName: 'Awa',
      phoneVerified: false,
    });
  });

  it('omits photoPath/country when absent or empty', () => {
    expect(
      projectPublicProfile({ displayName: 'Awa', photoPath: '', country: '' })
    ).toEqual({ displayName: 'Awa', phoneVerified: false });
  });

  it('falls back to empty displayName when missing or non-string', () => {
    expect(projectPublicProfile({})).toEqual({
      displayName: '',
      phoneVerified: false,
    });
    expect(projectPublicProfile({ displayName: 42 })).toEqual({
      displayName: '',
      phoneVerified: false,
    });
  });

  it('returns null for an absent (deleted) user', () => {
    expect(projectPublicProfile(undefined)).toBeNull();
  });
});

describe('projectionsEqual', () => {
  it('treats identical projections as equal', () => {
    expect(
      projectionsEqual(
        { displayName: 'A', photoPath: 'p', country: 'FR', phoneVerified: true },
        { displayName: 'A', photoPath: 'p', country: 'FR', phoneVerified: true }
      )
    ).toBe(true);
  });

  it('detects any projected-field difference', () => {
    const base = { displayName: 'A', phoneVerified: false };
    expect(projectionsEqual(base, { displayName: 'B', phoneVerified: false })).toBe(false);
    expect(
      projectionsEqual(base, { displayName: 'A', photoPath: 'p', phoneVerified: false })
    ).toBe(false);
    expect(
      projectionsEqual(base, { displayName: 'A', country: 'SN', phoneVerified: false })
    ).toBe(false);
    expect(projectionsEqual(base, { displayName: 'A', phoneVerified: true })).toBe(false);
  });

  it('handles nulls (create / delete edges)', () => {
    expect(projectionsEqual(null, null)).toBe(true);
    expect(projectionsEqual(null, { displayName: 'A', phoneVerified: false })).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// mirrorPublicProfile trigger
// ---------------------------------------------------------------------------
describe('mirrorPublicProfile', () => {
  it('creates a PII-free projection on user create', async () => {
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, {
        displayName: 'Awa',
        photoPath: 'avatars/a.jpg',
        country: 'SN',
        email: 'awa@example.com',
        phoneE164: '+221770000000',
      })
    );
    const p = await publicProfile('u1');
    expect(p).toEqual({
      displayName: 'Awa',
      photoPath: 'avatars/a.jpg',
      country: 'SN',
      phoneVerified: true,
    });
    expect(p).not.toHaveProperty('email');
    expect(p).not.toHaveProperty('phoneE164');
  });

  it('updates the projection when displayName changes', async () => {
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, { displayName: 'Old' })
    );
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent({ displayName: 'Old' }, { displayName: 'New' })
    );
    expect((await publicProfile('u1'))?.displayName).toBe('New');
  });

  it('drops photoPath from the public doc when the user removes it', async () => {
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, { displayName: 'Awa', photoPath: 'avatars/a.jpg' })
    );
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(
        { displayName: 'Awa', photoPath: 'avatars/a.jpg' },
        { displayName: 'Awa' }
      )
    );
    expect(await publicProfile('u1')).toEqual({
      displayName: 'Awa',
      phoneVerified: false,
    });
  });

  it('does not rewrite when only PII changed (projection unchanged)', async () => {
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, { displayName: 'Awa', email: 'a@x.com' })
    );
    // Manually mark the doc so we can detect an unwanted overwrite.
    await db().collection('public_profiles').doc('u1').set({
      displayName: 'Awa',
      phoneVerified: false,
      marker: 'untouched',
    });
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(
        { displayName: 'Awa', email: 'a@x.com' },
        { displayName: 'Awa', email: 'new@x.com' }
      )
    );
    expect((await publicProfile('u1'))?.marker).toBe('untouched');
  });

  it('rewrites when phoneVerified flips (phone number added)', async () => {
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, { displayName: 'Awa' })
    );
    expect((await publicProfile('u1'))?.phoneVerified).toBe(false);
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(
        { displayName: 'Awa' },
        { displayName: 'Awa', phoneE164: '+221770000000' }
      )
    );
    expect((await publicProfile('u1'))?.phoneVerified).toBe(true);
  });

  it('deletes the projection when the user is deleted', async () => {
    await db().collection('public_profiles').doc('u1').set({
      displayName: 'Awa',
      phoneVerified: false,
    });
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent({ displayName: 'Awa' }, undefined)
    );
    expect(await publicProfile('u1')).toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// backfillPublicProfiles callable
// ---------------------------------------------------------------------------
describe('backfillPublicProfiles', () => {
  it('mirrors every user, stripping PII, for an admin caller', async () => {
    await db().collection('users').doc('u1').set({
      displayName: 'Awa',
      photoPath: 'avatars/a.jpg',
      country: 'SN',
      email: 'awa@example.com',
      phoneE164: '+221770000000',
    });
    await db().collection('users').doc('u2').set({ displayName: 'Bou' });

    const res = (await call(fns.backfillPublicProfiles, {}, {
      uid: 'boss',
      token: { admin: true },
    })) as { written: number };

    expect(res.written).toBe(2);
    expect(await publicProfile('u1')).toEqual({
      displayName: 'Awa',
      photoPath: 'avatars/a.jpg',
      country: 'SN',
      phoneVerified: true,
    });
    expect(await publicProfile('u2')).toEqual({
      displayName: 'Bou',
      phoneVerified: false,
    });
  });

  it('rejects a non-admin caller', async () => {
    await expect(
      call(fns.backfillPublicProfiles, {}, { uid: 'nobody' })
    ).rejects.toMatchObject({ code: expect.stringContaining('permission-denied') });
  });

  it('rejects an unauthenticated caller', async () => {
    await expect(
      call(fns.backfillPublicProfiles, {})
    ).rejects.toMatchObject({ code: expect.stringContaining('unauthenticated') });
  });
});
