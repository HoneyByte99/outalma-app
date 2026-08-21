/**
 * Outalma - one-shot encadre-pricing migration (archi section 6).
 *
 * Two passes with a human checkpoint between them, because the cents and
 * whole-FCFA populations overlap and NO automatic classification is safe
 * (archi section 6.1).
 *
 *   Pass 1 (inventory, never writes):
 *     node scripts/pricing-migration/migrate.js --pass=1 --out=./out
 *   -> writes out/inventory.csv and out/summary.json. Amath reviews the CSV
 *      and produces a classification file: { "<docId>": "fcfa" | "cents", ... }.
 *
 *   Pass 2 (apply), simulation by default (writes nothing):
 *     node scripts/pricing-migration/migrate.js --pass=2 \
 *        --classification=./out/classification.json --out=./out
 *   -> writes out/journal.simulation.json, mutates nothing.
 *
 *   Pass 2 for real (explicit flag required):
 *     node scripts/pricing-migration/migrate.js --pass=2 \
 *        --classification=./out/classification.json --out=./out --apply
 *   -> writes out/journal.apply.json AND updates Firestore.
 *
 * Idempotent: a document already at pricingSchema 2 is left untouched and
 * journalled as such, so an interrupted run is safe to relaunch (SC-38/40).
 *
 * Credentials: GOOGLE_APPLICATION_CREDENTIALS, or scripts/service-account.json.
 * Against the emulator: set FIRESTORE_EMULATOR_HOST (used by the SCRIPT
 * acceptance scenarios SC-32..SC-40).
 */

'use strict';

const path = require('path');
const fs = require('fs');
const admin = require('../../functions/node_modules/firebase-admin');
const { proposeConvention, planDocument } = require('./core');

function parseArgs(argv) {
  const args = { pass: null, apply: false, classification: null, out: './out' };
  for (const a of argv.slice(2)) {
    if (a === '--apply') args.apply = true;
    else if (a.startsWith('--pass=')) args.pass = a.slice(7);
    else if (a.startsWith('--classification=')) args.classification = a.slice(17);
    else if (a.startsWith('--out=')) args.out = a.slice(6);
  }
  return args;
}

function resolveCredential() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return admin.credential.applicationDefault();
  }
  const localKey = path.join(__dirname, '..', 'service-account.json');
  if (fs.existsSync(localKey)) return admin.credential.cert(localKey);
  return null;
}

function initAdmin() {
  // On the emulator no real credentials are needed.
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-outalma' });
    return;
  }
  const credential = resolveCredential();
  if (!credential) {
    console.error('No credentials. Set GOOGLE_APPLICATION_CREDENTIALS or add scripts/service-account.json.');
    process.exit(1);
  }
  admin.initializeApp({ credential });
}

async function readConfig(db) {
  const snap = await db.collection('config').doc('pricing').get();
  if (!snap.exists) {
    throw new Error('config/pricing is missing: create it before migrating (archi section 7).');
  }
  return snap.data();
}

async function* iterateServices(db, pageSize = 200) {
  // Bounded, paged scan of the whole collection, off the user path (D1).
  let last = null;
  for (;;) {
    let q = db.collection('services').orderBy('__name__').limit(pageSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) return;
    for (const d of snap.docs) yield d;
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) return;
  }
}

function ensureOutDir(out) {
  fs.mkdirSync(out, { recursive: true });
}

async function pass1(db, args) {
  const config = await readConfig(db);
  ensureOutDir(args.out);
  const rows = [['id', 'providerId', 'categoryId', 'priceType', 'price', 'seeded', 'proposedConvention', 'reason', 'proposedPrice', 'outOfRange']];
  const summary = { total: 0, byConvention: {}, byReason: {} };

  for await (const doc of iterateServices(db)) {
    const data = { id: doc.id, ...doc.data() };
    const proposal = proposeConvention(data);
    // Preview using the proposed convention (pass 2 uses the human decision).
    const preview = planDocument(data, proposal.convention === 'ambiguous' ? 'fcfa' : proposal.convention, config);
    const proposedPrice = preview.changes.price ?? data.price;
    const bounded = (config.boundedCategories || []).includes(data.categoryId);
    const b = config.modes[preview.changes.priceType || data.priceType];
    const outOfRange = bounded && b
      ? proposedPrice < b.min || proposedPrice > b.max
      : false;

    rows.push([
      doc.id, data.providerId ?? '', data.categoryId ?? '', data.priceType ?? '',
      data.price ?? '', data._seeded === true ? 'yes' : 'no',
      proposal.convention, proposal.reason, proposedPrice, outOfRange ? 'yes' : 'no',
    ]);
    summary.total += 1;
    summary.byConvention[proposal.convention] = (summary.byConvention[proposal.convention] || 0) + 1;
    summary.byReason[proposal.reason] = (summary.byReason[proposal.reason] || 0) + 1;
  }

  const csv = rows.map((r) => r.map((c) => `${c}`.replace(/,/g, ' ')).join(',')).join('\n');
  fs.writeFileSync(path.join(args.out, 'inventory.csv'), csv);
  fs.writeFileSync(path.join(args.out, 'summary.json'), JSON.stringify(summary, null, 2));
  console.log(`Pass 1 inventory: ${summary.total} documents -> ${args.out}/inventory.csv`);
  console.log(JSON.stringify(summary, null, 2));
}

async function pass2(db, args) {
  if (!args.classification) {
    console.error('Pass 2 needs --classification=<file> (the human-reviewed id -> convention map).');
    process.exit(1);
  }
  const config = await readConfig(db);
  const classification = JSON.parse(fs.readFileSync(args.classification, 'utf8'));
  ensureOutDir(args.out);

  const mode = args.apply ? 'apply' : 'simulation';
  const journal = { mode, entries: [], skipped: [], unclassified: [], migrated: 0 };

  for await (const doc of iterateServices(db)) {
    const data = { id: doc.id, ...doc.data() };
    // A document already migrated is safe to re-see (idempotence).
    if (data.pricingSchema === 2) {
      journal.skipped.push({ id: doc.id, reason: 'already_migrated' });
      continue;
    }
    const convention = classification[doc.id];
    if (convention !== 'fcfa' && convention !== 'cents') {
      // Never guess: a document absent from the classification is reported and
      // left untouched (archi section 6.2).
      journal.unclassified.push(doc.id);
      continue;
    }
    const plan = planDocument(data, convention, config);
    if (plan.skipped) {
      journal.skipped.push({ id: doc.id, reason: 'already_migrated' });
      continue;
    }
    journal.entries.push(...plan.journal);
    journal.migrated += 1;
    if (args.apply) {
      await doc.ref.set(plan.changes, { merge: true });
    }
  }

  const file = path.join(args.out, `journal.${mode}.json`);
  fs.writeFileSync(file, JSON.stringify(journal, null, 2));
  console.log(`Pass 2 (${mode}): ${journal.migrated} migrated, ${journal.skipped.length} skipped, ${journal.unclassified.length} unclassified -> ${file}`);
  if (journal.unclassified.length > 0) {
    console.warn(`WARNING: ${journal.unclassified.length} documents were not in the classification file and were left untouched.`);
  }
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.pass !== '1' && args.pass !== '2') {
    console.error('Usage: --pass=1 | --pass=2 [--apply] [--classification=<file>] [--out=<dir>]');
    process.exit(1);
  }
  initAdmin();
  const db = admin.firestore();
  if (args.pass === '1') await pass1(db, args);
  else await pass2(db, args);
  await admin.app().delete();
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

module.exports = { parseArgs };
