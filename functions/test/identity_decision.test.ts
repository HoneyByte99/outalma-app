// Decision callables (approve / reject / revoke), plus the deletion and export
// wiring. The refusals matter most here: a verdict on an identity document is
// the increment's whole point.
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
  STATES,
  VERIFICATIONS,
} from '../src/identity_verification';
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
const READONLY: Auth = { uid: 'ro', token: { readonly: true } };

const approve = (data: unknown, auth: Auth) =>
  wrap(fns.approveIdentityVerification)({ data, auth } as never);
const reject = (data: unknown, auth: Auth) =>
  wrap(fns.rejectIdentityVerification)({ data, auth } as never);
const revoke = (data: unknown, auth: Auth) =>
  wrap(fns.revokeIdentityVerification)({ data, auth } as never);


/// Asserts on the HttpsError CODE rather than on the message: the code is the
/// contract a client branches on, the message is prose that may be reworded.
async function expectCode(promise: Promise<unknown>, code: string): Promise<void> {
  await expect(promise).rejects.toMatchObject({ code });
}

const verifDoc = (id = VERIF) => db().collection(VERIFICATIONS).doc(id);
const internalDoc = (id = VERIF) =>
  verifDoc(id).collection(INTERNAL_SUB).doc(INTERNAL_DOC);

const paths = (uid = OWNER, batch = BATCH) => ({
  recto: `private/identity/${uid}/${batch}/recto.jpg`,
  verso: `private/identity/${uid}/${batch}/verso.jpg`,
  selfie: `private/identity/${uid}/${batch}/selfie.jpg`,
});

async function uploadBatch(uid = OWNER, batch = BATCH): Promise<void> {
  const bucket = admin.storage().bucket();
  for (const [, path] of Object.entries(paths(uid, batch))) {
    await bucket
      .file(path)
      .save(Buffer.from(`bytes-${path}`), { contentType: 'image/jpeg' });
  }
}

/// Seeds a pending file whose fingerprints match the objects actually on disk.
async function seedPendingFile(status = 'pending', id = VERIF): Promise<void> {
  await uploadBatch();
  const bucket = admin.storage().bucket();
  const p = paths();
  const meta: Record<string, string> = {};
  for (const key of ['recto', 'verso', 'selfie'] as const) {
    const [m] = await bucket.file(p[key]).getMetadata();
    meta[`${key}Generation`] = String(m.generation);
    meta[`${key}Md5`] = String(m.md5Hash);
  }

  await verifDoc(id).set({
    providerId: OWNER,
    batchId: BATCH,
    status,
    attempt: 1,
    priority: false,
    extractionStatus: 'ok',
    cniNumber: '12345678901234567',
    cniNom: 'NDIAYE',
    cniPrenom: 'FATOU',
    cniDateNaissance: '740812',
    cniDateExpiration: '120415',
    cniSexe: 'F',
    mrzValid: true,
    rejectionReason: null,
    submittedAt: admin.firestore.Timestamp.now(),
    reviewedAt: null,
  });
  await internalDoc(id).set({
    providerId: OWNER,
    rectoPath: p.recto,
    versoPath: p.verso,
    selfiePath: p.selfie,
    ...meta,
    cniNumberKey: '12345678901234567',
    doublonPotentiel: false,
    doublonReferenceId: null,
    mrzRaw: 'MRZ',
    reviewedBy: null,
  });
  await db().collection(STATES).doc(OWNER).set({
    pendingId: status === 'pending' ? id : null,
    approvedId: status === 'approved' ? id : null,
    verified: status === 'approved',
    rejectedCount: 0,
    submitTimestamps: [Date.now()],
  });
}

beforeEach(async () => {
  await clearFirestore();
  await admin.storage().bucket().deleteFiles({ prefix: 'private/identity/' });
  await createAuthUser(OWNER);
});

afterAll(() => tf.cleanup());

describe('who may decide', () => {
  beforeEach(seedPendingFile);

  it('admin and moderator may approve or reject', async () => {
    await expect(
      approve({ verificationId: VERIF }, ADMIN)
    ).resolves.toMatchObject({ status: 'approved' });

    await seedPendingFile();
    await expect(
      reject({ verificationId: VERIF, reason: 'photo floue' }, MOD)
    ).resolves.toMatchObject({ status: 'rejected' });
  });

  it('refuses support, which the service moderation helper would have allowed', async () => {
    // approveService uses assertMinSupportClaim. Reusing it here would widen
    // the circle that decides on identity documents (decision D8).
    await expectCode(approve({ verificationId: VERIF }, SUPPORT), 'permission-denied');
    await expectCode(
      reject({ verificationId: VERIF, reason: 'x' }, SUPPORT),
      'permission-denied'
    );
  });

  it('refuses readonly, the owner and an unauthenticated caller', async () => {
    await expectCode(approve({ verificationId: VERIF }, READONLY), 'permission-denied');
    await expectCode(
      approve({ verificationId: VERIF }, { uid: OWNER }),
      'permission-denied'
    );
    await expectCode(
      approve({ verificationId: VERIF }, undefined as never),
      'unauthenticated'
    );
  });

  it('reserves revoke to admin: moderator may grant but not undo', async () => {
    await approve({ verificationId: VERIF }, MOD);
    await expectCode(
      revoke({ verificationId: VERIF, reason: 'fraude' }, MOD),
      'permission-denied'
    );
    await expect(
      revoke({ verificationId: VERIF, reason: 'fraude' }, ADMIN)
    ).resolves.toMatchObject({ status: 'revoked' });
  });
});

describe('deciding once, and only once', () => {
  beforeEach(seedPendingFile);

  it('refuses a second decision on the same file', async () => {
    await approve({ verificationId: VERIF }, ADMIN);
    await expectCode(approve({ verificationId: VERIF }, ADMIN), 'failed-precondition');
    await expectCode(
      reject({ verificationId: VERIF, reason: 'trop tard' }, ADMIN),
      'failed-precondition'
    );
  });

  it('refuses a decision on a file that does not exist', async () => {
    await expectCode(approve({ verificationId: 'ghost' }, ADMIN), 'not-found');
  });

  it('refuses a rejection with an empty or blank reason', async () => {
    await expectCode(reject({ verificationId: VERIF }, ADMIN), 'invalid-argument');
    await expectCode(
      reject({ verificationId: VERIF, reason: '   ' }, ADMIN),
      'invalid-argument'
    );
  });

  it('refuses an oversized reason rather than failing later on the push payload', async () => {
    await expectCode(
      reject({ verificationId: VERIF, reason: 'x'.repeat(1001) }, ADMIN),
      'invalid-argument'
    );
  });
});

describe('the immutability guard at decision time', () => {
  it('refuses to decide when an image changed since submission', async () => {
    await seedPendingFile();
    // Bypasses the Storage rule on purpose: the point is to prove the SECOND
    // guard still catches it if the rule were ever relaxed.
    await admin
      .storage()
      .bucket()
      .file(paths().recto)
      .save(Buffer.from('swapped bytes'), { contentType: 'image/jpeg' });

    await expectCode(approve({ verificationId: VERIF }, ADMIN), 'failed-precondition');
  });

  it('still allows a revoke, which must not be blocked by an altered image', async () => {
    await seedPendingFile('approved');
    await admin
      .storage()
      .bucket()
      .file(paths().recto)
      .save(Buffer.from('swapped bytes'), { contentType: 'image/jpeg' });

    await expect(
      revoke({ verificationId: VERIF, reason: 'fraude' }, ADMIN)
    ).resolves.toMatchObject({ status: 'revoked' });
  });
});

describe('what a decision writes', () => {
  beforeEach(seedPendingFile);

  it('records the verdict, the reviewer and the guard state', async () => {
    await approve({ verificationId: VERIF }, ADMIN);

    const file = (await verifDoc().get()).data();
    expect(file?.status).toBe('approved');
    expect(file?.reviewedAt).toBeTruthy();
    expect((await internalDoc().get()).get('reviewedBy')).toBe(ADMIN.uid);

    const state = (await db().collection(STATES).doc(OWNER).get()).data();
    expect(state?.verified).toBe(true);
    expect(state?.approvedId).toBe(VERIF);
    expect(state?.pendingId).toBeNull();
  });

  it('counts a rejection so the next attempt can be flagged priority', async () => {
    await reject({ verificationId: VERIF, reason: 'photo floue' }, MOD);

    const state = (await db().collection(STATES).doc(OWNER).get()).data();
    expect(state?.rejectedCount).toBe(1);
    expect(state?.verified).toBe(false);
    expect((await verifDoc().get()).get('rejectionReason')).toBe('photo floue');
  });

  it('traces the action without ever putting identity data in the audit log', async () => {
    // admin_logs survives deleteMyAccount, so a card number or a free-text
    // reason written there would be a retention with no purge path behind it.
    await reject({ verificationId: VERIF, reason: 'numero illisible 999' }, MOD);

    const logs = await db().collection('admin_logs').get();
    expect(logs.size).toBe(1);
    const log = logs.docs[0]?.data() ?? {};
    expect(log.action).toBe('reject_identity_verification');
    expect(log.actorUid).toBe(MOD.uid);
    expect(log.targetId).toBe(VERIF);
    const serialised = JSON.stringify(log);
    expect(serialised).not.toContain('numero illisible 999');
    expect(serialised).not.toContain('12345678901234567');
    expect(serialised).not.toContain('NDIAYE');
  });

  it('writes no trace at all when the decision is refused', async () => {
    await expect(approve({ verificationId: VERIF }, SUPPORT)).rejects.toThrow();
    expect((await db().collection('admin_logs').get()).size).toBe(0);
  });

  it('notifies the provider in app', async () => {
    await approve({ verificationId: VERIF }, ADMIN);
    const items = await db()
      .collection('notifications')
      .doc(OWNER)
      .collection('items')
      .get();
    expect(items.size).toBe(1);
    expect(items.docs[0]?.get('audience')).toBe('provider');
  });

  it('keeps a corrected number and recomputes the duplicate key with it', async () => {
    // Otherwise a real duplicate would stay invisible to every later
    // submission, since the search runs on the normalised key.
    await approve(
      {
        verificationId: VERIF,
        fields: { cniNumber: '9999 8888 7777 6666 5', cniNom: 'DIOP' },
      },
      ADMIN
    );

    expect((await verifDoc().get()).get('cniNumber')).toBe('9999 8888 7777 6666 5');
    expect((await internalDoc().get()).get('cniNumberKey')).toBe(
      '99998888777766665'
    );
    // The correction replaces the whole editable set: a field left out is
    // cleared, not silently kept from a failed extraction.
    expect((await verifDoc().get()).get('cniPrenom')).toBeNull();
  });
});

describe('account deletion and export', () => {
  it('erases the file, the internal document, the guard and the images', async () => {
    await seedPendingFile();
    await wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: OWNER } } as never);

    expect((await verifDoc().get()).exists).toBe(false);
    expect((await internalDoc().get()).exists).toBe(false);
    expect(
      (await db().collection(STATES).doc(OWNER).get()).exists
    ).toBe(false);

    const [files] = await admin
      .storage()
      .bucket()
      .getFiles({ prefix: `private/identity/${OWNER}/` });
    expect(files).toHaveLength(0);
  });

  it('includes the file in the personal data export, without images or review aids', async () => {
    await seedPendingFile();
    const out = (await wrap(fns.exportMyData)({
      data: {},
      auth: { uid: OWNER },
    } as never)) as { identityVerifications: Record<string, unknown>[] };

    expect(out.identityVerifications).toHaveLength(1);
    const entry = out.identityVerifications[0] ?? {};
    expect(entry.status).toBe('pending');
    expect(entry.cniNumber).toBe('12345678901234567');

    const serialised = JSON.stringify(out);
    expect(serialised).not.toContain('private/identity/');
    expect(serialised).not.toContain('doublonReferenceId');
    expect(serialised).not.toContain('reviewedBy');
  });
});

describe('normalisation at decision time', () => {
  it('marks a long-stalled extraction as failed', async () => {
    // A process that died between the commit and the extraction write would
    // otherwise leave a file "in progress" forever: replaying the callable
    // returns the existing file without redoing anything. The decision is the
    // only place in this increment able to observe and settle it.
    await seedPendingFile();
    await verifDoc().update({
      extractionStatus: 'pending',
      submittedAt: admin.firestore.Timestamp.fromMillis(
        Date.now() - 60 * 60 * 1000
      ),
    });

    await approve({ verificationId: VERIF }, ADMIN);

    expect((await verifDoc().get()).get('extractionStatus')).toBe('failed');
  });

  it('leaves a recent pending extraction alone', async () => {
    await seedPendingFile();
    await verifDoc().update({
      extractionStatus: 'pending',
      submittedAt: admin.firestore.Timestamp.now(),
    });

    await approve({ verificationId: VERIF }, ADMIN);

    expect((await verifDoc().get()).get('extractionStatus')).toBe('pending');
  });

  it('clears every editable field when the reviewer sends none', async () => {
    // The correction replaces the whole set, so approving without fields is an
    // explicit "none of these are right", not "keep what the OCR guessed".
    await seedPendingFile();
    await approve({ verificationId: VERIF }, ADMIN);

    const data = (await verifDoc().get()).data() ?? {};
    for (const key of ['cniNumber', 'cniNom', 'cniPrenom', 'cniSexe']) {
      expect(data[key]).toBeNull();
    }
  });
});
