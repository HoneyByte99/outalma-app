/**
 * Backfill the public_profiles projection for existing users.
 *
 * Mirrors src/public_profiles.ts::projectPublicProfile: writes ONLY the PII-free
 * display fields (displayName, photoPath?, country?, phoneVerified) so guests can
 * resolve provider/reviewer names without the users collection being world-read.
 * email and phoneE164 are never written. Idempotent (full set() per doc).
 *
 * Run: node scripts/backfill-public-profiles.js
 */
const admin = require('../functions/node_modules/firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(require('./service-account.json')),
});

const db = admin.firestore();

/** Same projection the mirrorPublicProfile trigger applies. */
function projectPublicProfile(user) {
  const displayName =
    typeof user.displayName === 'string' ? user.displayName : '';
  const profile = {
    displayName,
    phoneVerified:
      typeof user.phoneE164 === 'string' && user.phoneE164.length > 0,
  };
  if (typeof user.photoPath === 'string' && user.photoPath.length > 0) {
    profile.photoPath = user.photoPath;
  }
  if (typeof user.country === 'string' && user.country.length > 0) {
    profile.country = user.country;
  }
  return profile;
}

async function main() {
  const snap = await db.collection('users').get();
  console.log(`Found ${snap.size} users`);

  let batch = db.batch();
  let pending = 0;
  let written = 0;

  for (const doc of snap.docs) {
    const proj = projectPublicProfile(doc.data());
    batch.set(db.collection('public_profiles').doc(doc.id), proj);
    pending++;
    written++;
    // Log name only (no PII).
    console.log(`  ✅ ${doc.id} → "${proj.displayName}" (verified=${proj.phoneVerified})`);
    if (pending >= 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();

  console.log(`\nDone. Wrote ${written} public_profiles.`);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
