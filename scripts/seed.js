/**
 * Outalma — seed script
 *
 * Creates realistic test users, provider profiles, and published services
 * directly in the outalmaservice-d1e59 Firestore project.
 *
 * Usage (from repo root):
 *   node scripts/seed.js
 *
 * Requires: firebase CLI login (`firebase login`)
 * Node.js >= 18
 */

const path = require('path');
const os = require('os');
const fs = require('fs');
const admin = require('../functions/node_modules/firebase-admin');

// Resolve credential:
//   1. GOOGLE_APPLICATION_CREDENTIALS env var (standard ADC)
//   2. scripts/service-account.json alongside this file
function resolveCredential() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return admin.credential.applicationDefault();
  }
  const localKey = path.join(__dirname, 'service-account.json');
  if (fs.existsSync(localKey)) {
    return admin.credential.cert(localKey);
  }
  console.error(
    '\n❌  No credentials found.\n' +
    '    Option A: set GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json\n' +
    '    Option B: place a service account key at scripts/service-account.json\n\n' +
    '    Get a key: Firebase Console → Project Settings → Service Accounts\n' +
    '              → Generate new private key\n'
  );
  process.exit(1);
}

admin.initializeApp({
  projectId: 'outalmaservice-d1e59',
  credential: resolveCredential(),
});

const auth = admin.auth();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const ts = () => admin.firestore.FieldValue.serverTimestamp();

async function upsertAuthUser({ email, password, displayName }) {
  try {
    const existing = await auth.getUserByEmail(email);
    console.log(`  ✓ auth user exists: ${email} (${existing.uid})`);
    return existing.uid;
  } catch {
    const created = await auth.createUser({ email, password, displayName });
    console.log(`  + auth user created: ${email} (${created.uid})`);
    return created.uid;
  }
}

async function upsertDoc(collection, id, data) {
  await db.collection(collection).doc(id).set(data, { merge: true });
}

// ---------------------------------------------------------------------------
// Test accounts
// ---------------------------------------------------------------------------

const TEST_PASSWORD = 'outalma2024!';

const users = [
  // Clients
  {
    email: 'client1@outalma.test',
    displayName: 'Sophie Martin',
    country: 'FR',
    phoneE164: '+33612345601',
    activeMode: 'client',
  },
  {
    email: 'client2@outalma.test',
    displayName: 'Mamadou Diallo',
    country: 'SN',
    phoneE164: '+221771234501',
    activeMode: 'client',
  },
  // Providers (also have client mode available)
  {
    email: 'provider1@outalma.test',
    displayName: 'Marie Leclerc',
    country: 'FR',
    phoneE164: '+33698765401',
    activeMode: 'provider',
  },
  {
    email: 'provider2@outalma.test',
    displayName: 'Ahmed Sow',
    country: 'SN',
    phoneE164: '+221772345601',
    activeMode: 'provider',
  },
  {
    email: 'provider3@outalma.test',
    displayName: 'Pierre Dubois',
    country: 'FR',
    phoneE164: '+33611223344',
    activeMode: 'provider',
  },
  {
    email: 'provider4@outalma.test',
    displayName: 'Fatou Ndiaye',
    country: 'SN',
    phoneE164: '+221703456789',
    activeMode: 'provider',
  },
];

// ---------------------------------------------------------------------------
// Services catalogue
// ---------------------------------------------------------------------------

function services(providerUids) {
  const [marie, ahmed, pierre, fatou] = providerUids;

  return [
    // ---- Marie Leclerc — Ménage ----
    {
      providerId: marie,
      categoryId: 'menage',
      title: 'Ménage complet appartement',
      description:
        'Nettoyage en profondeur de votre appartement : sols, sanitaires, cuisine, poussières. Produits fournis. Disponible du lundi au samedi.',
      priceType: 'hourly',
      price: 2500, // 25 €/h en centimes
      published: true,
      serviceZones: [{ label: 'Paris 11e', lat: 48.8584, lng: 2.3808, radiusKm: 10 }],
      photos: [],
    },
    {
      providerId: marie,
      categoryId: 'menage',
      title: 'Nettoyage de printemps',
      description:
        'Grand ménage saisonnier : vitres, placards, four, réfrigérateur, terrasse. Idéal avant ou après un déménagement.',
      priceType: 'fixed',
      price: 18000, // 180 € forfait
      published: true,
      serviceZones: [{ label: 'Paris', lat: 48.8566, lng: 2.3522, radiusKm: 30 }],
      photos: [],
    },

    // ---- Ahmed Sow — Jardinage ----
    {
      providerId: ahmed,
      categoryId: 'jardinage',
      title: 'Tonte de pelouse & entretien',
      description:
        'Tonte, ramassage des tontes, désherbage des bordures. Matériel professionnel fourni. Résultat impeccable garanti.',
      priceType: 'hourly',
      price: 3000, // 30 €/h
      published: true,
      serviceZones: [{ label: 'Dakar', lat: 14.6928, lng: -17.4467, radiusKm: 20 }],
      photos: [],
    },
    {
      providerId: ahmed,
      categoryId: 'jardinage',
      title: 'Taille de haies et arbustes',
      description:
        'Taille soignée de haies, arbustes et petits arbres. Ramassage et évacuation des déchets verts inclus.',
      priceType: 'fixed',
      price: 8000, // 80 €
      published: true,
      serviceZones: [{ label: 'Dakar', lat: 14.6928, lng: -17.4467, radiusKm: 30 }, { label: 'Rufisque', lat: 14.7167, lng: -17.2667, radiusKm: 10 }],
      photos: [],
    },
    {
      providerId: ahmed,
      categoryId: 'jardinage',
      title: 'Création et aménagement jardin',
      description:
        'Conception et mise en place d\'espaces verts : plantation, allées, massifs fleuris. Devis gratuit sur place.',
      priceType: 'fixed',
      price: 35000, // 350 €
      published: true,
      serviceZones: [{ label: 'Dakar', lat: 14.6928, lng: -17.4467, radiusKm: 50 }],
      photos: [],
    },

    // ---- Pierre Dubois — Plomberie ----
    {
      providerId: pierre,
      categoryId: 'plomberie',
      title: 'Réparation fuite robinet & tuyauterie',
      description:
        'Intervention rapide pour fuites, robinetterie défectueuse, joints. Devis gratuit avant intervention. Disponible en urgence.',
      priceType: 'hourly',
      price: 6500, // 65 €/h
      published: true,
      serviceZones: [{ label: 'Lyon centre', lat: 45.7640, lng: 4.8357, radiusKm: 10 }],
      photos: [],
    },
    {
      providerId: pierre,
      categoryId: 'plomberie',
      title: 'Débouchage canalisation',
      description:
        'Débouchage lavabo, évier, WC, douche. Utilisation de furet électrique. Garantie 30 jours sur l\'intervention.',
      priceType: 'fixed',
      price: 9000, // 90 €
      published: true,
      serviceZones: [{ label: 'Lyon', lat: 45.7640, lng: 4.8357, radiusKm: 25 }],
      photos: [],
    },
    {
      providerId: pierre,
      categoryId: 'plomberie',
      title: 'Installation équipement sanitaire',
      description:
        'Pose de lavabo, WC, douche, baignoire, mitigeur. Travail soigné avec finitions propres. Évacuation ancien matériel.',
      priceType: 'fixed',
      price: 25000, // 250 €
      published: true,
      serviceZones: [{ label: 'Lyon', lat: 45.7640, lng: 4.8357, radiusKm: 30 }],
      photos: [],
    },

    // ---- Fatou Ndiaye — Ménage + Autre ----
    {
      providerId: fatou,
      categoryId: 'menage',
      title: 'Entretien maison & repassage',
      description:
        'Ménage hebdomadaire ou ponctuel, repassage linge, rangement. Sérieuse et discrète. Références disponibles.',
      priceType: 'hourly',
      price: 2000, // 20 €/h
      published: true,
      serviceZones: [{ label: 'Dakar, Mermoz', lat: 14.7055, lng: -17.4686, radiusKm: 15 }],
      photos: [],
    },
    {
      providerId: fatou,
      categoryId: 'gardeEnfants',
      title: 'Garde d\'enfants à domicile',
      description:
        'Garde d\'enfants de 2 à 12 ans. Aide aux devoirs incluse pour les scolaires. Expérience 5 ans, diplômée BAFA.',
      priceType: 'hourly',
      price: 1500, // 15 €/h
      published: true,
      serviceZones: [{ label: 'Dakar centre', lat: 14.6928, lng: -17.4467, radiusKm: 10 }],
      photos: [],
    },

    // ---- Bricolage ----
    {
      providerId: pierre,
      categoryId: 'bricolage',
      title: 'Montage de meubles',
      description:
        'Montage de tous types de meubles (IKEA, But, Conforama…). Rapide et soigné. À partir de 2 meubles, déplacement offert.',
      priceType: 'fixed',
      price: 5000, // 50 €
      published: true,
      serviceZones: [{ label: 'Lyon', lat: 45.7640, lng: 4.8357, radiusKm: 20 }],
      photos: [],
    },
  ];
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log('\n🌱  Outalma seed — starting\n');

  // 1. Create / fetch auth users
  console.log('▶  Creating auth users…');
  const uids = [];
  for (const u of users) {
    const uid = await upsertAuthUser({
      email: u.email,
      password: TEST_PASSWORD,
      displayName: u.displayName,
    });
    uids.push(uid);
  }

  const [client1Uid, client2Uid, marie, ahmed, pierre, fatou] = uids;

  // 2. Write user documents
  console.log('\n▶  Writing user documents…');
  for (let i = 0; i < users.length; i++) {
    const u = users[i];
    const uid = uids[i];
    await upsertDoc('users', uid, {
      displayName: u.displayName,
      email: u.email,
      phoneE164: u.phoneE164,
      country: u.country,
      activeMode: u.activeMode,
      pushToken: null,
      createdAt: ts(),
    });
    console.log(`  ✓ users/${uid} — ${u.displayName}`);
  }

  // 3. Write provider profiles
  console.log('\n▶  Writing provider profiles…');
  const providerProfiles = [
    {
      uid: marie,
      bio: 'Agent d\'entretien professionnelle depuis 8 ans. Sérieuse, ponctuelle et minutieuse. Je prends soin de votre chez-vous comme si c\'était le mien.',
      serviceZones: [{ label: 'Paris 11e', lat: 48.8584, lng: 2.3808, radiusKm: 10 }],
    },
    {
      uid: ahmed,
      bio: 'Jardinier paysagiste avec 10 ans d\'expérience. Spécialisé dans les jardins tropicaux et méditerranéens. Passionné par les plantes.',
      serviceArea: 'Dakar et banlieue',
    },
    {
      uid: pierre,
      bio: 'Plombier certifié, 12 ans de métier. Interventions rapides et propres. Tous travaux sanitaires, chauffage, climatisation.',
      serviceZones: [{ label: 'Lyon', lat: 45.7640, lng: 4.8357, radiusKm: 25 }],
    },
    {
      uid: fatou,
      bio: 'Aide à domicile polyvalente : ménage, repassage, garde d\'enfants. Travail soigné, références vérifiables. Disponible en semaine et week-end.',
      serviceArea: 'Dakar centre et Mermoz',
    },
  ];

  for (const p of providerProfiles) {
    await upsertDoc('providers', p.uid, {
      uid: p.uid,
      bio: p.bio,
      serviceArea: p.serviceArea,
      active: true,
      suspended: false,
      createdAt: ts(),
    });
    console.log(`  ✓ providers/${p.uid}`);
  }

  // 4. Write services
  console.log('\n▶  Writing services…');
  const servicesList = services([marie, ahmed, pierre, fatou]);

  for (const s of servicesList) {
    const ref = db.collection('services').doc();
    await ref.set({ ...s, createdAt: ts(), updatedAt: ts() });
    console.log(`  ✓ services/${ref.id} — "${s.title}"`);
  }

  // 5. Print test credentials
  console.log('\n' + '─'.repeat(60));
  console.log('✅  Seed complete!\n');
  console.log('TEST CREDENTIALS (password: outalma2024!)');
  console.log('─'.repeat(60));
  console.log('CLIENTS');
  console.log(`  Sophie Martin  → client1@outalma.test`);
  console.log(`  Mamadou Diallo → client2@outalma.test`);
  console.log('\nPRESTATAIRES');
  console.log(`  Marie Leclerc  → provider1@outalma.test  (Ménage, Paris)`);
  console.log(`  Ahmed Sow      → provider2@outalma.test  (Jardinage, Dakar)`);
  console.log(`  Pierre Dubois  → provider3@outalma.test  (Plomberie, Lyon)`);
  console.log(`  Fatou Ndiaye   → provider4@outalma.test  (Ménage/Autre, Dakar)`);
  console.log('─'.repeat(60) + '\n');

  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Seed failed:', err);
  process.exit(1);
});
