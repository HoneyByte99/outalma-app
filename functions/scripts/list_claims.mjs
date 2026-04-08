import { readFileSync } from 'fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
initializeApp({ credential: cert(serviceAccount) });

const result = await getAuth().listUsers();
const withClaims = result.users.filter(
  u => u.customClaims && Object.keys(u.customClaims).length > 0
);

if (withClaims.length === 0) {
  console.log('Aucun utilisateur avec des custom claims.');
} else {
  for (const u of withClaims) {
    console.log(`${u.email} (${u.uid}) → ${JSON.stringify(u.customClaims)}`);
  }
}
