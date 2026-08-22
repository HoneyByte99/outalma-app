/**
 * End-to-end smoke run of the identity-verification flow, against the REAL
 * Cloud Functions and the REAL emulators. Not a unit test: it drives the whole
 * journey once, in order, and prints what it observes at each step.
 *
 * Run it through:
 *   firebase emulators:exec --only firestore,auth,storage --project demo-outalma \
 *     --config smoke.emulator.json "node scripts/smoke-identity.js"
 *
 * It exercises the compiled output in lib/, so it also proves the build is the
 * thing that works, not only the TypeScript sources.
 */
const admin = require('firebase-admin');
const functionsTest = require('firebase-functions-test');

const tf = functionsTest({
  projectId: 'demo-outalma',
  storageBucket: 'demo-outalma.appspot.com',
});

const fns = require('../lib/index');
const {
  verificationDocId,
  setTextExtractor,
} = require('../lib/identity_verification');

const PROVIDER = 'smoke-provider';
const ADMIN = { uid: 'smoke-admin', token: { admin: true } };
const BATCH = 'smokebatch01';

// Valid TD1, checksums verified, 17-digit number across both optional blocks.
const MRZ = [
  'I<UTOD231458907123456789012345',
  '7408122F1204159UTO67<<<<<<<<<9',
  'NDIAYE<<FATOU<<<<<<<<<<<<<<<<<',
];

const db = () => admin.firestore();
const bucket = () => admin.storage().bucket();

let step = 0;
const ok = (msg) => console.log(`  [${++step}] OK   ${msg}`);
function must(condition, msg) {
  if (!condition) {
    console.error(`  [${++step}] FAIL ${msg}`);
    process.exitCode = 1;
    throw new Error(msg);
  }
  ok(msg);
}

async function main() {
  console.log('\n=== SMOKE identity-verification (real callables, real emulators) ===\n');

  setTextExtractor({ async detect() { return MRZ; } });

  // --- 1. The provider uploads three pieces -------------------------------
  console.log('1. Provider uploads the three pieces');
  for (const name of ['recto.jpg', 'verso.jpg', 'selfie.jpg']) {
    await bucket()
      .file(`private/identity/${PROVIDER}/${BATCH}/${name}`)
      .save(Buffer.from(`smoke-${name}`), { contentType: 'image/jpeg' });
  }
  await db().collection('users').doc(PROVIDER).set({ displayName: 'Smoke' });
  // A real account exists in Auth too: deleteMyAccount ends by removing it, and
  // a Firestore document alone would make the last step fail for a reason that
  // has nothing to do with the flow under test.
  await admin.auth().createUser({ uid: PROVIDER });
  const [uploaded] = await bucket().getFiles({
    prefix: `private/identity/${PROVIDER}/`,
  });
  must(uploaded.length === 3, `three objects on disk (${uploaded.length})`);

  // --- 2. Submission -------------------------------------------------------
  console.log('\n2. submitIdentityVerification');
  const res = await tf.wrap(fns.submitIdentityVerification)({
    data: { batchId: BATCH, cniNumber: 'FORGED-BY-CLIENT' },
    auth: { uid: PROVIDER },
  });
  const id = verificationDocId(PROVIDER, BATCH);
  must(res.verificationId === id, `file id is derived from the uid (${id.slice(0, 12)}...)`);

  const file = (await db().collection('identity_verifications').doc(id).get()).data();
  must(file.status === 'pending', `status is pending`);
  must(file.cniNumber === '12345678901234567', `card number read by the SERVER (${file.cniNumber})`);
  must(file.cniNumber !== 'FORGED-BY-CLIENT', 'value sent by the client ignored');
  must(file.cniNom === 'NDIAYE', `name extracted (${file.cniNom})`);
  must(file.mrzValid === true, 'MRZ checksums verified');

  const internal = (
    await db().collection('identity_verifications').doc(id)
      .collection('identity_internal').doc('review').get()
  ).data();
  must(!JSON.stringify(internal).includes('https://'), 'no bearer download URL stored, paths only');
  must(!!internal.rectoMd5 && !!internal.rectoGeneration, 'fingerprints frozen at submission');

  // --- 3. Replay is idempotent --------------------------------------------
  console.log('\n3. Replay of the same submission');
  const replay = await tf.wrap(fns.submitIdentityVerification)({
    data: { batchId: BATCH },
    auth: { uid: PROVIDER },
  });
  must(replay.alreadySubmitted === true, 'replay reports alreadySubmitted');
  const count = (await db().collection('identity_verifications').get()).size;
  must(count === 1, `still a single file (${count})`);

  // --- 4. An altered piece blocks the decision -----------------------------
  console.log('\n4. A piece swapped after submission');
  await bucket()
    .file(`private/identity/${PROVIDER}/${BATCH}/recto.jpg`)
    .save(Buffer.from('SWAPPED'), { contentType: 'image/jpeg' });
  let refused = false;
  try {
    await tf.wrap(fns.approveIdentityVerification)({
      data: { verificationId: id }, auth: ADMIN,
    });
  } catch (e) {
    refused = e.code === 'failed-precondition';
  }
  must(refused, 'approval refused failed-precondition on a swapped piece');

  // Put the original bytes back so the journey can continue.
  await bucket()
    .file(`private/identity/${PROVIDER}/${BATCH}/recto.jpg`)
    .save(Buffer.from('smoke-recto.jpg'), { contentType: 'image/jpeg' });
  const [meta] = await bucket()
    .file(`private/identity/${PROVIDER}/${BATCH}/recto.jpg`).getMetadata();
  await db().collection('identity_verifications').doc(id)
    .collection('identity_internal').doc('review')
    .update({ rectoGeneration: String(meta.generation), rectoMd5: String(meta.md5Hash) });

  // --- 5. Support is refused, admin decides --------------------------------
  console.log('\n5. Who may decide');
  let denied = false;
  try {
    await tf.wrap(fns.approveIdentityVerification)({
      data: { verificationId: id },
      auth: { uid: 'smoke-support', token: { support: true } },
    });
  } catch (e) {
    denied = e.code === 'permission-denied';
  }
  must(denied, 'support refused permission-denied');

  const decision = await tf.wrap(fns.approveIdentityVerification)({
    data: { verificationId: id }, auth: ADMIN,
  });
  must(decision.status === 'approved', 'admin approves');

  const state = (
    await db().collection('identity_verification_states').doc(PROVIDER).get()
  ).data();
  must(state.verified === true && state.approvedId === id, 'guard records the verification');

  const logs = await db().collection('admin_logs').get();
  const log = logs.docs[0].data();
  must(log.action === 'approve_identity_verification', 'staff action traced');
  must(!JSON.stringify(log).includes('12345678901234567'), 'no card number in the audit trail');

  const notifs = await db().collection('notifications').doc(PROVIDER)
    .collection('items').get();
  must(notifs.size === 1, 'provider notified');

  // --- 6. Export -----------------------------------------------------------
  console.log('\n6. exportMyData');
  const exported = await tf.wrap(fns.exportMyData)({ data: {}, auth: { uid: PROVIDER } });
  must(exported.identityVerifications.length === 1, 'file present in the personal export');
  must(!JSON.stringify(exported).includes('private/identity/'), 'no storage path in the export');
  must(!JSON.stringify(exported).includes('doublonReferenceId'), 'no review aid in the export');

  // --- 7. Account deletion purges everything -------------------------------
  console.log('\n7. deleteMyAccount');
  await tf.wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: PROVIDER } });

  const gone = await db().collection('identity_verifications').doc(id).get();
  must(!gone.exists, 'file deleted');
  const goneInternal = await db().collection('identity_verifications').doc(id)
    .collection('identity_internal').doc('review').get();
  must(!goneInternal.exists, 'internal document deleted (subcollections do not cascade)');
  const goneState = await db().collection('identity_verification_states').doc(PROVIDER).get();
  must(!goneState.exists, 'guard document deleted');
  const [left] = await bucket().getFiles({ prefix: `private/identity/${PROVIDER}/` });
  must(left.length === 0, `no identity image left in the bucket (${left.length})`);

  // --- 8. A submission cannot outrun the deletion --------------------------
  console.log('\n8. Submission after the account is gone');
  for (const name of ['recto.jpg', 'verso.jpg', 'selfie.jpg']) {
    await bucket()
      .file(`private/identity/${PROVIDER}/latebatch01/${name}`)
      .save(Buffer.from('late'), { contentType: 'image/jpeg' });
  }
  let blocked = false;
  try {
    await tf.wrap(fns.submitIdentityVerification)({
      data: { batchId: 'latebatch01' }, auth: { uid: PROVIDER },
    });
  } catch (e) {
    blocked = e.code === 'failed-precondition';
  }
  must(blocked, 'submission refused once the account no longer exists');

  console.log(`\n=== SMOKE OK, ${step} checks ===\n`);
}

main()
  .then(() => process.exit(process.exitCode ?? 0))
  .catch((e) => {
    console.error('\n=== SMOKE FAILED ===\n', e.message);
    process.exit(1);
  });
