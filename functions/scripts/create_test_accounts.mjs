// Create (or update) two test Firebase Auth accounts with custom claims,
// and mirror the roles into Firestore user_roles/{uid}.
// Run from the functions/ directory:
//   GOOGLE_APPLICATION_CREDENTIALS=scripts/service-account.json node scripts/create_test_accounts.mjs

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// ---------- credentials ----------
const __dir = dirname(fileURLToPath(import.meta.url));

const keyPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ??
  resolve(__dir, 'service-account.json');

let serviceAccount;
try {
  serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
} catch (err) {
  console.error(`Cannot read service account at: ${keyPath}`);
  console.error(err.message);
  process.exit(1);
}

initializeApp({ credential: cert(serviceAccount) });

const auth = getAuth();
const db   = getFirestore();

// ---------- account definitions ----------
const TEST_ACCOUNTS = [
  {
    email:       'admin.test@outalma-test.dev',
    password:    'OutalmaAdmin2024!',
    displayName: 'Admin Test',
    claims:      { admin: true, role: 'admin' },
  },
  {
    email:       'mod.test@outalma-test.dev',
    password:    'OutalmaMod2024!',
    displayName: 'Moderator Test',
    claims:      { moderator: true, role: 'moderator' },
  },
];

// ---------- helpers ----------
async function getOrCreateUser({ email, password, displayName }) {
  try {
    const existing = await auth.getUserByEmail(email);
    console.log(`  User exists — updating password: ${email}`);
    await auth.updateUser(existing.uid, { password, displayName });
    return existing.uid;
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      console.log(`  Creating new user: ${email}`);
      const created = await auth.createUser({ email, password, displayName });
      return created.uid;
    }
    throw err;
  }
}

// ---------- main ----------
for (const account of TEST_ACCOUNTS) {
  console.log(`\n[${account.email}]`);
  try {
    const uid = await getOrCreateUser(account);
    console.log(`  UID: ${uid}`);

    await auth.setCustomUserClaims(uid, account.claims);
    console.log(`  Custom claims set:`, account.claims);

    await db.collection('user_roles').doc(uid).set(
      {
        uid,
        email:     account.email,
        admin:     account.claims.admin     === true,
        moderator: account.claims.moderator === true,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    console.log(`  Firestore user_roles/${uid} written`);
    console.log(`  OK`);
  } catch (err) {
    console.error(`  ERROR: ${err.message}`);
  }
}

console.log('\nDone.');
