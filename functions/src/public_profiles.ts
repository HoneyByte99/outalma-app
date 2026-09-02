// ---------------------------------------------------------------------------
// Public profile projection
// ---------------------------------------------------------------------------
//
// `users/{uid}` is readable only by a signed-in account because it carries
// `email` and `phoneE164`. A visitor with no account still browses the
// catalogue, and every service card, service detail and review carries the
// name and avatar of a user. Reading `users` there fails; opening `users` would
// publish the PII. So a PII-free projection is mirrored into a world-readable
// collection:
//
//   public_profiles/{uid} =
//     { displayName, photoPath?, country?, phoneVerified, gender? }
//
// Written EXCLUSIVELY here (the Firestore rule denies every client write), so
// the projection can never be poisoned and cannot drift into holding PII.
//
//   mirrorPublicProfile    - keeps the projection in sync on every users write
//   backfillPublicProfiles - one-shot admin backfill for pre-existing users

import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { assertAuthenticated, assertAdminClaim } from './common';

const db = () => admin.firestore();

export const PUBLIC_PROFILES = 'public_profiles';

/// The two values a declared gender can take. Stated here as well as in the
/// Dart enum and in firestore.rules, on purpose: the projection is a security
/// boundary and must not widen just because a client wrote something else into
/// `users`. Anything outside this list is dropped, not passed through.
export const GENDERS = ['male', 'female'] as const;
export type Gender = (typeof GENDERS)[number];

export interface PublicProfile {
  displayName: string;
  photoPath?: string;
  country?: string;
  /// Whether a verified number is on file. The BOOLEAN only: `phoneE164` never
  /// crosses into the public document, so the trust badge on a public profile
  /// can be rendered without exposing the number behind it.
  phoneVerified: boolean;
  /// The gender the person declared at sign-up. Public because the catalogue
  /// card and the service detail are GUEST surfaces and resolve the provider
  /// through this document. Not PII in the sense this collection guards
  /// against: it is not a contact route and not an identifier, and it is shown
  /// deliberately, by a product decision, on the very card it is projected for.
  ///
  /// Omitted, never null, when the source has no value: 50 of the 50 accounts
  /// in production predate the field, and the client renders nothing for them.
  gender?: Gender;
}

/**
 * Projects a `users/{uid}` document down to the PII-free public fields.
 *
 * This function is the whole security boundary of the collection: it is an
 * ALLOWLIST, built key by key, never a copy of the source with a few keys
 * deleted. A denylist would leak the next PII field someone adds to `users`.
 *
 * Optional fields are OMITTED rather than written as null or as a default. An
 * absent `country` means the user declared none, and 'FR' would invent one.
 *
 * Returns null when the source document is absent (account deleted).
 */
export function projectPublicProfile(
  user: Record<string, unknown> | undefined
): PublicProfile | null {
  if (!user) return null;
  const profile: PublicProfile = {
    displayName: typeof user.displayName === 'string' ? user.displayName : '',
    phoneVerified:
      typeof user.phoneE164 === 'string' && user.phoneE164.length > 0,
  };
  if (typeof user.photoPath === 'string' && user.photoPath.length > 0) {
    profile.photoPath = user.photoPath;
  }
  if (typeof user.country === 'string' && user.country.length > 0) {
    profile.country = user.country;
  }
  // Value-checked, not merely type-checked, unlike the two fields above. Those
  // are free text the user owns; this one is an enum the interface turns into a
  // pictogram, and the legacy FlutterFlow export used the same key name with
  // another vocabulary. Anything but the two canonical values is dropped, so an
  // unknown string shows nothing rather than a wrong glyph.
  if (GENDERS.includes(user.gender as Gender)) {
    profile.gender = user.gender as Gender;
  }
  return profile;
}

/**
 * True when two projections would render identically, so an unrelated change to
 * `users` (a pushToken refresh fires on every app start) does not cost a write
 * and does not wake every listener on a public card.
 */
export function projectionsEqual(
  a: PublicProfile | null,
  b: PublicProfile | null
): boolean {
  if (a === null || b === null) return a === b;
  return (
    a.displayName === b.displayName &&
    (a.photoPath ?? null) === (b.photoPath ?? null) &&
    (a.country ?? null) === (b.country ?? null) &&
    (a.gender ?? null) === (b.gender ?? null) &&
    a.phoneVerified === b.phoneVerified
  );
}

// ---------------------------------------------------------------------------
// mirrorPublicProfile - trigger on every users/{uid} write
// ---------------------------------------------------------------------------

export const mirrorPublicProfile = onDocumentWritten(
  'users/{uid}',
  async (event) => {
    const uid = event.params.uid;
    const ref = db().collection(PUBLIC_PROFILES).doc(uid);

    const after = projectPublicProfile(event.data?.after.data());

    // Source deleted: drop the projection. deleteMyAccount also deletes it in
    // its own batch, on purpose. Erasure must not depend on a trigger firing.
    if (after === null) {
      await ref.delete();
      return;
    }

    if (projectionsEqual(projectPublicProfile(event.data?.before.data()), after)) {
      return;
    }

    // set(), not set({merge:true}): a full overwrite guarantees that a removed
    // avatar disappears from the public document and that no stale or foreign
    // key can ever accumulate in a collection the whole internet can read.
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
    batch.set(db().collection(PUBLIC_PROFILES).doc(doc.id), proj);
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
