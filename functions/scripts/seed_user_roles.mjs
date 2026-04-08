// Seed user_roles/ collection from existing Firebase Auth custom claims.
// Run once after deploy to backfill existing admin/moderator accounts.

import { readFileSync } from 'fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json');
  process.exit(1);
}
const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();
const result = await getAuth().listUsers();

let seeded = 0;
for (const user of result.users) {
  const claims = user.customClaims ?? {};
  if (!claims.admin && !claims.moderator) continue;

  await db.collection('user_roles').doc(user.uid).set({
    uid: user.uid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    admin: claims.admin === true,
    moderator: claims.moderator === true,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`✅ ${user.email} → admin:${claims.admin ?? false} moderator:${claims.moderator ?? false}`);
  seeded++;
}

console.log(`\nDone — ${seeded} rôle(s) synchronisé(s) dans user_roles/`);
