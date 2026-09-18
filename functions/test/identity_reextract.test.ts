// Staff-triggered second read of an identity file. The guards matter most: the
// callable replays a recognition on a stored image, so who may fire it, on which
// file, and how many times are the whole contract. Admin SDK path, so the rules
// are bypassed by design and covered by identity_rules.test.ts.
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
  MAX_EXTRACTION_RUNS,
  VERIFICATIONS,
} from '../src/identity_verification';
import * as identity from '../src/identity_verification';
import { clearFirestore, createAuthUser } from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };

const db = () => admin.firestore();
const wrap = (fn: unknown) => tf.wrap(fn as never);

const OWNER = 'p1';
const VERIF = 'v1';
const BATCH = 'batch1234';

const ADMIN: Auth = { uid: 'boss', token: { admin: true } };
const MOD: Auth = { uid: 'mod', token: { moderator: true } };
const SUPPORT: Auth = { uid: 'sup', token: { support: true } };
const PROVIDER: Auth = { uid: OWNER, token: {} };

// A TD1 with valid check digits carrying a 17-digit number across the two
// optional data blocks, same shape as the other identity suites.
const MRZ_OK = [
  'I<UTOD231458907123456789012345',
  '7408122F1204159UTO67<<<<<<<<<9',
  'NDIAYE<<FATOU<<<<<<<<<<<<<<<<<',
];

const reextract = (data: unknown, auth: Auth | undefined) =>
  wrap(fns.reextractIdentityVerification)({ data, auth } as never);

async function expectCode(promise: Promise<unknown>, code: string): Promise<void> {
  await expect(promise).rejects.toMatchObject({ code });
}

const verifDoc = (id = VERIF) => db().collection(VERIFICATIONS).doc(id);
const internalDoc = (id = VERIF) =>
  verifDoc(id).collection(INTERNAL_SUB).doc(INTERNAL_DOC);

const rectoPath = `private/identity/${OWNER}/${BATCH}/recto.jpg`;
const versoPath = `private/identity/${OWNER}/${BATCH}/verso.jpg`;

/// Counts its calls, so "one recognition per click" and "none once the ceiling
/// is reached" are observed rather than asserted.
function countingExtractor(lines: string[]) {
  const calls: string[] = [];
  return {
    calls,
    double: {
      async detect(uri: string): Promise<string[]> {
        calls.push(uri);
        return lines;
      },
    },
  };
}

/// A file whose automatic extraction produced nothing: the exact state this
/// callable exists to get out of.
async function seedFailedFile(status = 'pending'): Promise<void> {
  for (const p of [rectoPath, versoPath]) {
    await admin
      .storage()
      .bucket()
      .file(p)
      .save(Buffer.from(`bytes-${p}`), { contentType: 'image/jpeg' });
  }

  await verifDoc().set({
    providerId: OWNER,
    batchId: BATCH,
    status,
    attempt: 1,
    priority: false,
    extractionStatus: 'failed',
    cniNumber: null,
    cniNom: null,
    cniPrenom: null,
    cniDateNaissance: null,
    cniDateExpiration: null,
    cniSexe: null,
    mrzValid: false,
    rejectionReason: null,
    submittedAt: admin.firestore.Timestamp.now(),
    reviewedAt: null,
  });
  await internalDoc().set({
    providerId: OWNER,
    rectoPath,
    versoPath,
    selfiePath: `private/identity/${OWNER}/${BATCH}/selfie.jpg`,
    cniNumberKey: null,
    doublonPotentiel: false,
    doublonReferenceId: null,
    mrzRaw: null,
    reviewedBy: null,
  });
}

beforeEach(async () => {
  await clearFirestore();
  await admin.storage().bucket().deleteFiles({ prefix: 'private/identity/' });
  identity.resetTextExtractor();
  await createAuthUser(OWNER);
});

afterAll(() => {
  identity.resetTextExtractor();
  tf.cleanup();
});

describe('who may ask for a second read', () => {
  beforeEach(() => seedFailedFile());

  it('refuses an unauthenticated caller', async () => {
    await expectCode(reextract({ verificationId: VERIF }, undefined), 'unauthenticated');
  });

  it('refuses a provider, even the owner of the file', async () => {
    await expectCode(reextract({ verificationId: VERIF }, PROVIDER), 'permission-denied');
  });

  it('refuses support, which never sees identity images', async () => {
    await expectCode(reextract({ verificationId: VERIF }, SUPPORT), 'permission-denied');
  });

  it('refuses an id that could escape the collection', async () => {
    await expectCode(reextract({ verificationId: 'a/b' }, ADMIN), 'invalid-argument');
  });

  it('refuses a file that does not exist', async () => {
    await expectCode(reextract({ verificationId: 'ghost' }, ADMIN), 'not-found');
  });
});

describe('what a second read does', () => {
  it('fills the fields a failed extraction left empty', async () => {
    await seedFailedFile();
    const { calls, double } = countingExtractor(MRZ_OK);
    identity.setTextExtractor(double);

    const res = await reextract({ verificationId: VERIF }, MOD);

    expect(res).toMatchObject({ verificationId: VERIF, extractionStatus: 'ok' });
    // Exactly one recognition per click: the pass is not free of CPU.
    expect(calls).toHaveLength(1);
    expect(calls[0]).toContain(versoPath);

    const data = (await verifDoc().get()).data() ?? {};
    expect(data.extractionStatus).toBe('ok');
    expect(data.cniNom).toBe('NDIAYE');
    expect(data.cniPrenom).toBe('FATOU');
    expect(data.mrzValid).toBe(true);

    const internal = (await internalDoc().get()).data() ?? {};
    expect(internal.cniNumberKey).toBe('12345678901234567');
    expect(internal.extractionRuns).toBe(1);
  });

  it('traces the staff action, with no identity data in the entry', async () => {
    await seedFailedFile();
    identity.setTextExtractor(countingExtractor(MRZ_OK).double);

    await reextract({ verificationId: VERIF }, MOD);

    const logs = await db()
      .collection('admin_logs')
      .where('action', '==', 'reextract_identity_verification')
      .get();
    expect(logs.size).toBe(1);
    const entry = logs.docs[0]?.data() ?? {};
    expect(entry.actorUid).toBe(MOD.uid);
    expect(entry.targetType).toBe('identity_verification');
    expect(entry.targetId).toBe(VERIF);
    // The entry outlives the account, so it carries no card number and no name.
    expect(JSON.stringify(entry)).not.toContain('NDIAYE');
    expect(JSON.stringify(entry)).not.toContain('12345678901234567');
  });

  it('reports a failure without hiding it behind a fake success', async () => {
    await seedFailedFile();
    identity.setTextExtractor({
      async detect(): Promise<string[]> {
        return ['pas une carte'];
      },
    });

    const res = await reextract({ verificationId: VERIF }, ADMIN);

    expect(res).toMatchObject({ extractionStatus: 'failed' });
    const data = (await verifDoc().get()).data() ?? {};
    expect(data.extractionStatus).toBe('failed');
    expect(data.cniNumber).toBeNull();
  });
});

describe('what a second read refuses to touch', () => {
  it('refuses a file already decided, so a verdict is never overwritten', async () => {
    await seedFailedFile('approved');
    const { calls, double } = countingExtractor(MRZ_OK);
    identity.setTextExtractor(double);

    await expectCode(reextract({ verificationId: VERIF }, ADMIN), 'failed-precondition');
    // Refused BEFORE the recognition, not after: the ceiling exists to stop
    // work, not to record it.
    expect(calls).toHaveLength(0);
  });

  it('stops at the ceiling instead of looping on our own bill', async () => {
    await seedFailedFile();
    await internalDoc().update({ extractionRuns: MAX_EXTRACTION_RUNS });
    const { calls, double } = countingExtractor(MRZ_OK);
    identity.setTextExtractor(double);

    await expectCode(reextract({ verificationId: VERIF }, ADMIN), 'resource-exhausted');
    expect(calls).toHaveLength(0);
  });

  it('counts every run, so the ceiling is actually reachable', async () => {
    await seedFailedFile();
    identity.setTextExtractor(countingExtractor(MRZ_OK).double);

    for (let i = 1; i <= MAX_EXTRACTION_RUNS; i++) {
      await reextract({ verificationId: VERIF }, ADMIN);
      expect((await internalDoc().get()).data()?.extractionRuns).toBe(i);
    }
    await expectCode(reextract({ verificationId: VERIF }, ADMIN), 'resource-exhausted');
  });

  it('refuses when the stored image path is missing', async () => {
    await seedFailedFile();
    await internalDoc().update({ versoPath: admin.firestore.FieldValue.delete() });

    await expectCode(reextract({ verificationId: VERIF }, ADMIN), 'failed-precondition');
  });
});
