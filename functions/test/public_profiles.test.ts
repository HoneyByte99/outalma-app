// Public profile projection: pure projection logic + the mirrorPublicProfile
// trigger and backfillPublicProfiles admin callable.
//
// The invariant under test: ONLY non-PII display fields (displayName,
// photoPath, country, phoneVerified boolean, gender) reach public_profiles;
// email and phoneE164 must never leak into the world-readable collection.
// `gender` was added deliberately, is value-checked against the two canonical
// strings rather than merely type-checked, and is the only key ever added.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import {
  isValidAvatarId,
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

  it('projects the declared gender, both values', () => {
    // The catalogue card and the service detail are guest surfaces and resolve
    // their provider through this document, so a gender that stopped here
    // would never be drawn.
    expect(projectPublicProfile({ displayName: 'Awa', gender: 'female' })).toEqual(
      { displayName: 'Awa', phoneVerified: false, gender: 'female' }
    );
    expect(projectPublicProfile({ displayName: 'Moussa', gender: 'male' })).toEqual(
      { displayName: 'Moussa', phoneVerified: false, gender: 'male' }
    );
  });

  it('omits gender when the source has none (every account today)', () => {
    const proj = projectPublicProfile({
      displayName: 'Awa',
    }) as unknown as Record<string, unknown>;
    expect('gender' in proj).toBe(false);
  });

  it('DROPS a gender outside the two canonical values', () => {
    // Value-checked, not merely type-checked. The 2024 FlutterFlow export used
    // this exact key with another vocabulary, and a client can write the field
    // itself. Anything else must not reach a world-readable document that the
    // interface turns into a pictogram.
    for (const bad of ['Male', 'FEMALE', 'homme', 'other', '', 42, null, {}]) {
      const proj = projectPublicProfile({
        displayName: 'Awa',
        gender: bad,
      }) as unknown as Record<string, unknown>;
      expect('gender' in proj).toBe(false);
    }
  });

  it('is an ALLOWLIST: a field added to users later never reaches it', () => {
    // The regression that matters. Every key of this collection is world
    // readable, so the projection must be built key by key. A denylist would
    // silently publish the next sensitive field someone adds to `users`, and
    // nobody would notice until it was indexed.
    const proj = projectPublicProfile({
      displayName: 'Awa',
      nationalId: 'SN-1234567',
      homeAddress: '12 rue des Lilas',
      ipAddress: '81.2.3.4',
      dateOfBirth: '1990-04-02',
      // Off-grammar on purpose: without it this test would be VACANT for
      // avatarId, passing while proving nothing about the field the increment
      // adds. With it, the same assertion covers both properties.
      avatarId: '../../etc/passwd',
    }) as unknown as Record<string, unknown>;
    expect(Object.keys(proj).sort()).toEqual(['displayName', 'phoneVerified']);
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
    expect(
      projectionsEqual(base, { displayName: 'A', gender: 'male', phoneVerified: false })
    ).toBe(false);
  });

  it('detects a gender CHANGE, so the mirror is not skipped', () => {
    // The comparison is the write filter. A gender missing from it means the
    // first user to correct their declaration never sees the public card update.
    expect(
      projectionsEqual(
        { displayName: 'A', gender: 'male', phoneVerified: false },
        { displayName: 'A', gender: 'female', phoneVerified: false }
      )
    ).toBe(false);
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

  it('mirrors a gender correction to the public document', async () => {
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, { displayName: 'Awa', gender: 'male' })
    );
    expect((await publicProfile('u1'))?.gender).toBe('male');

    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(
        { displayName: 'Awa', gender: 'male' },
        { displayName: 'Awa', gender: 'female' }
      )
    );
    expect((await publicProfile('u1'))?.gender).toBe('female');
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

// ---------------------------------------------------------------------------
// isValidAvatarId: a pure grammar check, so a table of cases, each refusal
// proving one NAMED thing.
// ---------------------------------------------------------------------------
describe('isValidAvatarId', () => {
  const accepted = [
    'human_afro1_t2',
    'human_a_t1',
    'human_afro1_t6',
    'animal_blob1',
    'animal_z9',
    'human_abcdefghij0123456789', // the 20-character bound
    'animal_0', // the 1-character bound
  ];
  it.each(accepted)('accepts %s', (value) => {
    expect(isValidAvatarId(value)).toBe(true);
  });

  const refused: [string, unknown][] = [
    ['empty', ''],
    ['undefined', undefined],
    ['null', null],
    ['a number', 42],
    ['a boolean', true],
    // Firestore stores both of these happily, so the type check is not
    // theoretical.
    ['an object', { tone: 3 }],
    ['an array', ['human_afro1_t2']],
    ['uppercase, refused and NOT normalised', 'Human_afro1_t2'],
    ['tone 0, below the closed range', 'human_afro1_t0'],
    ['tone 7, above the closed range', 'human_afro1_t7'],
    ['a repeated tone suffix', 'human_afro1_t2_t2'],
    ['an unknown family', 'robot_afro1'],
    ['an empty slug', 'human_'],
    ['a leading space', ' human_afro1_t2'],
    ['a trailing space', 'human_afro1_t2 '],
    // The money cases: this is where a reviewer looks.
    ['a path traversal', 'human_../../etc/passwd'],
    ['an encoded traversal', 'human_..%2f..%2fetc'],
    ['a slash in the slug', 'animal_a/b'],
    ['a 21-character slug', 'human_abcdefghij01234567890'],
  ];
  it.each(refused)('refuses %s', (_reason, value) => {
    expect(isValidAvatarId(value)).toBe(false);
  });

  it('refuses a trailing newline, so the `m` flag can never be added', () => {
    // Corrected after a mutation pass caught the comment that used to sit
    // here, which claimed that in JavaScript `$` without the `m` flag still
    // matches before a trailing newline. That is Python. In JavaScript
    // /^abc$/.test("abc\n") is FALSE, verified in node, which is why the
    // source now uses the plain `$` instead of a `(?![\s\S])` terminator
    // defended by a false reason.
    //
    // The test keeps its value all the same: adding the `m` flag WOULD make
    // this pass, and that is the one change that would break agreement with
    // the RE2 whole-string `matches()` in firestore.rules. Mutating the
    // pattern to `/.../m` turns THIS red and nothing else.
    expect(isValidAvatarId('human_afro1_t2\n')).toBe(false);
  });

  it('refuses an oversized value', () => {
    expect(isValidAvatarId('human_' + 'a'.repeat(5000))).toBe(false);
  });

  it('answers the same on two consecutive calls', () => {
    // Locks out the `g` flag forever: RegExp.prototype.test with `g` is
    // stateful through lastIndex and alternates its answer.
    expect(isValidAvatarId('animal_blob1')).toBe(true);
    expect(isValidAvatarId('animal_blob1')).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// The avatar through the projection and the trigger.
// ---------------------------------------------------------------------------
describe('projectPublicProfile: illustrated avatar', () => {
  it('projects a well-formed token', () => {
    const proj = projectPublicProfile({
      displayName: 'Awa',
      avatarId: 'human_afro1_t2',
    });
    expect(proj).toEqual({
      displayName: 'Awa',
      phoneVerified: false,
      avatarId: 'human_afro1_t2',
    });
  });

  it('OMITS an off-grammar value', () => {
    const proj = projectPublicProfile({
      displayName: 'Awa',
      avatarId: '../../etc/passwd',
    }) as unknown as Record<string, unknown>;
    // Both assertions on purpose: expect({a:1,b:undefined}).toEqual({a:1})
    // PASSES in Jest, so toEqual alone would be a weaker claim than it looks.
    expect(proj).toEqual({ displayName: 'Awa', phoneVerified: false });
    expect(proj).not.toHaveProperty('avatarId');
  });

  it.each([[42], [{ tone: 3 }], [null], [['human_afro1_t2']]])(
    'OMITS a non-string value (%p)',
    (bad) => {
      const proj = projectPublicProfile({
        displayName: 'Awa',
        avatarId: bad,
      }) as unknown as Record<string, unknown>;
      expect(proj).not.toHaveProperty('avatarId');
    }
  );

  it('projects a photo AND an avatar when both are present', () => {
    // The client keeps them mutually exclusive, so this is a robustness case
    // for documents written before that rule or by the Admin SDK. Publishing
    // both also means the display precedence can change later without a data
    // migration.
    const proj = projectPublicProfile({
      displayName: 'Awa',
      photoPath: 'https://example.test/a.jpg',
      avatarId: 'human_afro1_t2',
    });
    expect(proj).toEqual({
      displayName: 'Awa',
      phoneVerified: false,
      photoPath: 'https://example.test/a.jpg',
      avatarId: 'human_afro1_t2',
    });
  });
});

describe('projectionsEqual: illustrated avatar', () => {
  const base = { displayName: 'Awa', phoneVerified: false };

  it('is false when only the avatar differs', () => {
    expect(
      projectionsEqual(
        { ...base, avatarId: 'human_afro1_t2' },
        { ...base, avatarId: 'animal_blob1' }
      )
    ).toBe(false);
  });

  it('is false when the avatar is present on one side only', () => {
    expect(
      projectionsEqual({ ...base, avatarId: 'human_afro1_t2' }, { ...base })
    ).toBe(false);
    expect(
      projectionsEqual({ ...base }, { ...base, avatarId: 'human_afro1_t2' })
    ).toBe(false);
  });

  it('is true when the avatar is the same', () => {
    expect(
      projectionsEqual(
        { ...base, avatarId: 'human_afro1_t2' },
        { ...base, avatarId: 'human_afro1_t2' }
      )
    ).toBe(true);
  });
});

describe('mirrorPublicProfile: illustrated avatar', () => {
  it('publishes a catalogue token', async () => {
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, { displayName: 'Awa', avatarId: 'human_afro1_t2' })
    );
    expect(await publicProfile('u1')).toEqual({
      displayName: 'Awa',
      phoneVerified: false,
      avatarId: 'human_afro1_t2',
    });
  });

  it('NEVER publishes an off-grammar token', async () => {
    // The end-to-end proof that the PROJECTION is the last gate, not the rule:
    // tf.wrap on a fabricated snapshot IS a write that bypasses firestore
    // rules, exactly like the Admin SDK does.
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, {
        displayName: 'Awa',
        avatarId: 'human_../../etc/passwd',
      })
    );
    const doc = await publicProfile('u1');
    expect(doc).toEqual({ displayName: 'Awa', phoneVerified: false });
    expect(doc).not.toHaveProperty('avatarId');
  });

  it('REWRITES the public document when ONLY the avatar changes', async () => {
    // Without the avatarId line in projectionsEqual this test fails, and
    // nothing else does: the trigger would short-circuit, the avatar would
    // never reach any guest surface, and the suite would stay green. The
    // marker technique is borrowed from the pushToken test above, inverted.
    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(undefined, { displayName: 'Awa', avatarId: 'human_afro1_t2' })
    );
    await db()
      .collection('public_profiles')
      .doc('u1')
      .set({ marker: 'untouched' }, { merge: true });

    await tf.wrap(fns.mirrorPublicProfile)(
      writeEvent(
        { displayName: 'Awa', avatarId: 'human_afro1_t2' },
        { displayName: 'Awa', avatarId: 'animal_blob1' }
      )
    );

    const doc = await publicProfile('u1');
    expect(doc?.avatarId).toBe('animal_blob1');
    // The full set() swept the marker away, which is what proves a rewrite
    // actually happened rather than a no-op.
    expect(doc).not.toHaveProperty('marker');
  });

  it('removes the avatar from the public document when the user drops it',
    async () => {
      await tf.wrap(fns.mirrorPublicProfile)(
        writeEvent(undefined, {
          displayName: 'Awa',
          avatarId: 'human_afro1_t2',
        })
      );
      await tf.wrap(fns.mirrorPublicProfile)(
        writeEvent(
          { displayName: 'Awa', avatarId: 'human_afro1_t2' },
          { displayName: 'Awa' }
        )
      );
      const doc = await publicProfile('u1');
      expect(doc).not.toHaveProperty('avatarId');
    });

  it('is idempotent on a REPLAY of the same event', async () => {
    // Triggers replay, it is a fact of the platform (budget line D5), and this
    // file had no replay test at all. The projection is deterministic and the
    // write is a full set(), so a replay must be a no-op.
    const event = writeEvent(undefined, {
      displayName: 'Awa',
      avatarId: 'human_afro1_t2',
    });
    await tf.wrap(fns.mirrorPublicProfile)(event);
    const first = await publicProfile('u1');
    await tf.wrap(fns.mirrorPublicProfile)(event);
    expect(await publicProfile('u1')).toEqual(first);
  });
});
