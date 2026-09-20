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
import * as path from 'path';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  assertAdminClaim,
  assertAdminOrModeratorClaim,
  assertAuthenticated,
  requireString,
} from './common';
import { writeAdminLog, writeAdminLogTx } from './audit';
import { createNotification, sendPushToUsers } from './notify';
import {
  buildObjectPaths,
  normalizeOcrLines,
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

/// Public trust projection. One document per provider, world readable and
/// `write: if false` for every client (decision E1, Amath 2026-08-22, replacing
/// D6-a).
///
/// Why a dedicated collection rather than a flag on `providers/{uid}`: budget
/// line S4 forbids protecting a trust field with a deny list, because a deny
/// list only covers the keys someone remembered to list. And the product needs
/// THREE public states (E3), which a boolean cannot carry: a client must be able
/// to tell "verification under way" from "nothing submitted".
export const TRUST = 'provider_trust';

/// The only two values the projection ever holds. Absence of the document is
/// the third state, "not verified": nothing public is ever written about a
/// provider whose file was rejected or revoked.
export type TrustStatus = 'pending' | 'verified';

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

/// Derives the public projection from the guard document, and nothing else.
///
/// Single deriver on purpose: the guard is already the serialisation point of
/// this subsystem (both the submission and the decision transactions read and
/// write it), so anything derived from it inside one of those transactions
/// cannot interleave. Every caller passes its own transaction.
///
/// Returns what was written, so callers can assert on it without re-reading.
export function projectFromGuard(
  tx: admin.firestore.Transaction,
  uid: string,
  guard: { verified: boolean; pendingId: string | null }
): TrustStatus | null {
  const ref = db().collection(TRUST).doc(uid);
  if (guard.verified) {
    tx.set(ref, {
      identityStatus: 'verified',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return 'verified';
  }
  if (guard.pendingId) {
    tx.set(ref, {
      identityStatus: 'pending',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return 'pending';
  }
  // Rejected, revoked, or never submitted: the document is deleted, so a
  // refusal is indistinguishable from an absence of submission. That is the
  // product contract (spec section 5), not an implementation detail.
  tx.delete(ref);
  return null;
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

/// Runtime the recognition pass needs. The WebAssembly core plus the language
/// data do not fit in the platform default of 256 MiB, and a cold start that
/// loads both and then recognises an image does not fit in the default timeout
/// either. Every callable that can reach the extractor declares it.
export const OCR_RUNTIME = { memory: '1GiB', timeoutSeconds: 120 } as const;

/// Language data, SHIPPED with the function rather than downloaded at cold
/// start. Resolved from the compiled file (`lib/identity_verification.js`), so
/// the same path holds in the emulator and in the deployed bundle.
const TESSDATA_DIR = path.join(__dirname, '..', 'tessdata');

/// The MRZ is printed in OCR-B, whose glyphs are the Latin ones: `eng` reads it
/// and nothing here is ever translated, so no second language is needed.
const TESSDATA_LANG = 'eng';

interface OcrWorker {
  recognize(image: Buffer): Promise<{ data: { text: string } }>;
}

/// Kept across invocations of a warm instance: loading the WebAssembly core and
/// the language data costs more than the recognition itself.
let ocrWorker: OcrWorker | null = null;

/// Splits `gs://bucket/object/path` in two.
///
/// Throws rather than guessing: the only caller builds this URI from a path the
/// server itself stored, so a malformed value is a bug in this file, never a
/// user input to be tolerated.
export function parseGcsUri(gcsUri: string): { bucket: string; objectPath: string } {
  const match = /^gs:\/\/([^/]+)\/(.+)$/.exec(gcsUri);
  if (!match?.[1] || !match[2]) {
    throw new Error('Malformed GCS URI');
  }
  return { bucket: match[1], objectPath: match[2] };
}

/// Production extractor: Tesseract (Apache 2.0), running INSIDE the function.
///
/// It replaced Cloud Vision on 2026-09-18 (decision Amath), and the reason is
/// not only the bill: an identity document now never leaves the project, so
/// there is no third-party processor to declare and no second copy of a card to
/// reason about in the data protection file.
/* istanbul ignore next -- thin adapter over the WASM recogniser and the Storage
   SDK. Everything it feeds is covered through the injected double, and covering
   the body itself would mean committing a real card image to the repository. */
export const tesseractExtractor: TextExtractor = {
  async detect(gcsUri: string): Promise<string[]> {
    const { bucket, objectPath } = parseGcsUri(gcsUri);
    const [image] = await admin.storage().bucket(bucket).file(objectPath).download();

    if (!ocrWorker) {
      const { createWorker } = await import('tesseract.js');
      ocrWorker = (await createWorker(TESSDATA_LANG, 1, {
        langPath: TESSDATA_DIR,
        // The shipped file is already decompressed, and the function filesystem
        // is read only outside /tmp: nothing may be fetched or cached at run
        // time. Both flags together are what make the pass work offline.
        gzip: false,
        cacheMethod: 'none',
      })) as unknown as OcrWorker;
    }

    const { data } = await ocrWorker.recognize(image);
    return data.text.split('\n');
  },
};

let activeExtractor: TextExtractor = tesseractExtractor;

/// Swaps the extractor. The only supported use is a test double that counts its
/// calls: "exactly one extraction per file" and "no extraction beyond the rate
/// limit" are claims about a resource we pay for, and an unobservable claim is
/// not a tested one.
export function setTextExtractor(extractor: TextExtractor): void {
  activeExtractor = extractor;
}

export function resetTextExtractor(): void {
  activeExtractor = tesseractExtractor;
}

// ---------------------------------------------------------------------------
// submitIdentityVerification
// ---------------------------------------------------------------------------

export const submitIdentityVerification = onCall(OCR_RUNTIME, async (request) => {
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
      // Same shape from the start, so a reader never has to tell "not read yet"
      // from "field never existed".
      ocrVerso: null,
      ocrRecto: null,
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

    // Public projection, in the same transaction as the guard it derives from.
    projectFromGuard(tx, uid, { verified: state.verified, pendingId: docId });

    return { alreadySubmitted: false, verificationId: docId };
  });

  if (created.alreadySubmitted) {
    // A replay, not a new submission: no second file, no second extraction, no
    // second notification. The marker lets a client tell the two apart.
    return created;
  }

  await runExtraction(docId, uid, { recto: paths.recto, verso: paths.verso });

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
  faces: IdentityFaces
): Promise<void> {
  // The WHOLE body is best effort, not just the extraction call. The duplicate
  // search uses a collection group index that is built asynchronously after a
  // deploy: while it builds, the query raises FAILED_PRECONDITION. Guarding
  // only the detect call would make the callable fail AFTER the main
  // transaction committed, leaving a pending file, a consumed rate-limit slot,
  // and a provider convinced their submission failed while a replay tells them
  // one is already in progress.
  try {
    await extractAndFlag(docId, uid, faces);
  } catch {
    // No card number, no name and no object path in the log (budget line S12).
    logger.warn('Identity extraction step failed', { verificationId: docId });
  }
}

/// Compact, PII-free description of a thrown value, for the logs.
///
/// Budget line S12 keeps identity data out of the logs, and a storage or OCR
/// error message routinely quotes the object path, which carries the provider's
/// uid: the private prefix is therefore redacted rather than trusted, and the
/// whole thing is capped so a stack-shaped message cannot flood an entry.
export function errorSummary(e: unknown): string {
  const raw =
    e instanceof Error
      ? (e as { code?: unknown }).code !== undefined
        ? `${String((e as { code?: unknown }).code)}: ${e.message}`
        : e.message
      : String(e);
  return raw.replace(/private\/identity\/\S*/g, 'private/identity/[redacted]').slice(0, 300);
}

/// The two faces of the card that may carry the machine readable zone.
export interface IdentityFaces {
  recto: string;
  verso: string;
}

/// Reads the card and returns both the MRZ outcome and the text a human can copy.
///
/// The BACK comes first, and that order is a measured fact rather than a guess:
/// on the Senegalese CEDEAO card the machine readable zone is printed on the
/// back (checked against real files on 2026-09-18, after every read of the
/// front had come back empty). The front is still tried, because other
/// documents put the zone there and a wrong assumption in this file is exactly
/// what cost the previous attempt.
///
/// The second face is skipped ONLY when the first one reads perfectly (`ok`):
/// that text is never stored, so the pass would be CPU spent on a result the
/// caller throws away one step later. On `partial` the second face IS read,
/// because a zone with a failed check digit is precisely the case where a
/// reviewer wants the printed text of both sides to compare against.
///
/// `noReadableText` is computed across the faces actually read: it means "this
/// upload carries no text at all", the review aid a human acts on. Deriving it
/// from one face would flag a perfectly good card as unreadable whenever its
/// other side happens to be blank.
///
/// It rattrape NOTHING: a throw from `detect` propagates to `extractAndFlag`,
/// which keeps its catch and its warning with the cause. That log is what made
/// the September outage visible, and swallowing it here would put it back in
/// the dark.
/// Whether the text read on the card is kept for a reviewer to copy.
///
/// OFF since 2026-09-20. The section shipped, Amath tried it on the real
/// console, and what the recogniser reads off a CEDEAO card does not help
/// enough to justify keeping a copy of the document alongside it. Manual entry
/// until a better engine exists. While this is false, every extraction writes
/// null into both fields, which also clears whatever an earlier run stored.
let keepCardText = false;

/// Test seam, same shape as `setTextExtractor`: the behaviour behind the flag
/// stays covered for the day it comes back on.
export function setKeepCardText(value: boolean): void {
  keepCardText = value;
}

export async function readCard(
  faces: IdentityFaces,
  detect: (objectPath: string) => Promise<string[]>
): Promise<{ outcome: ExtractionOutcome; ocr: { verso: string[]; recto: string[] } }> {
  let found: ExtractionOutcome | null = null;
  let sawText = false;
  const ocr = { verso: [] as string[], recto: [] as string[] };

  for (const face of ['verso', 'recto'] as const) {
    const lines = await detect(faces[face]);
    ocr[face] = normalizeOcrLines(lines);

    const candidate = extractionFromLines(lines);
    sawText = sawText || !candidate.noReadableText;
    // The FIRST face that carried a zone owns the outcome. The other face is
    // read for its text only, and must never quietly replace fields that a
    // reviewer may already be comparing against the image.
    if (found === null && candidate.status !== 'failed') found = candidate;

    // A perfect read ends it: the six fields are filled and verified by their
    // check digits, so there is nothing for a human to copy.
    if (candidate.status === 'ok') break;
  }

  const outcome = found ?? { ...FAILED_EXTRACTION };
  return { outcome: { ...outcome, noReadableText: !sawText }, ocr };
}

export async function extractAndFlag(
  docId: string,
  uid: string,
  faces: IdentityFaces
): Promise<void> {
  let outcome: ExtractionOutcome = { ...FAILED_EXTRACTION };
  let ocr: { verso: string[]; recto: string[] } | null = null;
  try {
    const bucket = admin.storage().bucket().name;
    const result = await readCard(faces, (path) =>
      activeExtractor.detect(`gs://${bucket}/${path}`)
    );
    outcome = result.outcome;
    // Assigned ONLY here, so `null` means "no face ever answered". The
    // distinction is what stops an infrastructure failure from erasing text
    // read on an earlier pass: see the write below.
    ocr = result.ocr;
  } catch (e) {
    // The CAUSE, never the content. Until 2026-09-18 this catch swallowed
    // everything, and that is exactly how a project-wide outage (the recogniser
    // API was simply not enabled) stayed invisible for weeks: every file came
    // back empty and the log said only that something had failed.
    logger.warn('Identity extraction failed', {
      verificationId: docId,
      cause: errorSummary(e),
    });
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
      // The text a reviewer copies from, when the zone could not be read for
      // them. Three cases, and the difference between them matters:
      //
      //  - a face answered and the read was imperfect: store the text;
      //  - the read was perfect: store null, because the six fields are filled
      //    and verified, so a copy of the card text would be retention with no
      //    reader. Null rather than untouched, otherwise a successful replay
      //    would leave the text of the failed attempt behind it;
      //  - nothing answered at all (`ocr === null`, the extractor threw): touch
      //    NEITHER field. Writing empty lists here would wipe the text of an
      //    earlier successful read on a transient Storage or OCR failure, and
      //    it would do so while consuming one of the five replays. That is the
      //    one thing this increment must never do to a reviewer.
      ...(!keepCardText
        ? { ocrVerso: null, ocrRecto: null }
        : ocr === null
          ? {}
          : outcome.status === 'ok'
            ? { ocrVerso: null, ocrRecto: null }
            : { ocrVerso: ocr.verso, ocrRecto: ocr.recto }),
      // Dead field of the September debugging pass, replaced by the two above.
      // Removed here and in `decide`, because this write never reaches a file
      // that is already decided.
      extractionDiagnostic: admin.firestore.FieldValue.delete(),
      // Review aid only (decision D1): no face carried readable text, so the
      // upload is likely not a document. The reviewer decides; nothing is
      // auto-rejected.
      pasDocumentLisible: outcome.noReadableText,
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

    // Dead field of the September debugging pass. It has no reader left, and
    // `extractAndFlag` can never clear it on a decided file because its own
    // guard requires `pending`: this is the only write that still reaches one.
    // It says nothing about `ocrVerso`/`ocrRecto`, which are kept on purpose
    // and die with the account.
    const dropDeadField = {
      extractionDiagnostic: admin.firestore.FieldValue.delete(),
    };

    if (fields) {
      // The duplicate key must follow a corrected number, otherwise a real
      // duplicate becomes invisible to every later submission.
      tx.update(internalRef, {
        cniNumberKey: normalizeCniNumber(fields.cniNumber) || null,
        reviewedBy: callerUid,
        ...dropDeadField,
      });
    } else {
      tx.update(internalRef, { reviewedBy: callerUid, ...dropDeadField });
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

    // Public projection (E1), in the same transaction as the verdict, so the
    // badge can never diverge from it. Approve projects "verified"; reject and
    // revoke delete the document, which is what makes a refusal publicly
    // indistinguishable from never having submitted.
    projectFromGuard(tx, uid, {
      verified: opts.status === 'approved',
      pendingId: null,
    });

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

// ---------------------------------------------------------------------------
// reextractIdentityVerification : staff-triggered second read
// ---------------------------------------------------------------------------
//
// Extraction runs once, at submission. When it fails there, the file stays
// empty for ever and the reviewer has to key in six fields from the image by
// hand, because nothing in the product could ask for a second read. Three
// causes make that common enough to need a way back: a blurred or angled photo,
// a transient storage error, and the recogniser being down project-wide, which
// is what happened until 2026-09-18.
//
// It decides nothing (budget line S1). It rewrites the same review aids the
// automatic pass writes, which a human then reads, corrects and confirms.

/// Replays allowed per file. The recogniser costs no API fee but it does cost
/// CPU and memory: without a ceiling, a held-down button turns a review screen
/// into a compute loop billed to us (budget line S8). Five is far above what a
/// genuine review needs and far below what a loop would consume.
export const MAX_EXTRACTION_RUNS = 5;

export const reextractIdentityVerification = onCall(OCR_RUNTIME, async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  // The same circle as the decision callables, which is the circle that may see
  // the images: moderator and admin, never support.
  assertAdminOrModeratorClaim(
    request.auth?.token as Record<string, unknown> | undefined
  );

  const verificationId = requireVerificationId(request.data?.verificationId);
  const verifRef = db().collection(VERIFICATIONS).doc(verificationId);
  const internalRef = verifRef.collection(INTERNAL_SUB).doc(INTERNAL_DOC);

  // One transaction arms the replay: it checks the file is still pending, counts
  // the run against the ceiling, and puts the extraction back into the `pending`
  // state that extractAndFlag requires before it writes anything. Doing the
  // three atomically is what stops two reviewers clicking at the same moment
  // from running two recognitions and racing over the result.
  const armed = await db().runTransaction(async (tx) => {
    const [verifSnap, internalSnap] = await Promise.all([
      tx.get(verifRef),
      tx.get(internalRef),
    ]);
    if (!verifSnap.exists || !internalSnap.exists) {
      throw new HttpsError('not-found', 'Dossier introuvable.');
    }

    const data = verifSnap.data() ?? {};
    if (data.status !== 'pending') {
      // A decided file carries the fields a human confirmed. Replaying on it
      // would overwrite a decision with a machine guess, silently.
      throw new HttpsError(
        'failed-precondition',
        `Dossier deja traite (${String(data.status)}).`
      );
    }

    const internal = internalSnap.data() ?? {};
    const runs =
      typeof internal.extractionRuns === 'number' ? internal.extractionRuns : 0;
    if (runs >= MAX_EXTRACTION_RUNS) {
      throw new HttpsError(
        'resource-exhausted',
        'Trop de relectures pour ce dossier.'
      );
    }

    // Both faces, because the MRZ lives on the back of the card and the front
    // is only the fallback. A file missing either path cannot be replayed the
    // way the automatic pass reads it.
    const rectoPath = internal.rectoPath;
    const versoPath = internal.versoPath;
    if (
      typeof rectoPath !== 'string' ||
      rectoPath.length === 0 ||
      typeof versoPath !== 'string' ||
      versoPath.length === 0
    ) {
      throw new HttpsError(
        'failed-precondition',
        'Piece introuvable, relecture impossible.'
      );
    }

    tx.update(verifRef, { extractionStatus: 'pending' });
    tx.update(internalRef, { extractionRuns: runs + 1 });

    // Inside the transaction, like every other decision on an identity file: a
    // staff action that leaves no trace breaks budget line S7 without anything
    // noticing. No field value and no object path in the entry.
    writeAdminLogTx(tx, {
      actorUid: callerUid,
      action: 'reextract_identity_verification',
      targetType: 'identity_verification',
      targetId: verificationId,
    });

    return {
      providerId: String(data.providerId),
      faces: { recto: rectoPath, verso: versoPath },
    };
  });

  try {
    await extractAndFlag(verificationId, armed.providerId, armed.faces);
  } catch (e) {
    // The run is already counted and the file is back to `pending`: the reviewer
    // can try again, or key the fields in by hand. Surfacing the raw SDK error
    // would put an untyped code in front of them instead.
    logger.warn('Identity re-extraction failed', {
      verificationId,
      cause: errorSummary(e),
    });
    throw new HttpsError('internal', 'La relecture a echoue.');
  }

  const after = await verifRef.get();
  return {
    verificationId,
    extractionStatus: String(after.data()?.extractionStatus ?? 'failed'),
  };
});

// ---------------------------------------------------------------------------
// getIdentityVerificationImages : staff-only, short-lived signed URLs
// ---------------------------------------------------------------------------
//
// The three identity images live under a private, staff-only bucket prefix
// (`private/identity/{uid}/{batchId}/`): no client, not even their owner, can
// read them directly (storage.rules deny every path under `private/`). The
// review screen therefore cannot load them straight from Storage. This callable
// is the only door: the SERVER signs a short-lived read URL for each object,
// so the bucket stays staff-only and the URL cannot be reused past its window.
//
// The paths are never taken from the caller: they are read from the internal
// review document written at submission, exactly like the decision callables.

/// How long a signed identity-image URL stays valid. Ten minutes: long enough
/// for a reviewer to open the three images, short enough that a leaked URL is
/// worthless almost immediately. Exported so tests reason about the window.
export const IDENTITY_IMAGE_URL_TTL_MS = 10 * 60 * 1000;

/// Signs a short-lived read URL for one Storage object. Behind an interface for
/// the same reason as the text extractor: `getSignedUrl` calls the IAM signBlob
/// API (or a local key) that the Storage emulator cannot serve, so the only way
/// to test "the callable signs exactly these three paths, and refuses the wrong
/// caller" without a billed dependency is to substitute a double.
export interface UrlSigner {
  sign(objectPath: string, expiresAtMs: number): Promise<string>;
}

/// Production signer: a v4 read URL via the bucket's default credentials. On a
/// deployed function the runtime service account holds `signBlob`, so no private
/// key is shipped.
/* istanbul ignore next -- thin adapter over the Storage SDK: there is no signer
   in the emulator, so the only way to execute this body would be to sign against
   the real API. The seam it sits behind is one line wide and covered through the
   injected double. */
export const storageUrlSigner: UrlSigner = {
  async sign(objectPath: string, expiresAtMs: number): Promise<string> {
    const [url] = await admin
      .storage()
      .bucket()
      .file(objectPath)
      .getSignedUrl({ version: 'v4', action: 'read', expires: expiresAtMs });
    return url;
  },
};

let activeSigner: UrlSigner = storageUrlSigner;

/// Swaps the URL signer. The only supported use is a test double: see UrlSigner.
export function setUrlSigner(signer: UrlSigner): void {
  activeSigner = signer;
}

export function resetUrlSigner(): void {
  activeSigner = storageUrlSigner;
}

export const getIdentityVerificationImages = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  // Same circle as the decision callables: the people who may see identity
  // documents stop at moderator. `support` never reaches the images.
  assertAdminOrModeratorClaim(
    request.auth?.token as Record<string, unknown> | undefined
  );

  const verificationId = requireVerificationId(request.data?.verificationId);

  const internalRef = db()
    .collection(VERIFICATIONS)
    .doc(verificationId)
    .collection(INTERNAL_SUB)
    .doc(INTERNAL_DOC);
  const snap = await internalRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Dossier introuvable.');
  }

  const data = snap.data() ?? {};
  const rectoPath = data.rectoPath;
  const versoPath = data.versoPath;
  const selfiePath = data.selfiePath;
  if (
    typeof rectoPath !== 'string' ||
    typeof versoPath !== 'string' ||
    typeof selfiePath !== 'string'
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Chemins de pieces manquants, dossier non consultable.'
    );
  }

  const expiresAt = Date.now() + IDENTITY_IMAGE_URL_TTL_MS;
  const [rectoUrl, versoUrl, selfieUrl] = await Promise.all([
    activeSigner.sign(rectoPath, expiresAt),
    activeSigner.sign(versoPath, expiresAt),
    activeSigner.sign(selfiePath, expiresAt),
  ]);

  // Trace the PII access. Opaque marker only: never the extracted card fields
  // (admin_logs survives account deletion, see audit.ts, and must carry no PII).
  await writeAdminLog({
    actorUid: callerUid as string,
    action: 'view_identity_verification_images',
    targetType: 'identity_verification',
    targetId: verificationId,
  });

  return { rectoUrl, versoUrl, selfieUrl };
});
