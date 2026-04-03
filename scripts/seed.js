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

  // Axe Paris–Orléans (~130 km) pour tester le filtrage progressif :
  //   Paris       — 48.8566, 2.3522  (0 km)
  //   Évry        — 48.6244, 2.4263  (~30 km)
  //   Étampes     — 48.4369, 2.1614  (~55 km)
  //   Pithiviers  — 48.1717, 2.2519  (~85 km)
  //   Orléans     — 47.9029, 1.9090  (~130 km)

  return [
    // ---- Paris (0 km) — Marie ----
    {
      providerId: marie,
      categoryId: 'menage',
      title: 'Ménage complet appartement',
      description:
        'Nettoyage en profondeur de votre appartement : sols, sanitaires, cuisine, poussières. Produits fournis.',
      priceType: 'hourly',
      price: 2500,
      published: true,
      serviceZones: [{ label: 'Paris 11e', lat: 48.8584, lng: 2.3808, radiusKm: 10 }],
      photos: [],
    },
    {
      providerId: marie,
      categoryId: 'gardeEnfants',
      title: 'Garde d\'enfants à domicile',
      description:
        'Garde d\'enfants de 2 à 12 ans. Aide aux devoirs incluse. Expérience 5 ans, diplômée BAFA.',
      priceType: 'hourly',
      price: 1500,
      published: true,
      serviceZones: [{ label: 'Paris 5e', lat: 48.8462, lng: 2.3449, radiusKm: 15 }],
      photos: [],
    },

    // ---- Évry (~30 km) — Ahmed ----
    {
      providerId: ahmed,
      categoryId: 'jardinage',
      title: 'Tonte de pelouse & entretien',
      description:
        'Tonte, ramassage, désherbage des bordures. Matériel professionnel fourni. Résultat impeccable.',
      priceType: 'hourly',
      price: 3000,
      published: true,
      serviceZones: [{ label: 'Évry-Courcouronnes', lat: 48.6244, lng: 2.4263, radiusKm: 15 }],
      photos: [],
    },
    {
      providerId: ahmed,
      categoryId: 'jardinage',
      title: 'Taille de haies et arbustes',
      description:
        'Taille soignée de haies, arbustes et petits arbres. Ramassage et évacuation des déchets verts inclus.',
      priceType: 'fixed',
      price: 8000,
      published: true,
      serviceZones: [{ label: 'Évry-Courcouronnes', lat: 48.6244, lng: 2.4263, radiusKm: 20 }],
      photos: [],
    },

    // ---- Étampes (~55 km) — Pierre ----
    {
      providerId: pierre,
      categoryId: 'plomberie',
      title: 'Réparation fuite robinet & tuyauterie',
      description:
        'Intervention rapide pour fuites, robinetterie défectueuse, joints. Devis gratuit. Disponible en urgence.',
      priceType: 'hourly',
      price: 6500,
      published: true,
      serviceZones: [{ label: 'Étampes', lat: 48.4369, lng: 2.1614, radiusKm: 10 }],
      photos: [],
    },
    {
      providerId: pierre,
      categoryId: 'electricite',
      title: 'Dépannage électrique urgent',
      description:
        'Panne de courant, disjoncteur, remplacement de prises et interrupteurs. Intervention rapide.',
      priceType: 'hourly',
      price: 7000,
      published: true,
      serviceZones: [{ label: 'Étampes', lat: 48.4369, lng: 2.1614, radiusKm: 25 }],
      photos: [],
    },

    // ---- Pithiviers (~85 km) — Fatou ----
    {
      providerId: fatou,
      categoryId: 'menage',
      title: 'Entretien maison & repassage',
      description:
        'Ménage hebdomadaire ou ponctuel, repassage linge, rangement. Sérieuse et discrète.',
      priceType: 'hourly',
      price: 2000,
      published: true,
      serviceZones: [{ label: 'Pithiviers', lat: 48.1717, lng: 2.2519, radiusKm: 15 }],
      photos: [],
    },
    {
      providerId: fatou,
      categoryId: 'peinture',
      title: 'Peinture intérieure',
      description:
        'Mise en peinture murs et plafonds. Préparation des surfaces, application soignée, protection du mobilier.',
      priceType: 'fixed',
      price: 15000,
      published: true,
      serviceZones: [{ label: 'Pithiviers', lat: 48.1717, lng: 2.2519, radiusKm: 20 }],
      photos: [],
    },

    // ---- Orléans (~130 km) — Pierre + Ahmed ----
    {
      providerId: pierre,
      categoryId: 'plomberie',
      title: 'Installation équipement sanitaire',
      description:
        'Pose de lavabo, WC, douche, baignoire, mitigeur. Travail soigné avec finitions propres.',
      priceType: 'fixed',
      price: 25000,
      published: true,
      serviceZones: [{ label: 'Orléans', lat: 47.9029, lng: 1.9090, radiusKm: 15 }],
      photos: [],
    },
    {
      providerId: ahmed,
      categoryId: 'jardinage',
      title: 'Création et aménagement jardin',
      description:
        'Conception et mise en place d\'espaces verts : plantation, allées, massifs fleuris. Devis gratuit.',
      priceType: 'fixed',
      price: 35000,
      published: true,
      serviceZones: [{ label: 'Orléans', lat: 47.9029, lng: 1.9090, radiusKm: 30 }],
      photos: [],
    },
    {
      providerId: pierre,
      categoryId: 'bricolage',
      title: 'Montage de meubles',
      description:
        'Montage de tous types de meubles (IKEA, But, Conforama…). Rapide et soigné.',
      priceType: 'fixed',
      price: 5000,
      published: true,
      serviceZones: [{ label: 'Orléans centre', lat: 47.9029, lng: 1.9090, radiusKm: 10 }],
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
      serviceArea: 'Paris',
    },
    {
      uid: ahmed,
      bio: 'Jardinier paysagiste avec 10 ans d\'expérience. Spécialisé dans l\'entretien et la création de jardins. Passionné par les plantes.',
      serviceArea: 'Évry / Orléans',
    },
    {
      uid: pierre,
      bio: 'Plombier certifié, 12 ans de métier. Interventions rapides et propres. Tous travaux sanitaires, chauffage, climatisation.',
      serviceArea: 'Étampes / Orléans',
    },
    {
      uid: fatou,
      bio: 'Aide à domicile polyvalente : ménage, repassage, peinture. Travail soigné, références vérifiables. Disponible en semaine et week-end.',
      serviceArea: 'Pithiviers',
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
  console.log(`  Marie Leclerc  → provider1@outalma.test  (Ménage+Garde, Paris)`);
  console.log(`  Ahmed Sow      → provider2@outalma.test  (Jardinage, Évry+Orléans)`);
  console.log(`  Pierre Dubois  → provider3@outalma.test  (Plomberie+Élec+Bricolage, Étampes+Orléans)`);
  console.log(`  Fatou Ndiaye   → provider4@outalma.test  (Ménage/Autre, Dakar)`);
  console.log('─'.repeat(60) + '\n');

  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Seed failed:', err);
  process.exit(1);
});
