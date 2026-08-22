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
  TRUST,
  INTERNAL_DOC,
  INTERNAL_SUB,
  STATES,
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

  it('projects "verified" publicly on approve, in the decision transaction', async () => {
    // E1: the badge a client reads is provider_trust/{uid}, derived from the
    // guard inside the decision transaction. Before any decision there is no
    // document at all, which is the third public state, "not verified".
    expect((await db().collection(TRUST).doc(OWNER).get()).exists).toBe(false);

    await approve({ verificationId: VERIF }, ADMIN);

    const trust = (await db().collection(TRUST).doc(OWNER).get()).data();
    expect(trust?.identityStatus).toBe('verified');
  });

  it('deletes the public projection on revoke, rather than writing false', async () => {
    // Deleting, not flipping: nothing public is ever written about a provider
    // whose verification was taken away, so a revocation is indistinguishable
    // from never having submitted. That is a product contract, not a detail.
    await approve({ verificationId: VERIF }, ADMIN);
    expect(
      (await db().collection(TRUST).doc(OWNER).get()).get('identityStatus')
    ).toBe('verified');

    await revoke({ verificationId: VERIF, reason: 'fraude' }, ADMIN);
    expect((await db().collection(TRUST).doc(OWNER).get()).exists).toBe(false);
  });

  it('leaves no public projection behind on reject', async () => {
    await reject({ verificationId: VERIF, reason: 'photo floue' }, MOD);
    expect((await db().collection(TRUST).doc(OWNER).get()).exists).toBe(false);
  });

  it('carries no personal data in the public projection', async () => {
    // The document is world readable, so every key it holds is public. This
    // test is the guard on that: it fails the day someone denormalises a name,
    // a card number or a rejection reason into it for convenience.
    await approve({ verificationId: VERIF }, ADMIN);
    const trust = (await db().collection(TRUST).doc(OWNER).get()).data() ?? {};
    expect(Object.keys(trust).sort()).toEqual(['identityStatus', 'updatedAt']);
  });

  it('never touches the provider profile when deciding', async () => {
    // The badge used to live on providers/{uid} (D6-a, replaced by E1). It must
    // not come back by accident: the decision writes the projection and nothing
    // else about the profile.
    await db()
      .collection('providers')
      .doc(OWNER)
      .set({ bio: 'Menage a domicile', active: true, suspended: false });

    await approve({ verificationId: VERIF }, ADMIN);

    const provider = (await db().collection('providers').doc(OWNER).get()).data();
    expect(provider).toEqual({
      bio: 'Menage a domicile',
      active: true,
      suspended: false,
    });
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
    // The target TYPE matters as much as the id: an audit trail that does not
    // say what kind of object was acted on cannot be filtered or audited.
    expect(log.targetType).toBe('identity_verification');
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
    // A generic type would make the notification unroutable by the app.
    expect(items.docs[0]?.get('type')).toBe('identity_approved');
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

  it('keeps the extracted fields when the reviewer sends no correction', async () => {
    // Deciding without corrections means "the extracted values are right".
    // Treating it as an empty correction erased them AND nulled the duplicate
    // key, letting the holder of an approved card resubmit it on another
    // account unflagged.
    await seedPendingFile();
    await approve({ verificationId: VERIF }, ADMIN);

    const data = (await verifDoc().get()).data() ?? {};
    expect(data.cniNumber).toBe('12345678901234567');
    expect(data.cniNom).toBe('NDIAYE');
    expect(data.cniPrenom).toBe('FATOU');
    expect((await internalDoc().get()).get('cniNumberKey')).toBe(
      '12345678901234567'
    );
  });

  it('clears a field omitted from an ACTUAL correction', async () => {
    // Within a correction the reviewer replaces the whole set, so a field left
    // out is cleared rather than silently kept from a failed extraction.
    await seedPendingFile();
    await approve(
      { verificationId: VERIF, fields: { cniNumber: '12345678901234567' } },
      ADMIN
    );

    const data = (await verifDoc().get()).data() ?? {};
    expect(data.cniNumber).toBe('12345678901234567');
    expect(data.cniNom).toBeNull();
    expect(data.cniPrenom).toBeNull();
  });
});

describe('decision error paths', () => {
  it('reports a missing object as failed-precondition, not as a raw storage error', async () => {
    // Manual cleanup, or an account deletion interrupted between the storage
    // purge and the Firestore purge. The published error table promises
    // failed-precondition; a bare GCS 404 would surface as `internal`.
    await seedPendingFile();
    await admin.storage().bucket().file(paths().recto).delete();

    await expectCode(approve({ verificationId: VERIF }, ADMIN), 'failed-precondition');
  });

  it('bounds the reason on revoke as well as on reject', async () => {
    // Same failure mechanism on both: the reason is copied into the push body,
    // and the FCM payload caps at 4 KB, after the verdict is already written.
    await seedPendingFile('approved');
    await expectCode(
      revoke({ verificationId: VERIF, reason: 'x'.repeat(1001) }, ADMIN),
      'invalid-argument'
    );
  });

  it('refuses a malformed fields payload instead of silently ignoring it', async () => {
    // A review screen serialising its form badly would otherwise approve while
    // dropping what the reviewer typed, with no signal at all.
    await seedPendingFile();
    await expectCode(
      approve({ verificationId: VERIF, fields: 'cniNumber=X' }, ADMIN),
      'invalid-argument'
    );
    await expectCode(
      approve({ verificationId: VERIF, fields: 42 }, ADMIN),
      'invalid-argument'
    );
  });
});

describe('account deletion is scoped and exhaustive', () => {
  const STRANGER = 'p9';

  async function seedFor(uid: string, batches: string[]): Promise<string[]> {
    const bucket = admin.storage().bucket();
    const ids: string[] = [];
    for (const batch of batches) {
      const id = `${uid}-${batch}`;
      ids.push(id);
      for (const name of ['recto.jpg', 'verso.jpg', 'selfie.jpg']) {
        await bucket
          .file(`private/identity/${uid}/${batch}/${name}`)
          .save(Buffer.from('x'), { contentType: 'image/jpeg' });
      }
      await verifDoc(id).set({ providerId: uid, status: 'rejected', batchId: batch });
      await internalDoc(id).set({
        providerId: uid,
        rectoPath: `private/identity/${uid}/${batch}/recto.jpg`,
      });
    }
    await db().collection(STATES).doc(uid).set({
      pendingId: null,
      approvedId: null,
      verified: false,
      rejectedCount: batches.length,
      submitTimestamps: [],
    });
    return ids;
  }

  const objectCount = async (uid: string): Promise<number> => {
    const [files] = await admin
      .storage()
      .bucket()
      .getFiles({ prefix: `private/identity/${uid}/` });
    return files.length;
  };

  it('erases the WHOLE history, not only the most recent file', async () => {
    // A loop that stopped after the first file would leave older submissions,
    // images included, behind a deleted account. Retention was decided as
    // "kept until the account is deleted", so nothing else would ever remove
    // them.
    const mine = await seedFor(OWNER, ['b1', 'b2', 'b3']);
    await createAuthUser(OWNER);

    await wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: OWNER } } as never);

    for (const id of mine) {
      expect((await verifDoc(id).get()).exists).toBe(false);
      expect((await internalDoc(id).get()).exists).toBe(false);
    }
    expect(await objectCount(OWNER)).toBe(0);
    expect((await db().collection(STATES).doc(OWNER).get()).exists).toBe(false);
  });

  it('spares every other provider, documents and images alike', async () => {
    // The guard this proves is not "deletion happens" but "deletion is scoped".
    // Without it, dropping the providerId filter, or widening the storage
    // prefix to private/identity/, would wipe every provider's identity
    // documents on any single account deletion, and no test would notice.
    await seedFor(OWNER, ['b1', 'b2']);
    const theirs = await seedFor(STRANGER, ['b1']);
    await createAuthUser(OWNER);

    await wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: OWNER } } as never);

    expect(await objectCount(OWNER)).toBe(0);

    for (const id of theirs) {
      expect((await verifDoc(id).get()).exists).toBe(true);
      expect((await internalDoc(id).get()).exists).toBe(true);
    }
    expect(await objectCount(STRANGER)).toBe(3);
    expect((await db().collection(STATES).doc(STRANGER).get()).exists).toBe(true);
  });
});

describe('what a decision emits, observed rather than assumed', () => {
  it('writes an audit entry on an APPROVAL too, not only on a rejection', async () => {
    await seedPendingFile();
    await approve({ verificationId: VERIF }, ADMIN);

    const logs = await db().collection('admin_logs').get();
    expect(logs.size).toBe(1);
    expect(logs.docs[0]?.get('action')).toBe('approve_identity_verification');
  });

  it('emits exactly one push, to the provider token and no other', async () => {
    await seedPendingFile();
    await db().collection('users').doc(OWNER).set({ pushToken: 'tok-p1' }, { merge: true });
    await db().collection('users').doc('someone-else').set({ pushToken: 'tok-other' });

    const spy = jest
      .spyOn(admin.messaging(), 'sendEachForMulticast')
      .mockResolvedValue({ successCount: 1, failureCount: 0, responses: [{ success: true }] } as never);

    await approve({ verificationId: VERIF }, ADMIN);

    expect(spy).toHaveBeenCalledTimes(1);
    expect(spy.mock.calls[0]?.[0]?.tokens).toEqual(['tok-p1']);
    spy.mockRestore();
  });

  it('carries the rejection reason all the way to the provider notification', async () => {
    // The reason is the only thing that tells a provider what to fix. A
    // notification that dropped it would leave them guessing.
    await seedPendingFile();
    await reject({ verificationId: VERIF, reason: 'le verso est illisible' }, MOD);

    const items = await db()
      .collection('notifications')
      .doc(OWNER)
      .collection('items')
      .get();
    expect(items.size).toBe(1);
    expect(items.docs[0]?.get('body')).toContain('le verso est illisible');
  });
});

describe('the export is confined to its requester', () => {
  it('never returns another provider file', async () => {
    // Same class of defect as the deletion scoping, on the callable that sweeps
    // the same collection with the same filter. Without this, dropping the
    // providerId filter would hand every provider's card number, names and
    // dates to any authenticated caller, and neither the suite nor the smoke
    // would notice: both only ever had one provider.
    await seedPendingFile();
    const other = verifDoc('stranger-file');
    await other.set({
      providerId: 'p9',
      status: 'approved',
      cniNumber: '99998888777766665',
      cniNom: 'AUTRE',
    });

    const out = (await wrap(fns.exportMyData)({
      data: {},
      auth: { uid: OWNER },
    } as never)) as { identityVerifications: Record<string, unknown>[] };

    expect(out.identityVerifications).toHaveLength(1);
    expect(out.identityVerifications[0]?.id).toBe(VERIF);
    const serialised = JSON.stringify(out);
    expect(serialised).not.toContain('99998888777766665');
    expect(serialised).not.toContain('AUTRE');
  });

  it('returns an empty list for a provider who never submitted', async () => {
    await db().collection('users').doc('p8').set({ displayName: 'X' });
    const out = (await wrap(fns.exportMyData)({
      data: {},
      auth: { uid: 'p8' },
    } as never)) as { identityVerifications: unknown[] };
    expect(out.identityVerifications).toHaveLength(0);
  });
});

describe('the fingerprint guard covers all three pieces', () => {
  for (const piece of ['verso', 'selfie'] as const) {
    it(`refuses a decision when the ${piece} changed`, async () => {
      // Checking only the recto would leave the selfie swappable, which is the
      // very image the reviewer compares against the card.
      await seedPendingFile();
      await admin
        .storage()
        .bucket()
        .file(paths()[piece])
        .save(Buffer.from('swapped'), { contentType: 'image/jpeg' });

      await expectCode(approve({ verificationId: VERIF }, ADMIN), 'failed-precondition');
    });
  }
});

describe('a late extraction cannot overwrite a decided file', () => {
  it('leaves a reviewer correction untouched', async () => {
    // The conditional write exists for this: a slow extraction landing after a
    // decision would otherwise replace what the reviewer typed.
    await seedPendingFile();
    await approve(
      { verificationId: VERIF, fields: { cniNumber: '11112222333344445', cniNom: 'CORRIGE' } },
      ADMIN
    );

    // A double, otherwise the step reaches for the real Cloud Vision client and
    // hangs on the network instead of testing anything.
    identity.setTextExtractor({
      async detect() {
        return [
          'I<UTOD231458907123456789012345',
          '7408122F1204159UTO67<<<<<<<<<9',
          'NDIAYE<<FATOU<<<<<<<<<<<<<<<<<',
        ];
      },
    });
    try {
      await identity.runExtraction(
        VERIF,
        OWNER,
        `private/identity/${OWNER}/${BATCH}/recto.jpg`
      );
    } finally {
      identity.resetTextExtractor();
    }

    const data = (await verifDoc().get()).data() ?? {};
    expect(data.cniNumber).toBe('11112222333344445');
    expect(data.cniNom).toBe('CORRIGE');
    expect(data.status).toBe('approved');
  });
});

/**
 * Systematic sweep of the four callables against the same four questions:
 * what does it read, what does it write, what does it trace, what does it
 * notify. Three QA passes each found the same motif on a different callable
 * (deleteMyAccount, then exportMyData, then revoke), so the countermeasure is a
 * sweep, not another patch on the case that happened to be caught.
 */
describe('sweep: revoke writes, traces and notifies like the others', () => {
  it('actually removes the verification, and lets the provider submit again', async () => {
    // The heart of AC-30, and the only inverse of AC-21b. Nothing tested what
    // revoke WRITES: a version that left `verified` true would keep the badge
    // and lock the provider out of ever resubmitting.
    await seedPendingFile('approved');
    await revoke({ verificationId: VERIF, reason: 'fraude avere' }, ADMIN);

    const state = (await db().collection(STATES).doc(OWNER).get()).data();
    expect(state?.verified).toBe(false);
    expect(state?.approvedId).toBeNull();
    expect((await verifDoc().get()).get('status')).toBe('revoked');
  });

  it('traces a revocation as a revocation, not as an approval', async () => {
    await seedPendingFile('approved');
    await revoke({ verificationId: VERIF, reason: 'fraude avere' }, ADMIN);

    const logs = await db().collection('admin_logs').get();
    expect(logs.size).toBe(1);
    expect(logs.docs[0]?.get('action')).toBe('revoke_identity_verification');
    expect(logs.docs[0]?.get('targetType')).toBe('identity_verification');
    expect(logs.docs[0]?.get('actorUid')).toBe(ADMIN.uid);
  });

  it('tells the provider their verification was withdrawn', async () => {
    await seedPendingFile('approved');
    await revoke({ verificationId: VERIF, reason: 'fraude avere' }, ADMIN);

    const items = await db()
      .collection('notifications').doc(OWNER).collection('items').get();
    expect(items.size).toBe(1);
    expect(items.docs[0]?.get('type')).toBe('identity_revoked');
    expect(items.docs[0]?.get('body')).toContain('fraude avere');
  });
});

describe('sweep: the immutability guard applies to reject, not only approve', () => {
  it('refuses a rejection when a piece changed since submission', async () => {
    await seedPendingFile();
    await admin.storage().bucket().file(paths().selfie)
      .save(Buffer.from('swapped'), { contentType: 'image/jpeg' });

    await expectCode(
      reject({ verificationId: VERIF, reason: 'photo floue' }, MOD),
      'failed-precondition'
    );
  });
});

describe('sweep: a decision never resets the submission window', () => {
  it('keeps counting submissions across real rejections', async () => {
    // The earlier accumulation test clears pendingId by writing to the guard
    // directly. A real provider gets there through a rejection, and a decision
    // that dropped the timestamps would hand back an unlimited quota on the
    // billed extraction API.
    identity.setTextExtractor({
      async detect() {
        return [
          'I<UTOD231458907123456789012345',
          '7408122F1204159UTO67<<<<<<<<<9',
          'NDIAYE<<FATOU<<<<<<<<<<<<<<<<<',
        ];
      },
    });
    try {
      // A submission requires the account to still exist.
      await db().collection('users').doc(OWNER).set({ displayName: 'U' });
      const bucket = admin.storage().bucket();
      for (const batch of ['sweepAAAA', 'sweepBBBB', 'sweepCCCC']) {
        for (const name of ['recto.jpg', 'verso.jpg', 'selfie.jpg']) {
          await bucket.file(`private/identity/${OWNER}/${batch}/${name}`)
            .save(Buffer.from('x'), { contentType: 'image/jpeg' });
        }
        const res = (await wrap(fns.submitIdentityVerification)({
          data: { batchId: batch }, auth: { uid: OWNER },
        } as never)) as { verificationId: string };
        await reject({ verificationId: res.verificationId, reason: 'a refaire' }, MOD);
      }

      const state = (await db().collection(STATES).doc(OWNER).get()).data();
      expect(state?.submitTimestamps).toHaveLength(3);
      expect(state?.rejectedCount).toBe(3);

      for (const name of ['recto.jpg', 'verso.jpg', 'selfie.jpg']) {
        await bucket.file(`private/identity/${OWNER}/sweepDDDD/${name}`)
          .save(Buffer.from('x'), { contentType: 'image/jpeg' });
      }
      await expect(
        wrap(fns.submitIdentityVerification)({
          data: { batchId: 'sweepDDDD' }, auth: { uid: OWNER },
        } as never)
      ).rejects.toMatchObject({ code: 'resource-exhausted' });
    } finally {
      identity.resetTextExtractor();
    }
  });
});

describe('sweep: the export carries an explicit field list', () => {
  it('exposes exactly the agreed keys and nothing more', async () => {
    // A raw `...d.data()` would pass every current assertion while leaking
    // batchId, mrzValid, attempt and priority, plus any field added later.
    await seedPendingFile();
    const out = (await wrap(fns.exportMyData)({
      data: {}, auth: { uid: OWNER },
    } as never)) as { identityVerifications: Record<string, unknown>[] };

    expect(Object.keys(out.identityVerifications[0] ?? {}).sort()).toEqual([
      'cniDateExpiration', 'cniDateNaissance', 'cniNom', 'cniNumber',
      'cniPrenom', 'cniSexe', 'id', 'rejectionReason', 'reviewedAt',
      'status', 'submittedAt',
    ]);
  });
});

describe('sweep: a forged verification id refuses through the published table', () => {
  it('answers invalid-argument rather than a raw SDK error', async () => {
    for (const bad of ['', '   ', 'a/b/c', '../../etc']) {
      await expectCode(approve({ verificationId: bad }, ADMIN), 'invalid-argument');
    }
    expect((await db().collection('admin_logs').get()).size).toBe(0);
  });
});

describe('sweep: the branches the earlier passes only half covered', () => {
  it('records the reviewer even when they corrected the fields', async () => {
    // reviewedBy was only ever asserted on the branch WITHOUT a correction,
    // which is the branch a real review screen will rarely take.
    await seedPendingFile();
    await approve(
      { verificationId: VERIF, fields: { cniNumber: '12345678901234567' } },
      ADMIN
    );
    expect((await internalDoc().get()).get('reviewedBy')).toBe(ADMIN.uid);
  });

  it('exports VALUES, not just the shape', async () => {
    // The key-set assertion added last round would stay green with every value
    // turned to null, which is a family my own fix created.
    await seedPendingFile();
    await reject({ verificationId: VERIF, reason: 'verso illisible' }, MOD);

    const out = (await wrap(fns.exportMyData)({
      data: {}, auth: { uid: OWNER },
    } as never)) as { identityVerifications: Record<string, unknown>[] };
    const entry = out.identityVerifications[0] ?? {};

    expect(entry.status).toBe('rejected');
    expect(entry.rejectionReason).toBe('verso illisible');
    expect(entry.submittedAt).toBeTruthy();
    expect(entry.reviewedAt).toBeTruthy();
    expect(entry.cniNumber).toBe('12345678901234567');
  });

  it('refuses an unbounded correction like it refuses an unbounded reason', async () => {
    await seedPendingFile();
    await expectCode(
      approve({ verificationId: VERIF, fields: { cniNom: 'A'.repeat(201) } }, ADMIN),
      'invalid-argument'
    );
    expect((await verifDoc().get()).get('status')).toBe('pending');
  });
});
