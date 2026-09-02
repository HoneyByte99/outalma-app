// getIdentityVerificationImages: staff-only, short-lived signed URLs for the
// admin review screen. The signer is a billed/emulator-absent dependency, so it
// runs behind a seam (setUrlSigner) that a test double replaces. These tests
// assert the access circle (moderator+), the not-found path, and that exactly
// the three stored object paths are signed.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({
  projectId: 'demo-outalma',
  storageBucket: 'demo-outalma.appspot.com',
});

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  INTERNAL_DOC,
  INTERNAL_SUB,
  VERIFICATIONS,
  IDENTITY_IMAGE_URL_TTL_MS,
  setUrlSigner,
  resetUrlSigner,
} from '../src/identity_verification';
import { clearFirestore } from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };

const db = () => admin.firestore();
const wrap = (fn: unknown) => tf.wrap(fn as never);

const OWNER = 'p1';
const VERIF = 'v1';
const BATCH = 'batch1234';

const ADMIN: Auth = { uid: 'boss', token: { admin: true } };
const MOD: Auth = { uid: 'mod', token: { moderator: true } };
const SUPPORT: Auth = { uid: 'sup', token: { support: true } };
const READONLY: Auth = { uid: 'ro', token: { readonly: true } };

const getImages = (data: unknown, auth?: Auth) =>
  wrap(fns.getIdentityVerificationImages)({ data, auth } as never);

async function expectCode(p: Promise<unknown>, code: string): Promise<void> {
  await expect(p).rejects.toMatchObject({ code });
}

const paths = (uid = OWNER, batch = BATCH) => ({
  recto: `private/identity/${uid}/${batch}/recto.jpg`,
  verso: `private/identity/${uid}/${batch}/verso.jpg`,
  selfie: `private/identity/${uid}/${batch}/selfie.jpg`,
});

const internalDoc = (id = VERIF) =>
  db().collection(VERIFICATIONS).doc(id).collection(INTERNAL_SUB).doc(INTERNAL_DOC);

async function seedInternal(
  id = VERIF,
  fields: Record<string, unknown> = {}
): Promise<void> {
  const p = paths();
  await internalDoc(id).set({
    providerId: OWNER,
    rectoPath: p.recto,
    versoPath: p.verso,
    selfiePath: p.selfie,
    ...fields,
  });
}

/// Records every path signed and returns a deterministic URL for it.
function recordingSigner(): {
  calls: Array<{ path: string; expiresAtMs: number }>;
} {
  const calls: Array<{ path: string; expiresAtMs: number }> = [];
  setUrlSigner({
    async sign(path: string, expiresAtMs: number): Promise<string> {
      calls.push({ path, expiresAtMs });
      return `https://signed.example/${encodeURIComponent(path)}`;
    },
  });
  return { calls };
}

beforeEach(async () => {
  await clearFirestore();
  resetUrlSigner();
});

afterAll(async () => {
  resetUrlSigner();
  tf.cleanup();
  await admin.firestore().terminate();
});

describe('getIdentityVerificationImages: access circle', () => {
  beforeEach(async () => {
    await seedInternal();
    recordingSigner();
  });

  it('rejects an unauthenticated caller', async () => {
    await expectCode(getImages({ verificationId: VERIF }), 'unauthenticated');
  });

  it('rejects support (below the identity circle)', async () => {
    await expectCode(
      getImages({ verificationId: VERIF }, SUPPORT),
      'permission-denied'
    );
  });

  it('rejects readonly', async () => {
    await expectCode(
      getImages({ verificationId: VERIF }, READONLY),
      'permission-denied'
    );
  });

  it('allows a moderator', async () => {
    await expect(
      getImages({ verificationId: VERIF }, MOD)
    ).resolves.toBeTruthy();
  });

  it('allows an admin', async () => {
    await expect(
      getImages({ verificationId: VERIF }, ADMIN)
    ).resolves.toBeTruthy();
  });
});

describe('getIdentityVerificationImages: contract', () => {
  it('signs exactly the three stored paths and returns their URLs', async () => {
    await seedInternal();
    const signer = recordingSigner();

    const before = Date.now();
    const res = (await getImages({ verificationId: VERIF }, MOD)) as {
      rectoUrl: string;
      versoUrl: string;
      selfieUrl: string;
    };
    const after = Date.now();

    const p = paths();
    expect(res.rectoUrl).toBe(
      `https://signed.example/${encodeURIComponent(p.recto)}`
    );
    expect(res.versoUrl).toBe(
      `https://signed.example/${encodeURIComponent(p.verso)}`
    );
    expect(res.selfieUrl).toBe(
      `https://signed.example/${encodeURIComponent(p.selfie)}`
    );

    const signedPaths = signer.calls.map((c) => c.path).sort();
    expect(signedPaths).toEqual([p.recto, p.selfie, p.verso].sort());

    // Every URL expires roughly IDENTITY_IMAGE_URL_TTL_MS from now (short-lived).
    for (const call of signer.calls) {
      expect(call.expiresAtMs).toBeGreaterThanOrEqual(
        before + IDENTITY_IMAGE_URL_TTL_MS
      );
      expect(call.expiresAtMs).toBeLessThanOrEqual(
        after + IDENTITY_IMAGE_URL_TTL_MS
      );
    }
  });

  it('rejects an unknown verificationId with not-found', async () => {
    recordingSigner();
    await expectCode(getImages({ verificationId: 'ghost' }, MOD), 'not-found');
  });

  it('rejects a verificationId with a path traversal segment', async () => {
    recordingSigner();
    await expectCode(
      getImages({ verificationId: '../secret' }, MOD),
      'invalid-argument'
    );
  });

  it('fails precondition when the stored paths are missing', async () => {
    // Internal doc exists but was written without the path fields.
    await internalDoc().set({ providerId: OWNER });
    recordingSigner();
    await expectCode(
      getImages({ verificationId: VERIF }, MOD),
      'failed-precondition'
    );
  });

  it('traces the access in admin_logs with no PII', async () => {
    await seedInternal();
    recordingSigner();
    await getImages({ verificationId: VERIF }, MOD);

    const logs = await db()
      .collection('admin_logs')
      .where('action', '==', 'view_identity_verification_images')
      .get();
    expect(logs.size).toBe(1);
    const entry = logs.docs[0]!.data();
    expect(entry.actorUid).toBe(MOD.uid);
    expect(entry.targetId).toBe(VERIF);
    // No extracted identity field is ever written to the log.
    const serialized = JSON.stringify(entry);
    expect(serialized).not.toContain('NDIAYE');
    expect(serialized).not.toContain('recto.jpg');
  });
});
