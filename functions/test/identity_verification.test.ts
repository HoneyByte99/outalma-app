// Submission callable: guards, idempotence, rate limit, extraction, duplicates.
// Admin SDK path, so the security rules are bypassed here by design; the rules
// themselves are covered by identity_rules.test.ts and identity_storage_rules.test.ts.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({
  projectId: 'demo-outalma',
  storageBucket: 'demo-outalma.appspot.com',
});

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  resetTextExtractor,
  setTextExtractor,
  verificationDocId,
  INTERNAL_SUB,
  INTERNAL_DOC,
  STATES,
  VERIFICATIONS,
} from '../src/identity_verification';
import * as identity from '../src/identity_verification';
import { clearFirestore, seedUser } from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };

const db = () => admin.firestore();
const wrap = (fn: unknown) => tf.wrap(fn as never);

const OWNER = 'p1';
const OTHER = 'p2';
const BATCH = 'batch1234';

// A TD1 with valid check digits, carrying a 17-digit number across the two
// optional data blocks. Same shape as the extraction unit tests.
const MRZ_OK = [
  'I<UTOD231458907123456789012345',
  '7408122F1204159UTO67<<<<<<<<<9',
  'NDIAYE<<FATOU<<<<<<<<<<<<<<<<<',
];
const MRZ_NUMBER = '12345678901234567';

/// Counts its calls, so "one extraction per file" and "no extraction beyond the
/// rate limit" become observable rather than asserted.
function extractorReturning(lines: string[]) {
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

async function uploadBatch(uid: string, batchId: string): Promise<void> {
  const bucket = admin.storage().bucket();
  for (const name of ['recto.jpg', 'verso.jpg', 'selfie.jpg']) {
    await bucket
      .file(`private/identity/${uid}/${batchId}/${name}`)
      .save(Buffer.from(`bytes-${name}`), { contentType: 'image/jpeg' });
  }
}

async function clearStorage(): Promise<void> {
  await admin.storage().bucket().deleteFiles({ prefix: 'private/identity/' });
}

const submit = (data: unknown, auth: Auth) =>
  wrap(fns.submitIdentityVerification)({ data, auth } as never);

const verifDoc = (id: string) => db().collection(VERIFICATIONS).doc(id);
const internalDoc = (id: string) =>
  verifDoc(id).collection(INTERNAL_SUB).doc(INTERNAL_DOC);

beforeEach(async () => {
  await clearFirestore();
  await clearStorage();
  resetTextExtractor();
  // A submission now requires the account to still exist, which is what closes
  // the window where a deletion in flight could be outrun.
  await seedUser(OWNER);
  await seedUser(OTHER);
});

afterAll(() => {
  resetTextExtractor();
  tf.cleanup();
});

describe('submitIdentityVerification: entry contract', () => {
  it('refuses an unauthenticated caller', async () => {
    await expect(submit({ batchId: BATCH }, undefined as never)).rejects.toThrow(
      /unauthenticated|Authentication/i
    );
  });

  it('refuses a batch id that could escape the prefix', async () => {
    for (const bad of ['../../etc', 'aaaa/bbbb', 'short', 'abcdefgh\n', '', 42]) {
      await expect(submit({ batchId: bad }, { uid: OWNER })).rejects.toThrow(
        /invalid-argument|batchId/i
      );
    }
  });

  it('refuses when the three objects are not all there', async () => {
    const bucket = admin.storage().bucket();
    await bucket
      .file(`private/identity/${OWNER}/${BATCH}/recto.jpg`)
      .save(Buffer.from('x'), { contentType: 'image/jpeg' });

    await expect(submit({ batchId: BATCH }, { uid: OWNER })).rejects.toThrow(
      /invalid-argument|introuvables/i
    );
  });

  it('cannot reach another provider objects, since the prefix comes from the uid', async () => {
    // OTHER uploaded a batch; OWNER submits the same batch id. The prefix is
    // rebuilt from the AUTHENTICATED uid, so it resolves under OWNER, where
    // nothing exists.
    await uploadBatch(OTHER, BATCH);

    await expect(submit({ batchId: BATCH }, { uid: OWNER })).rejects.toThrow(
      /invalid-argument|introuvables/i
    );
  });
});

describe('submitIdentityVerification: the happy path', () => {
  it('creates a pending file whose fields come from the server', async () => {
    const { double, calls } = extractorReturning(MRZ_OK);
    setTextExtractor(double);
    await uploadBatch(OWNER, BATCH);

    const res = (await submit(
      // The client also sends field values and a verdict. Both are ignored.
      { batchId: BATCH, cniNumber: 'FORGED', status: 'approved' },
      { uid: OWNER }
    )) as { verificationId: string; alreadySubmitted: boolean };

    const id = verificationDocId(OWNER, BATCH);
    expect(res.verificationId).toBe(id);
    expect(res.alreadySubmitted).toBe(false);
    expect(calls).toHaveLength(1);

    const data = (await verifDoc(id).get()).data();
    expect(data?.status).toBe('pending');
    expect(data?.providerId).toBe(OWNER);
    expect(data?.attempt).toBe(1);
    expect(data?.priority).toBe(false);
    expect(data?.cniNumber).not.toBe('FORGED');
    expect(data?.cniNom).toBe('NDIAYE');
    expect(data?.extractionStatus).not.toBe('pending');

    const internal = (await internalDoc(id).get()).data();
    expect(internal?.rectoPath).toBe(
      `private/identity/${OWNER}/${BATCH}/recto.jpg`
    );
    // Paths, never a tokenised download URL.
    expect(JSON.stringify(internal)).not.toContain('https://');
    expect(internal?.rectoGeneration).toBeTruthy();
    expect(internal?.rectoMd5).toBeTruthy();
  });

  it('records the file even when extraction fails entirely', async () => {
    setTextExtractor({
      async detect() {
        throw new Error('vision is down');
      },
    });
    await uploadBatch(OWNER, BATCH);

    await submit({ batchId: BATCH }, { uid: OWNER });

    const data = (await verifDoc(verificationDocId(OWNER, BATCH)).get()).data();
    expect(data?.status).toBe('pending');
    expect(data?.extractionStatus).toBe('failed');
    expect(data?.cniNumber).toBeNull();
    expect(data?.mrzValid).toBe(false);
  });
});

describe('submitIdentityVerification: idempotence and state guards', () => {
  it('returns the same file on replay, without a second extraction', async () => {
    const { double, calls } = extractorReturning(MRZ_OK);
    setTextExtractor(double);
    await uploadBatch(OWNER, BATCH);

    const first = (await submit({ batchId: BATCH }, { uid: OWNER })) as {
      verificationId: string;
    };
    const second = (await submit({ batchId: BATCH }, { uid: OWNER })) as {
      verificationId: string;
      alreadySubmitted: boolean;
    };

    expect(second.verificationId).toBe(first.verificationId);
    expect(second.alreadySubmitted).toBe(true);
    expect(calls).toHaveLength(1);

    const all = await db().collection(VERIFICATIONS).get();
    expect(all.size).toBe(1);
  });

  it('serialises two concurrent submissions carrying different batch ids', async () => {
    // The batch id gives idempotence on a REPLAY, never mutual exclusion
    // between two different ids. The guard document is what serialises them.
    const { double, calls } = extractorReturning(MRZ_OK);
    setTextExtractor(double);
    await uploadBatch(OWNER, 'batchAAAA');
    await uploadBatch(OWNER, 'batchBBBB');

    const results = await Promise.allSettled([
      submit({ batchId: 'batchAAAA' }, { uid: OWNER }),
      submit({ batchId: 'batchBBBB' }, { uid: OWNER }),
    ]);

    const ok = results.filter((r) => r.status === 'fulfilled');
    expect(ok).toHaveLength(1);
    expect(calls).toHaveLength(1);

    const all = await db().collection(VERIFICATIONS).get();
    expect(all.size).toBe(1);
  });

  it('refuses a second file while one is pending', async () => {
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await uploadBatch(OWNER, 'batchAAAA');
    await uploadBatch(OWNER, 'batchBBBB');

    await submit({ batchId: 'batchAAAA' }, { uid: OWNER });
    await expect(
      submit({ batchId: 'batchBBBB' }, { uid: OWNER })
    ).rejects.toThrow(/failed-precondition|en cours/i);
  });

  it('refuses a new file when the provider is already verified', async () => {
    await db().collection(STATES).doc(OWNER).set({
      pendingId: null,
      approvedId: 'approved-1',
      verified: true,
      rejectedCount: 0,
      submitTimestamps: [],
    });
    await verifDoc('approved-1').set({ providerId: OWNER, status: 'approved' });
    await uploadBatch(OWNER, BATCH);

    await expect(submit({ batchId: BATCH }, { uid: OWNER })).rejects.toThrow(
      /failed-precondition|deja verifiee/i
    );
  });

  it('repairs a guard pointing at a file that no longer exists', async () => {
    // A file deleted by hand would otherwise block the provider forever: the
    // submission is refused because the guard says "pending", and revoke cannot
    // help since it requires an approved file.
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await db().collection(STATES).doc(OWNER).set({
      pendingId: 'ghost',
      approvedId: 'ghost-approved',
      verified: true,
      rejectedCount: 0,
      submitTimestamps: [],
    });
    await uploadBatch(OWNER, BATCH);

    await expect(submit({ batchId: BATCH }, { uid: OWNER })).resolves.toBeTruthy();

    const state = (await db().collection(STATES).doc(OWNER).get()).data();
    expect(state?.verified).toBe(false);
    expect(state?.pendingId).toBe(verificationDocId(OWNER, BATCH));
  });
});

describe('submitIdentityVerification: rate limit', () => {
  it('refuses past the window cap and calls no extraction at all', async () => {
    const { double, calls } = extractorReturning(MRZ_OK);
    setTextExtractor(double);
    await uploadBatch(OWNER, BATCH);

    const now = Date.now();
    await db().collection(STATES).doc(OWNER).set({
      pendingId: null,
      approvedId: null,
      verified: false,
      rejectedCount: 3,
      submitTimestamps: [now - 1000, now - 2000, now - 3000],
    });

    await expect(submit({ batchId: BATCH }, { uid: OWNER })).rejects.toThrow(
      /resource-exhausted|Trop de depots/i
    );
    // The billed API is never reached: that is the point of checking the cap
    // before the extraction rather than after.
    expect(calls).toHaveLength(0);
  });

  it('lets a submission through once the window has rolled over', async () => {
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await uploadBatch(OWNER, BATCH);

    const old = Date.now() - 25 * 60 * 60 * 1000;
    await db().collection(STATES).doc(OWNER).set({
      pendingId: null,
      approvedId: null,
      verified: false,
      rejectedCount: 0,
      submitTimestamps: [old, old, old],
    });

    await expect(submit({ batchId: BATCH }, { uid: OWNER })).resolves.toBeTruthy();
  });

  it('flags a fourth attempt as priority instead of refusing it', async () => {
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await uploadBatch(OWNER, BATCH);
    await db().collection(STATES).doc(OWNER).set({
      pendingId: null,
      approvedId: null,
      verified: false,
      rejectedCount: 3,
      submitTimestamps: [],
    });

    await submit({ batchId: BATCH }, { uid: OWNER });

    const data = (await verifDoc(verificationDocId(OWNER, BATCH)).get()).data();
    expect(data?.attempt).toBe(4);
    expect(data?.priority).toBe(true);
  });
});

describe('submitIdentityVerification: duplicate search', () => {
  async function seedForeignFile(key: string): Promise<void> {
    const ref = verifDoc('foreign-1');
    await ref.set({ providerId: OTHER, status: 'approved' });
    await ref.collection(INTERNAL_SUB).doc(INTERNAL_DOC).set({
      providerId: OTHER,
      cniNumberKey: key,
    });
  }

  it('flags a number already used by ANOTHER provider, with a reference', async () => {
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await seedForeignFile(MRZ_NUMBER);
    await uploadBatch(OWNER, BATCH);

    await submit({ batchId: BATCH }, { uid: OWNER });

    const internal = (
      await internalDoc(verificationDocId(OWNER, BATCH)).get()
    ).data();
    expect(internal?.doublonPotentiel).toBe(true);
    expect(internal?.doublonReferenceId).toBe('foreign-1');
  });

  it('does not flag the provider own earlier file', async () => {
    setTextExtractor(extractorReturning(MRZ_OK).double);
    const ref = verifDoc('mine-old');
    await ref.set({ providerId: OWNER, status: 'rejected' });
    await ref.collection(INTERNAL_SUB).doc(INTERNAL_DOC).set({
      providerId: OWNER,
      cniNumberKey: MRZ_NUMBER,
    });
    await uploadBatch(OWNER, BATCH);

    await submit({ batchId: BATCH }, { uid: OWNER });

    const internal = (
      await internalDoc(verificationDocId(OWNER, BATCH)).get()
    ).data();
    expect(internal?.doublonPotentiel).toBe(false);
    expect(internal?.doublonReferenceId).toBeNull();
  });

  it('never flags when no number could be read', async () => {
    // Two files with no readable number must not be duplicates of each other:
    // the reference shown to a reviewer would point at a stranger.
    setTextExtractor({
      async detect() {
        return ['CARTE ILLISIBLE'];
      },
    });
    await seedForeignFile(MRZ_NUMBER);
    await uploadBatch(OWNER, BATCH);

    await submit({ batchId: BATCH }, { uid: OWNER });

    const internal = (
      await internalDoc(verificationDocId(OWNER, BATCH)).get()
    ).data();
    expect(internal?.cniNumberKey).toBeNull();
    expect(internal?.doublonPotentiel).toBe(false);
  });

  it('does not reject or block on a duplicate', async () => {
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await seedForeignFile(MRZ_NUMBER);
    await uploadBatch(OWNER, BATCH);

    await submit({ batchId: BATCH }, { uid: OWNER });

    const data = (await verifDoc(verificationDocId(OWNER, BATCH)).get()).data();
    expect(data?.status).toBe('pending');
  });
});

describe('the extraction step never breaks a submission', () => {
  it('swallows a failure of the duplicate search or of its own write', async () => {
    // Only the detect call used to be guarded. The duplicate search runs on a
    // collection group index, and a Firestore index is built asynchronously
    // after a deploy: while it builds, the query raises FAILED_PRECONDITION.
    // Unguarded, that made the callable fail AFTER the main transaction had
    // committed, leaving a pending file, a consumed rate-limit slot, and a
    // provider convinced their submission had failed.
    //
    // Exercised here by pointing the step at a file that does not exist, so its
    // conditional write throws: the step must still resolve.
    setTextExtractor(extractorReturning(MRZ_OK).double);

    // The file must EXIST and be pending, otherwise the step returns early on
    // its own guard and the test proves nothing: removing the try/catch would
    // still leave it green. Here the parent exists but its internal document
    // does not, so the conditional tx.update raises NOT_FOUND and the commit
    // fails, which is exactly what the guard has to absorb.
    await verifDoc('orphan').set({
      providerId: OWNER,
      status: 'pending',
      extractionStatus: 'pending',
    });

    await expect(
      identity.runExtraction('orphan', OWNER, `private/identity/${OWNER}/${BATCH}/recto.jpg`)
    ).resolves.toBeUndefined();
    // And the file is left decidable rather than half written.
    expect((await verifDoc('orphan').get()).get('status')).toBe('pending');
  });

  it('refuses a submission once the account is gone', async () => {
    // deleteMyAccount takes hundreds of milliseconds between purging identity
    // data and removing the auth user, and an ID token already issued stays
    // acceptable for up to an hour after deleteUser. Without this guard, a
    // second device could recreate a file and three CNI images behind a deleted
    // account, with no purge mechanism left to remove them.
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await uploadBatch(OWNER, BATCH);
    await db().collection('users').doc(OWNER).delete();

    await expect(submit({ batchId: BATCH }, { uid: OWNER })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    expect((await db().collection(VERIFICATIONS).get()).size).toBe(0);
  });

  it('pages past the caller own files to find a real duplicate', async () => {
    // A provider who resubmits many times would otherwise fill the first page
    // with their own history and hide a stranger's file carrying the same
    // number.
    setTextExtractor(extractorReturning(MRZ_OK).double);
    for (let i = 0; i < 11; i++) {
      const ref = verifDoc(`mine-${i}`);
      await ref.set({ providerId: OWNER, status: 'rejected' });
      await ref
        .collection(INTERNAL_SUB)
        .doc(INTERNAL_DOC)
        .set({ providerId: OWNER, cniNumberKey: MRZ_NUMBER });
    }
    const foreign = verifDoc('foreign-deep');
    await foreign.set({ providerId: OTHER, status: 'approved' });
    await foreign
      .collection(INTERNAL_SUB)
      .doc(INTERNAL_DOC)
      .set({ providerId: OTHER, cniNumberKey: MRZ_NUMBER });

    await uploadBatch(OWNER, BATCH);
    await submit({ batchId: BATCH }, { uid: OWNER });

    const internal = (
      await internalDoc(verificationDocId(OWNER, BATCH)).get()
    ).data();
    expect(internal?.doublonPotentiel).toBe(true);
    expect(internal?.doublonReferenceId).toBe('foreign-deep');
  });
});

describe('end to end: a card approved once is flagged on a second account', () => {
  it('flags a resubmission of an approved number by another provider', async () => {
    // The whole point of the duplicate search, and the case a defect made
    // silently pass: approving without corrections used to null the duplicate
    // key of the approved file, so the same card could be reused elsewhere
    // unflagged.
    setTextExtractor(extractorReturning(MRZ_OK).double);
    await uploadBatch(OWNER, BATCH);
    const first = (await submit({ batchId: BATCH }, { uid: OWNER })) as {
      verificationId: string;
    };

    await wrap(fns.approveIdentityVerification)({
      data: { verificationId: first.verificationId },
      auth: { uid: 'boss', token: { admin: true } },
    } as never);

    setTextExtractor(extractorReturning(MRZ_OK).double);
    await uploadBatch(OTHER, BATCH);
    const second = (await submit({ batchId: BATCH }, { uid: OTHER })) as {
      verificationId: string;
    };

    const internal = (await internalDoc(second.verificationId).get()).data();
    expect(internal?.doublonPotentiel).toBe(true);
    expect(internal?.doublonReferenceId).toBe(first.verificationId);
  });
});
