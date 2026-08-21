/**
 * End-to-end integration check for the migration against the Firestore
 * emulator. Seeds config/pricing and a small fixture set, then drives migrate.js
 * (pass 1, classification, pass 2 simulation, pass 2 apply, pass 2 apply again)
 * as child processes and asserts the acceptance behaviour:
 *
 *  - SC-32: simulation writes nothing; its journal equals the apply journal
 *           except for the mode marker.
 *  - SC-33/34/36: seeded fixed 15000 -> daily 10000; app cents 250000 -> 2500;
 *           out-of-range clamped; non-launch category never clamped.
 *  - SC-38: a second apply migrates 0 documents (idempotent sentinel).
 *
 * Run (from functions/, which holds the emulator config):
 *   firebase emulators:exec --only firestore --project demo-outalma \
 *     --config firebase.emulator.json \
 *     "node ../scripts/pricing-migration/emulator-check.js"
 */

'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFileSync } = require('child_process');
const admin = require('../../functions/node_modules/firebase-admin');

const MIGRATE = path.join(__dirname, 'migrate.js');

const CONFIG = {
  version: 1,
  currency: 'XOF',
  boundedCategories: ['menage', 'cuisine', 'gardeEnfants', 'repassage'],
  maxExtraTasks: 3,
  modes: {
    hourly: { min: 1000, max: 3500, extraBonusPercent: 25 },
    daily: { min: 2000, max: 10000, extraBonusPercent: 25 },
    monthly: { min: 50000, max: 150000, extraBonusPercent: 0, isRange: true },
  },
};

const FIXTURES = {
  'fx-seed-py': { _seeded: true, providerId: 'p1', categoryId: 'menage', priceType: 'fixed', price: 15000 },
  'fx-app': { providerId: 'p1', categoryId: 'menage', priceType: 'hourly', price: 250000 },
  'fx-app-low': { providerId: 'p1', categoryId: 'menage', priceType: 'hourly', price: 50000 },
  'fx-plomberie': { providerId: 'p1', categoryId: 'plomberie', priceType: 'fixed', price: 4000000 },
};

const CLASSIFICATION = {
  'fx-seed-py': 'fcfa',
  'fx-app': 'cents',
  'fx-app-low': 'cents',
  'fx-plomberie': 'cents',
};

function assert(cond, msg) {
  if (!cond) {
    console.error(`FAIL: ${msg}`);
    process.exitCode = 1;
    throw new Error(msg);
  }
  console.log(`ok - ${msg}`);
}

function run(args) {
  execFileSync('node', [MIGRATE, ...args], { stdio: 'inherit', env: process.env });
}

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.error('FIRESTORE_EMULATOR_HOST not set; run via firebase emulators:exec.');
    process.exit(1);
  }
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-outalma' });
  const db = admin.firestore();

  await db.collection('config').doc('pricing').set(CONFIG);
  for (const [id, data] of Object.entries(FIXTURES)) {
    await db.collection('services').doc(id).set(data);
  }

  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'pricing-mig-'));
  fs.writeFileSync(path.join(out, 'classification.json'), JSON.stringify(CLASSIFICATION));

  // Pass 1 inventory.
  run(['--pass=1', `--out=${out}`]);
  assert(fs.existsSync(path.join(out, 'inventory.csv')), 'pass 1 wrote inventory.csv');

  // Pass 2 simulation: nothing changes in the database.
  run(['--pass=2', `--classification=${path.join(out, 'classification.json')}`, `--out=${out}`]);
  const afterSim = (await db.collection('services').doc('fx-seed-py').get()).data();
  assert(afterSim.price === 15000 && afterSim.pricingSchema === undefined, 'SC-32: simulation left fx-seed-py untouched');

  // Pass 2 apply.
  run(['--pass=2', `--classification=${path.join(out, 'classification.json')}`, `--out=${out}`, '--apply']);

  const seedPy = (await db.collection('services').doc('fx-seed-py').get()).data();
  assert(seedPy.priceType === 'daily' && seedPy.price === 10000, 'SC-33: fx-seed-py -> daily 10000 (clamped)');
  const app = (await db.collection('services').doc('fx-app').get()).data();
  assert(app.price === 2500, 'SC-34: fx-app cents 250000 -> 2500');
  const low = (await db.collection('services').doc('fx-app-low').get()).data();
  assert(low.price === 1000, 'SC-36: fx-app-low raised to floor 1000');
  const plomb = (await db.collection('services').doc('fx-plomberie').get()).data();
  assert(plomb.priceType === 'daily' && plomb.price === 40000, 'fx-plomberie -> daily 40000, no clamp (non-launch)');

  // Journals identical bar the mode marker (SC-32).
  const sim = JSON.parse(fs.readFileSync(path.join(out, 'journal.simulation.json'), 'utf8'));
  const app2 = JSON.parse(fs.readFileSync(path.join(out, 'journal.apply.json'), 'utf8'));
  assert(sim.mode === 'simulation' && app2.mode === 'apply', 'journals carry a mode marker');
  assert(JSON.stringify(sim.entries) === JSON.stringify(app2.entries), 'SC-32: simulation and apply journals have identical entries');

  // Second apply: idempotent, zero migrated.
  run(['--pass=2', `--classification=${path.join(out, 'classification.json')}`, `--out=${out}`, '--apply']);
  const journal2 = JSON.parse(fs.readFileSync(path.join(out, 'journal.apply.json'), 'utf8'));
  assert(journal2.migrated === 0 && journal2.skipped.length === Object.keys(FIXTURES).length, 'SC-38: second apply migrates 0 (all skipped)');

  await admin.app().delete();
  console.log('\nemulator-check: ALL PASS');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
