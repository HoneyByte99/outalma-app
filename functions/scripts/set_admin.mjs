// One-shot script — set admin claim on a user.
// Usage: node scripts/set_admin.mjs
// Requires Application Default Credentials (firebase CLI login).

import { readFileSync } from 'fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json');
  process.exit(1);
}
const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
initializeApp({ credential: cert(serviceAccount) });

const uid = 'coCVvK9Q8cbd2s7cIHPMSocLRTr1';

const user = await getAuth().getUser(uid);
const current = user.customClaims ?? {};
await getAuth().setCustomUserClaims(uid, { ...current, admin: true });

console.log(`✅ admin: true set on ${user.email} (${uid})`);
