// ---------------------------------------------------------------------------
// Identity verification: submission
// ---------------------------------------------------------------------------
//
// Server-authoritative throughout. The client uploads three images under a
// prefix scoped by its own uid, then calls submit with nothing but the batch
// id. It never sends a path, never sends a field value, and never sends a
// verdict: everything stored here is read from the objects by this file.

import * as admin from 'firebase-admin';
import { createHash } from 'crypto';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  assertAdminClaim,
  assertAdminOrModeratorClaim,
  assertAuthenticated,
  requireString,
} from './common';
import { writeAdminLogTx } from './audit';
import { createNotification, sendPushToUsers } from './notify';
import {
  buildObjectPaths,
  extractionFromLines,
  FAILED_EXTRACTION,
  isValidBatchId,
  normalizeCniNumber,
  type ExtractionOutcome,
  type TextExtractor,
} from './identity_extraction';

const db = () => admin.firestore();

export const VERIFICATIONS = 'identity_verifications';
export const INTERNAL_SUB = 'identity_internal';
export const INTERNAL_DOC = 'review';
export const STATES = 'identity_verification_states';

/// Public provider profile collection. Holds the server-owned identity badge
/// flag (D6-a, Amath 2026-08-21): a boolean the client is never trusted to
/// write. See the decision transaction and firestore.rules.
export const PROVIDERS = 'providers';
export const IDENTITY_VERIFIED_FIELD = 'identityVerified';

/// Rate limit. Exported so tests can reason about the window without waiting a
/// day, and so no other file re-invents the numbers.
export const SUBMIT_MAX_PER_WINDOW = 3;
export const SUBMIT_WINDOW_MS = 24 * 60 * 60 * 1000;

/// Beyond this many rejected files, a new one is flagged for priority review.
/// It is never refused for that reason: the rate limit is the only thing that
/// refuses (decision O1).
export const PRIORITY_AFTER_ATTEMPTS = 3;

/// An extraction still marked pending after this long is treated as dead and
/// normalised to failed when a reviewer decides.
export const EXTRACTION_STALE_MS = 15 * 60 * 1000;

export interface IdentityFileMetadata {
  generation: string;
  md5Hash: string;
}

/// Deterministic, caller-scoped document id.
///
/// The batch id is chosen by the client and carries no guaranteed entropy, so
/// it must never be an access key on its own: keying files by batch id alone
/// would let anyone who guesses another provider's value receive that
/// provider's file, names and card number included. Hashing the authenticated
/// uid into the id makes the collision impossible instead of unlikely.
export function verificationDocId(uid: string, batchId: string): string {
  return createHash('sha256').update(`${uid}:${batchId}`).digest('hex');
}

// ---------------------------------------------------------------------------
// Text extraction wiring
// ---------------------------------------------------------------------------

let visionClient: { textDetection: (uri: string) => Promise<unknown[]> } | null =
  null;

/// Production extractor: Cloud Vision, European endpoint. The users are in
/// France and Senegal, there is no Senegalese GCP region, and the data
/// protection file has to state where the images are processed, so the choice
/// is explicit rather than left to a default.
/* istanbul ignore next -- thin adapter over an external SDK: there is no
   Cloud Vision emulator, so the only way to execute this body would be to call
   the paid API from the test suite. Everything it feeds is covered through the
   injected double, and the interface boundary is one line wide. */
export const cloudVisionExtractor: TextExtractor = {
  async detect(gcsUri: string): Promise<string[]> {
    if (!visionClient) {
      const vision = await import('@google-cloud/vision');
      visionClient = new vision.ImageAnnotatorClient({
        apiEndpoint: 'eu-vision.googleapis.com',
      }) as unknown as typeof visionClient;
    }
    const [result] = (await visionClient!.textDetection(gcsUri)) as [
      { fullTextAnnotation?: { text?: string } | null },
    ];
    const text = result?.fullTextAnnotation?.text ?? '';
    return text.split('\n');
  },
};

let activeExtractor: TextExtractor = cloudVisionExtractor;

/// Swaps the extractor. The only supported use is a test double that counts its
/// calls: "exactly one extraction per file" and "no extraction beyond the rate
/// limit" are claims about a billed API, and an unobservable claim is not a
/// tested one.
export function setTextExtractor(extractor: TextExtractor): void {
  activeExtractor = extractor;
}

export function resetTextExtractor(): void {
  activeExtractor = cloudVisionExtractor;
}

// ---------------------------------------------------------------------------
// submitIdentityVerification
// ---------------------------------------------------------------------------

export const submitIdentityVerification = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const batchId: unknown = request.data?.batchId;
  if (!isValidBatchId(batchId)) {
    // Length plus allowlist, never an anchored regex: `$` matches before a
    // trailing newline in JavaScript and an object name may contain one.
    throw new HttpsError(
      'invalid-argument',
      "Le champ 'batchId' est invalide."
    );
  }

  const docId = verificationDocId(uid, batchId);
  const paths = buildObjectPaths(uid, batchId);

  // Read the object fingerprints BEFORE the transaction. Network calls inside a
  // Firestore transaction would be repeated on contention. Reading early is
  // safe precisely because the objects are immutable once created.
  const fingerprints = await readFingerprints(paths);

  const created = await db().runTransaction(async (tx) => {
    const verifRef = db().collection(VERIFICATIONS).doc(docId);
    const stateRef = db().collection(STATES).doc(uid);

    const userRef = db().collection('users').doc(uid);
    const [verifSnap, stateSnap, userSnap] = await Promise.all([
      tx.get(verifRef),
      tx.get(stateRef),
      tx.get(userRef),
    ]);

    // The account must still exist. Two windows this closes, both of which
    // would leave identity documents behind a deleted account with no purge
    // mechanism left (decision D4 removed the scheduled one):
    //  - deleteMyAccount takes hundreds of milliseconds between purging the
    //    identity data and removing the auth user. Reading users/{uid} inside
    //    this transaction makes a concurrent submission conflict with the
    //    deletion batch and replay, instead of recreating what was just purged.
    //  - after deleteUser, Firebase revokes refresh tokens but an ID token
    //    already issued stays acceptable until it expires, up to an hour.
    if (!userSnap.exists) {
      throw new HttpsError('failed-precondition', 'Compte introuvable.');
    }

    // Idempotence, scoped by construction: this id can only be the caller's.
    if (verifSnap.exists) {
      return { alreadySubmitted: true, verificationId: docId };
    }

    const state = await reconcileState(tx, stateSnap.data() ?? {});

    if (state.pendingId) {
      throw new HttpsError(
        'failed-precondition',
        'Un dossier est deja en cours de verification.'
      );
    }
    if (state.verified) {
      throw new HttpsError(
        'failed-precondition',
        'Votre identite est deja verifiee.'
      );
    }

    const now = Date.now();
    const recent = state.submitTimestamps.filter(
      (ms) => now - ms < SUBMIT_WINDOW_MS
    );
    if (recent.length >= SUBMIT_MAX_PER_WINDOW) {
      // Refused BEFORE any extraction call, which is the whole point: an
      // uncapped callable in front of a billed API is a denial of service
      // against ourselves.
      throw new HttpsError(
        'resource-exhausted',
        'Trop de depots recents. Reessayez plus tard.'
      );
    }

    const attempt = state.rejectedCount + 1;

    tx.set(verifRef, {
      providerId: uid,
      batchId,
      status: 'pending',
      attempt,
      priority: attempt > PRIORITY_AFTER_ATTEMPTS,
      extractionStatus: 'pending',
      cniNumber: null,
      cniNom: null,
      cniPrenom: null,
      cniDateNaissance: null,
      cniDateExpiration: null,
      cniSexe: null,
      mrzValid: false,
      rejectionReason: null,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedAt: null,
    });

    tx.set(verifRef.collection(INTERNAL_SUB).doc(INTERNAL_DOC), {
      // Duplicated from the parent: a collectionGroup duplicate search only
      // yields the subcollection document, and re-reading every parent to know
      // who owns it would cost one read per result.
      providerId: uid,
      rectoPath: paths.recto,
      versoPath: paths.verso,
      selfiePath: paths.selfie,
      rectoGeneration: fingerprints.recto.generation,
      rectoMd5: fingerprints.recto.md5Hash,
      versoGeneration: fingerprints.verso.generation,
      versoMd5: fingerprints.verso.md5Hash,
      selfieGeneration: fingerprints.selfie.generation,
      selfieMd5: fingerprints.selfie.md5Hash,
      cniNumberKey: null,
      doublonPotentiel: false,
      doublonReferenceId: null,
      mrzRaw: null,
      reviewedBy: null,
    });

    tx.set(
      stateRef,
      {
        pendingId: docId,
        approvedId: state.approvedId,
        verified: state.verified,
        rejectedCount: state.rejectedCount,
        submitTimestamps: [...recent, now],
      },
      { merge: true }
    );

    return { alreadySubmitted: false, verificationId: docId };
  });

  if (created.alreadySubmitted) {
    // A replay, not a new submission: no second file, no second extraction, no
    // second notification. The marker lets a client tell the two apart.
    return created;
  }

  await runExtraction(docId, uid, paths.recto);

  logger.info('Identity verification submitted', {
    uid,
    verificationId: docId,
  });
  return created;
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface GuardState {
  pendingId: string | null;
  approvedId: string | null;
  verified: boolean;
  rejectedCount: number;
  submitTimestamps: number[];
}

/// Reads the guard document and repairs it against the files it points at.
///
/// The guard is a denormalisation, so it can drift: a file deleted by hand (a
/// data protection request handled manually, a console cleanup) would otherwise
/// leave `pendingId` or `verified` pointing at nothing. The provider would then
/// be refused forever, and revoke could not help either since it requires an
/// approved file to exist. Reconciling here is the only way out.
async function reconcileState(
  tx: admin.firestore.Transaction,
  raw: Record<string, unknown>
): Promise<GuardState> {
  const state: GuardState = {
    pendingId: (raw.pendingId as string | null) ?? null,
    approvedId: (raw.approvedId as string | null) ?? null,
    verified: raw.verified === true,
    rejectedCount:
      typeof raw.rejectedCount === 'number' ? raw.rejectedCount : 0,
    submitTimestamps: Array.isArray(raw.submitTimestamps)
      ? (raw.submitTimestamps as number[]).filter(
          (v) => typeof v === 'number'
        )
      : [],
  };

  if (state.pendingId) {
    const snap = await tx.get(
      db().collection(VERIFICATIONS).doc(state.pendingId)
    );
    if (!snap.exists || snap.data()?.status !== 'pending') {
      state.pendingId = null;
    }
  }

  if (state.verified) {
    const approved = state.approvedId
      ? await tx.get(db().collection(VERIFICATIONS).doc(state.approvedId))
      : null;
    if (!approved || !approved.exists || approved.data()?.status !== 'approved') {
      state.verified = false;
      state.approvedId = null;
    }
  }

  return state;
}

/// Confirms the three objects exist under the caller's own prefix and freezes
/// their fingerprints. A file pointing at nothing would be undecidable, and a
/// fingerprint is what lets the decision step notice a swapped image.
async function readFingerprints(paths: {
  recto: string;
  verso: string;
  selfie: string;
}): Promise<Record<'recto' | 'verso' | 'selfie', IdentityFileMetadata>> {
  const bucket = admin.storage().bucket();
  const entries = await Promise.all(
    (['recto', 'verso', 'selfie'] as const).map(async (key) => {
      const file = bucket.file(paths[key]);
      const [exists] = await file.exists();
      if (!exists) {
        throw new HttpsError(
          'invalid-argument',
          'Les trois images du dossier sont introuvables.'
        );
      }
      const [metadata] = await file.getMetadata();
      const generation = metadata.generation ? String(metadata.generation) : '';
      const md5Hash = metadata.md5Hash ? String(metadata.md5Hash) : '';
      if (!generation || !md5Hash) {
        // Treated as a refusal rather than as two undefined values comparing
        // equal later, which would silently disable the immutability check.
        throw new HttpsError(
          'failed-precondition',
          'Impossible de figer l empreinte des images.'
        );
      }
      return [key, { generation, md5Hash }] as const;
    })
  );
  return Object.fromEntries(entries) as Record<
    'recto' | 'verso' | 'selfie',
    IdentityFileMetadata
  >;
}

/// Runs the extraction and the duplicate search, then writes both in a single
/// conditional update. Never throws: a failed extraction leaves an empty file
/// for a human to fill in, and never blocks a provider.
export async function runExtraction(
  docId: string,
  uid: string,
  rectoPath: string
): Promise<void> {
  // The WHOLE body is best effort, not just the extraction call. The duplicate
  // search uses a collection group index that is built asynchronously after a
  // deploy: while it builds, the query raises FAILED_PRECONDITION. Guarding
  // only the detect call would make the callable fail AFTER the main
  // transaction committed, leaving a pending file, a consumed rate-limit slot,
  // and a provider convinced their submission failed while a replay tells them
  // one is already in progress.
  try {
    await extractAndFlag(docId, uid, rectoPath);
  } catch {
    // No card number, no name and no object path in the log (budget line S12).
    logger.warn('Identity extraction step failed', { verificationId: docId });
  }
}

export async function extractAndFlag(
  docId: string,
  uid: string,
  rectoPath: string
): Promise<void> {
  let outcome: ExtractionOutcome = { ...FAILED_EXTRACTION };
  try {
    const bucket = admin.storage().bucket().name;
    const lines = await activeExtractor.detect(`gs://${bucket}/${rectoPath}`);
    outcome = extractionFromLines(lines);
  } catch {
    logger.warn('Identity extraction failed', { verificationId: docId });
  }

  const duplicate = outcome.cniNumberKey
    ? await findDuplicate(outcome.cniNumberKey, uid)
    : null;

  const verifRef = db().collection(VERIFICATIONS).doc(docId);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(verifRef);
    // Only ever write onto a file still awaiting its extraction. Otherwise a
    // late result could overwrite a reviewer's correction.
    if (
      !snap.exists ||
      snap.data()?.status !== 'pending' ||
      snap.data()?.extractionStatus !== 'pending'
    ) {
      return;
    }
    tx.update(verifRef, {
      extractionStatus: outcome.status,
      mrzValid: outcome.mrzValid,
      cniNumber: outcome.cniNumber,
      cniNom: outcome.cniNom,
      cniPrenom: outcome.cniPrenom,
      cniDateNaissance: outcome.cniDateNaissance,
      cniDateExpiration: outcome.cniDateExpiration,
      cniSexe: outcome.cniSexe,
    });
    tx.update(verifRef.collection(INTERNAL_SUB).doc(INTERNAL_DOC), {
      cniNumberKey: outcome.cniNumberKey,
      mrzRaw: outcome.mrzRaw,
      doublonPotentiel: duplicate !== null,
      doublonReferenceId: duplicate,
    });
  });
}

/// Exact duplicate search, paginated.
///
/// Never searches an empty key: two files with no readable number would
/// otherwise be duplicates of each other, and the reference shown to the
/// reviewer would point at a stranger. Pages past the caller's own files, since
/// a provider who resubmits repeatedly would otherwise fill the first page with
/// their own history and hide a real duplicate.
async function findDuplicate(
  key: string,
  callerUid: string
): Promise<string | null> {
  const PAGE = 10;
  const MAX_PAGES = 3;

  let query = db()
    .collectionGroup(INTERNAL_SUB)
    .where('cniNumberKey', '==', key)
    .limit(PAGE);

  for (let page = 0; page < MAX_PAGES; page++) {
    const snap = await query.get();
    if (snap.empty) return null;

    for (const doc of snap.docs) {
      if (doc.get('providerId') !== callerUid) {
        return doc.ref.parent.parent?.id ?? null;
      }
    }
    if (snap.size < PAGE) return null;
    const last = snap.docs[snap.docs.length - 1];
    if (!last) return null;
    query = db()
      .collectionGroup(INTERNAL_SUB)
      .where('cniNumberKey', '==', key)
      .startAfter(last)
      .limit(PAGE);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Decision: approve, reject, revoke
// ---------------------------------------------------------------------------

/// Fields a reviewer may correct. The correction replaces the WHOLE set: what
/// the reviewer sends is what is stored, so a field left out is cleared rather
/// than silently kept from a failed extraction.
const EDITABLE_FIELDS = [
  'cniNumber',
  'cniNom',
  'cniPrenom',
  'cniDateNaissance',
  'cniDateExpiration',
  'cniSexe',
] as const;

export const MAX_REJECTION_REASON = 1000;

/// Same reasoning as the rejection reason: an unbounded corrected field reaches
/// the Firestore document limit and comes back as a raw gRPC code, outside the
/// published error table. A card number or a name has no legitimate reason to
/// be long.
export const MAX_EDITABLE_FIELD = 200;

/// Returns null when the caller sent NO correction at all, and a complete set
/// when they did.
///
/// The distinction is not cosmetic. Deciding without corrections means "the
/// extracted values are right", not "wipe them": treating an absent `fields` as
/// an empty one erased the six extracted fields and, worse, nulled the
/// duplicate key of the approved file. The holder of an already approved card
/// could then resubmit it on a second account without being flagged, which is
/// precisely what the duplicate search exists to catch.
/// A document id must be a plain segment. `requireString` already rejects the
/// empty string, but a value carrying a slash reaches the SDK and comes back as
/// an untyped error, outside the published error table.
function requireVerificationId(raw: unknown): string {
  const value = requireString(raw, 'verificationId');
  if (value.includes('/') || value.includes('..')) {
    throw new HttpsError('invalid-argument', "Le champ 'verificationId' est invalide.");
  }
  return value;
}

function readEditableFields(raw: unknown): Record<string, string | null> | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== 'object' || Array.isArray(raw)) {
    // Present but malformed is refused, never silently read as "no correction":
    // a review screen serialising its form badly would otherwise approve while
    // dropping what the reviewer typed, with no signal at all.
    throw new HttpsError('invalid-argument', "Le champ 'fields' est invalide.");
  }
  const input = raw as Record<string, unknown>;
  const out: Record<string, string | null> = {};
  for (const key of EDITABLE_FIELDS) {
    const value = input[key];
    // Within a correction, an omitted field IS cleared: the reviewer replaces
    // the whole set (decision O6).
    if (typeof value === 'string' && value.trim().length > MAX_EDITABLE_FIELD) {
      throw new HttpsError(
        'invalid-argument',
        `Le champ '${key}' est trop long.`
      );
    }
    out[key] = typeof value === 'string' && value.trim().length > 0
      ? value.trim()
      : null;
  }
  return out;
}

/// Confirms the three objects still carry the fingerprints frozen at
/// submission. This is the second half of the immutability guard: the Storage
/// rule is the first, and this catches the case where the rule was relaxed by
/// mistake later, on a path where the mistake would not be visible.
async function assertFingerprintsUnchanged(
  internal: admin.firestore.DocumentData
): Promise<void> {
  const bucket = admin.storage().bucket();
  const parts = [
    ['recto', internal.rectoPath, internal.rectoGeneration, internal.rectoMd5],
    ['verso', internal.versoPath, internal.versoGeneration, internal.versoMd5],
    ['selfie', internal.selfiePath, internal.selfieGeneration, internal.selfieMd5],
  ] as const;

  for (const [, path, generation, md5] of parts) {
    if (typeof path !== 'string' || !generation || !md5) {
      throw new HttpsError(
        'failed-precondition',
        'Empreinte de piece manquante, dossier non decidable.'
      );
    }
    let metadata;
    try {
      [metadata] = await bucket.file(path).getMetadata();
    } catch {
      // A missing object (manual cleanup, an interrupted account deletion)
      // must surface as the published refusal code, not as a raw storage error.
      throw new HttpsError(
        'failed-precondition',
        'Une piece est introuvable, dossier non decidable.'
      );
    }
    if (String(metadata.generation) !== String(generation) ||
        String(metadata.md5Hash) !== String(md5)) {
      throw new HttpsError(
        'failed-precondition',
        'Une piece a change depuis le depot, dossier non decidable.'
      );
    }
  }
}

interface DecisionOptions {
  status: 'approved' | 'rejected' | 'revoked';
  action: string;
  requireApprovedSource: boolean;
  checkFingerprints: boolean;
}

async function decide(
  callerUid: string,
  verificationId: string,
  reason: string | null,
  fields: Record<string, string | null> | null,
  opts: DecisionOptions
): Promise<{ verificationId: string; status: string }> {
  const verifRef = db().collection(VERIFICATIONS).doc(verificationId);
  const internalRef = verifRef.collection(INTERNAL_SUB).doc(INTERNAL_DOC);

  const internalSnap = await internalRef.get();
  if (!internalSnap.exists) {
    throw new HttpsError('not-found', 'Dossier introuvable.');
  }
  if (opts.checkFingerprints) {
    // Read outside the transaction: a network call inside one is repeated on
    // contention. Revoke skips this entirely, see revokeIdentityVerification.
    await assertFingerprintsUnchanged(internalSnap.data() ?? {});
  }

  const providerId = await db().runTransaction(async (tx) => {
    const snap = await tx.get(verifRef);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Dossier introuvable.');
    }
    const data = snap.data() ?? {};
    const expected = opts.requireApprovedSource ? 'approved' : 'pending';
    if (data.status !== expected) {
      throw new HttpsError(
        'failed-precondition',
        `Dossier deja traite (${String(data.status)}).`
      );
    }

    const uid = String(data.providerId);
    const stateRef = db().collection(STATES).doc(uid);
    const stateSnap = await tx.get(stateRef);
    const state = stateSnap.data() ?? {};

    // An extraction still pending long after submission is dead: normalise it
    // here, the only place in this increment able to observe it.
    const submittedAtMs = (data.submittedAt as admin.firestore.Timestamp | null)
      ?.toMillis?.();
    const staleExtraction =
      data.extractionStatus === 'pending' &&
      typeof submittedAtMs === 'number' &&
      Date.now() - submittedAtMs > EXTRACTION_STALE_MS;

    tx.update(verifRef, {
      status: opts.status,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(reason !== null ? { rejectionReason: reason } : {}),
      ...(fields ?? {}),
      ...(staleExtraction ? { extractionStatus: 'failed' } : {}),
    });

    if (fields) {
      // The duplicate key must follow a corrected number, otherwise a real
      // duplicate becomes invisible to every later submission.
      tx.update(internalRef, {
        cniNumberKey: normalizeCniNumber(fields.cniNumber) || null,
        reviewedBy: callerUid,
      });
    } else {
      tx.update(internalRef, { reviewedBy: callerUid });
    }

    const rejectedCount =
      (typeof state.rejectedCount === 'number' ? state.rejectedCount : 0) +
      (opts.status === 'rejected' ? 1 : 0);

    tx.set(
      stateRef,
      {
        pendingId: null,
        approvedId: opts.status === 'approved' ? verificationId : null,
        verified: opts.status === 'approved',
        rejectedCount,
        submitTimestamps: Array.isArray(state.submitTimestamps)
          ? state.submitTimestamps
          : [],
      },
      { merge: true }
    );

    // D6-a (Amath, 2026-08-21): the public "Verified" badge reads this
    // server-owned boolean on the provider profile, never a client-supplied
    // field. Written ONLY here, in the same transaction as the verdict, so the
    // badge can never diverge from the guard. approve -> true, reject/revoke ->
    // false. Firestore rules forbid the owner from writing this key, so a
    // provider can never grant themselves the badge.
    tx.set(
      db().collection(PROVIDERS).doc(uid),
      { [IDENTITY_VERIFIED_FIELD]: opts.status === 'approved' },
      { merge: true }
    );

    // Inside the transaction: an untraced decision on an identity document
    // would break "every staff action is traced" without anything noticing.
    // Never the free-text reason and never an extracted field: admin_logs
    // survives account deletion, so it must carry no identity data.
    writeAdminLogTx(tx, {
      actorUid: callerUid,
      action: opts.action,
      targetType: 'identity_verification',
      targetId: verificationId,
      notes: reason !== null ? 'reason_stored_on_dossier' : undefined,
    });

    return uid;
  });

  const titles: Record<string, [string, string]> = {
    approved: ['Identite verifiee', 'Votre identite a bien ete verifiee.'],
    rejected: [
      'Verification refusee',
      reason ? `Votre dossier a ete refuse : ${reason}` : 'Votre dossier a ete refuse.',
    ],
    revoked: [
      'Verification retiree',
      reason ? `Votre verification a ete retiree : ${reason}` : 'Votre verification a ete retiree.',
    ],
  };
  const [title, body] = titles[opts.status] ?? ['Verification', ''];

  // After the commit: these can fail without compromising the verdict, which is
  // the state. The push body is truncated to stay well inside the FCM payload.
  try {
    await createNotification(providerId, {
      type: `identity_${opts.status}`,
      title,
      body,
      audience: 'provider',
    });
    await sendPushToUsers([providerId], { title, body: body.slice(0, 500) }, {
      type: `identity_${opts.status}`,
    });
  } catch {
    // The verdict, its audit entry and the guard are already committed. Failing
    // the call here would tell a reviewer their decision did not go through,
    // and their retry would be refused as already decided.
    logger.warn('Identity decision notification failed', {
      verificationId,
    });
  }

  return { verificationId, status: opts.status };
}

export const approveIdentityVerification = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  // NOT assertMinSupportClaim, which approveService uses and which lets
  // `support` in. The circle that sees identity documents stops at moderator.
  assertAdminOrModeratorClaim(
    request.auth?.token as Record<string, unknown> | undefined
  );

  const verificationId = requireVerificationId(request.data?.verificationId);
  return decide(callerUid, verificationId, null, readEditableFields(request.data?.fields), {
    status: 'approved',
    action: 'approve_identity_verification',
    requireApprovedSource: false,
    checkFingerprints: true,
  });
});

export const rejectIdentityVerification = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(
    request.auth?.token as Record<string, unknown> | undefined
  );

  const verificationId = requireVerificationId(request.data?.verificationId);
  const reason = requireString(request.data?.reason, 'reason');
  if (reason.length > MAX_REJECTION_REASON) {
    throw new HttpsError('invalid-argument', 'Motif trop long.');
  }

  return decide(callerUid, verificationId, reason, readEditableFields(request.data?.fields), {
    status: 'rejected',
    action: 'reject_identity_verification',
    requireApprovedSource: false,
    checkFingerprints: true,
  });
});

export const revokeIdentityVerification = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  // Admin only: undoing an established fact sits one notch above granting it.
  assertAdminClaim(request.auth?.token?.admin);

  const verificationId = requireVerificationId(request.data?.verificationId);
  const reason = requireString(request.data?.reason, 'reason');
  if (reason.length > MAX_REJECTION_REASON) {
    throw new HttpsError('invalid-argument', 'Motif trop long.');
  }

  return decide(callerUid, verificationId, reason, null, {
    status: 'revoked',
    action: 'revoke_identity_verification',
    requireApprovedSource: true,
    // No fingerprint check: a revoke undoes an established fact, and refusing it
    // because an image was altered would block it exactly when it is most
    // needed.
    checkFingerprints: false,
  });
});
