// ---------------------------------------------------------------------------
// Public profile projection
// ---------------------------------------------------------------------------
//
// The `users/{uid}` collection is readable only by signed-in users because it
// carries PII (email, phoneE164). But guests browsing the marketplace still
// need a provider's name and avatar on service cards and public profiles, and
// reviewers' names on the reviews list. To serve that WITHOUT exposing PII, we
// mirror only the two non-sensitive fields into a world-readable projection:
//
//   public_profiles/{uid} = { displayName, photoPath? }
//
// The projection is written EXCLUSIVELY by Cloud Functions (rules deny all
// client writes), so it can never be poisoned and never leaks email/phone.
//
//   mirrorPublicProfile     - keeps the projection in sync on every users write
//   backfillPublicProfiles  - one-shot admin backfill for pre-existing users

import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { assertAuthenticated, assertAdminClaim } from './common';

const db = () => admin.firestore();

export interface PublicProfile {
  displayName: string;
  photoPath?: string;
}

/// Projects a `users/{uid}` document down to the PII-free public fields.
///
/// ONLY `displayName` and (when present) `photoPath` survive; `email` and
/// `phoneE164` are deliberately dropped so they can never reach the public
/// collection. Returns null when the source document is absent (user deleted).
export function projectPublicProfile(
  user: Record<string, unknown> | undefined
): PublicProfile | null {
  if (!user) return null;
  const displayName =
    typeof user.displayName === 'string' ? user.displayName : '';
  const profile: PublicProfile = { displayName };
  if (typeof user.photoPath === 'string' && user.photoPath.length > 0) {
    profile.photoPath = user.photoPath;
  }
  return profile;
}

/// True when two projections would render identically, so we can skip a
/// redundant write when an unrelated user field (email, pushToken, ...) changed.
export function projectionsEqual(
  a: PublicProfile | null,
  b: PublicProfile | null
): boolean {
  if (a === null || b === null) return a === b;
  return (
    a.displayName === b.displayName &&
    (a.photoPath ?? null) === (b.photoPath ?? null)
  );
}

// ---------------------------------------------------------------------------
// mirrorPublicProfile - trigger on every users/{uid} write
// ---------------------------------------------------------------------------

export const mirrorPublicProfile = onDocumentWritten(
  'users/{uid}',
  async (event) => {
    const uid = event.params.uid;
    const ref = db().collection('public_profiles').doc(uid);

    const after = projectPublicProfile(event.data?.after.data());

    // User document deleted -> drop the public projection too.
    if (after === null) {
      await ref.delete();
      return;
    }

    const before = projectPublicProfile(event.data?.before.data());
    if (projectionsEqual(before, after)) return;

    // Full overwrite (no merge): guarantees a removed photoPath disappears and
    // no stale/foreign fields ever accumulate in the public doc.
    await ref.set(after);
    logger.info('Mirrored public profile', { uid });
  }
);

// ---------------------------------------------------------------------------
// backfillPublicProfiles - one-shot admin backfill for existing users
// ---------------------------------------------------------------------------

export const backfillPublicProfiles = onCall(async (request) => {
  assertAuthenticated(request.auth?.uid);
  assertAdminClaim(request.auth?.token?.admin);

  const snap = await db().collection('users').get();
  let batch = db().batch();
  let pending = 0;
  let written = 0;

  for (const doc of snap.docs) {
    const proj = projectPublicProfile(doc.data());
    if (proj === null) continue;
    batch.set(db().collection('public_profiles').doc(doc.id), proj);
    pending++;
    written++;
    // Firestore batches cap at 500 writes; commit well under that.
    if (pending >= 400) {
      await batch.commit();
      batch = db().batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();

  logger.info('Backfilled public profiles', { written });
  return { written };
});
