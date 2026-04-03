/**
 * Seed realistic photos into Firestore:
 * - Services: relevant Unsplash open-source images by category
 * - Users: real person photos from randomuser.me
 *
 * All URLs are direct HTTPS links — no Storage upload needed,
 * we store the external URL in the existing photos[] / photoPath fields.
 *
 * Run: node scripts/seed-photos.js
 */

const admin = require('../functions/node_modules/firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(require('./service-account.json')),
});

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Photo banks
// ---------------------------------------------------------------------------

const SERVICE_PHOTOS = {
  menage: [
    'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=900&q=80',
    'https://images.unsplash.com/photo-1527515545081-5db817172677?w=900&q=80',
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=900&q=80',
    'https://images.unsplash.com/photo-1563453392212-326f5e854473?w=900&q=80',
  ],
  plomberie: [
    'https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=900&q=80',
    'https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=900&q=80',
    'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=900&q=80',
  ],
  jardinage: [
    'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=900&q=80',
    'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2?w=900&q=80',
    'https://images.unsplash.com/photo-1599598425997-5202edd56bdb?w=900&q=80',
    'https://images.unsplash.com/photo-1591857177580-dc82b9ac4e1e?w=900&q=80',
  ],
  autre: [
    'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=900&q=80',
    'https://images.unsplash.com/photo-1581244277943-fe4a9c777189?w=900&q=80',
    'https://images.unsplash.com/photo-1572981779307-38b8cabb2407?w=900&q=80',
  ],
};

// Diverse real person photos from randomuser.me
const PERSON_PHOTOS = [
  'https://randomuser.me/api/portraits/men/32.jpg',
  'https://randomuser.me/api/portraits/women/44.jpg',
  'https://randomuser.me/api/portraits/men/65.jpg',
  'https://randomuser.me/api/portraits/women/28.jpg',
  'https://randomuser.me/api/portraits/men/12.jpg',
  'https://randomuser.me/api/portraits/women/55.jpg',
  'https://randomuser.me/api/portraits/men/78.jpg',
  'https://randomuser.me/api/portraits/women/17.jpg',
  'https://randomuser.me/api/portraits/men/41.jpg',
  'https://randomuser.me/api/portraits/women/62.jpg',
];

// Simple deterministic picker — avoids repeating the same photo
// for consecutive docs of the same type
let _counters = {};
function pick(bank, key) {
  const arr = bank[key] ?? bank.autre ?? Object.values(bank)[0];
  _counters[key] = (_counters[key] ?? 0) % arr.length;
  return arr[_counters[key]++];
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  let servicesFixed = 0;
  let usersFixed = 0;

  // ---- Services ----
  console.log('\n📸 Updating service photos...');
  const servicesSnap = await db.collection('services').get();

  const serviceBatch = db.batch();
  for (const doc of servicesSnap.docs) {
    const data = doc.data();
    if (data.photos && data.photos.length > 0) {
      console.log(`  ✓ ${doc.id} (${data.categoryId}) — already has photo, skipping`);
      continue;
    }
    const category = data.categoryId ?? 'autre';
    const photo = pick(SERVICE_PHOTOS, category);
    serviceBatch.update(doc.ref, { photos: [photo] });
    console.log(`  ✅ ${doc.id} (${category}) → ${photo.slice(0, 60)}…`);
    servicesFixed++;
  }
  await serviceBatch.commit();

  // ---- Users ----
  console.log('\n👤 Updating user profile photos...');
  const usersSnap = await db.collection('users').get();

  let personIdx = 0;
  const userBatch = db.batch();
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    if (data.photoPath) {
      console.log(`  ✓ ${data.email ?? doc.id} — already has photo, skipping`);
      continue;
    }
    const photo = PERSON_PHOTOS[personIdx % PERSON_PHOTOS.length];
    personIdx++;
    userBatch.update(doc.ref, { photoPath: photo });
    console.log(`  ✅ ${data.email ?? doc.id} → ${photo}`);
    usersFixed++;
  }
  await userBatch.commit();

  console.log(`\nDone. Services updated: ${servicesFixed}, Users updated: ${usersFixed}`);
}

main().catch((err) => {
  console.error('❌', err.message);
  process.exit(1);
});
