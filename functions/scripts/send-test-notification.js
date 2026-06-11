#!/usr/bin/env node
/**
 * Notification diagnostic — sends a REAL push to a user via the Admin SDK and
 * reports exactly what happens, so you can be sure delivery works end-to-end
 * (server side). Also lists who can/can't receive across the whole user base.
 *
 * What it proves:
 *   - whether the user has a pushToken registered (no token => device never got
 *     an APNs/FCM token; check the printed notifDebug for the failing step),
 *   - whether FCM ACCEPTS that token (a returned message id == valid token +
 *     accepted for delivery). Actual on-device display then depends only on the
 *     phone (OS notif settings / network), not on our backend.
 *
 * Credentials: uses Application Default Credentials against the prod project.
 * Run ONE of these first if it fails to init:
 *   gcloud auth application-default login
 *   # or: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *
 * Usage (from functions/):
 *   npm run notif:test -- --list                 # who has a token + last notifDebug
 *   npm run notif:test -- --uid <uid>            # send a test push to a uid
 *   npm run notif:test -- --email a@b.com        # resolve uid via Auth, then send
 *   npm run notif:test -- --uid <uid> --message "Coucou"
 */
const admin = require('firebase-admin');

const PROJECT_ID = 'outalmaservice-d1e59';

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--list') args.list = true;
    else if (a === '--uid') args.uid = argv[++i];
    else if (a === '--email') args.email = argv[++i];
    else if (a === '--message') args.message = argv[++i];
  }
  return args;
}

function init() {
  try {
    admin.initializeApp({ projectId: PROJECT_ID });
  } catch (e) {
    console.error('❌ Could not initialize the Admin SDK:', e.message);
    console.error(
      '   Run: gcloud auth application-default login   (or set GOOGLE_APPLICATION_CREDENTIALS)'
    );
    process.exit(1);
  }
}

const db = () => admin.firestore();

function fmtDebug(d) {
  if (!d) return '(no notifDebug — initialize() never ran/recorded on this account)';
  const ts = d.ts && d.ts.toDate ? d.ts.toDate().toISOString() : d.ts;
  return [
    `step=${d.step}`,
    `auth=${d.authStatus}`,
    `apnsPresent=${d.apnsPresent}`,
    `fcmTokenPresent=${d.fcmTokenPresent}`,
    d.fcmError ? `fcmError=${d.fcmError}` : null,
    `platform=${d.platform}`,
    `at=${ts}`,
  ]
    .filter(Boolean)
    .join('  ');
}

async function list() {
  const snap = await db().collection('users').get();
  const rows = [];
  snap.forEach((doc) => {
    const d = doc.data();
    rows.push({
      uid: doc.id,
      name: d.displayName || '(no name)',
      email: d.email || '',
      hasToken: typeof d.pushToken === 'string' && d.pushToken.length > 0,
      debug: d.notifDebug,
    });
  });
  rows.sort((a, b) => Number(b.hasToken) - Number(a.hasToken));
  const withToken = rows.filter((r) => r.hasToken).length;
  console.log(`\n${rows.length} users — ${withToken} have a pushToken:\n`);
  for (const r of rows) {
    console.log(
      `${r.hasToken ? '✅' : '❌'} ${r.name}  <${r.email}>  [${r.uid}]`
    );
    if (!r.hasToken) console.log(`     ↳ ${fmtDebug(r.debug)}`);
  }
  console.log('');
}

async function resolveUid(args) {
  if (args.uid) return args.uid;
  if (args.email) {
    try {
      const user = await admin.auth().getUserByEmail(args.email);
      return user.uid;
    } catch {
      // Fall back to a Firestore lookup by the `email` field (seeds can differ
      // between Auth and Firestore).
      const q = await db()
        .collection('users')
        .where('email', '==', args.email)
        .limit(1)
        .get();
      if (!q.empty) return q.docs[0].id;
      console.error(`❌ No user found for email ${args.email}`);
      process.exit(1);
    }
  }
  console.error('❌ Provide --uid <uid> or --email <email> (or --list).');
  process.exit(1);
}

async function sendTest(args) {
  const uid = await resolveUid(args);
  const userSnap = await db().collection('users').doc(uid).get();
  if (!userSnap.exists) {
    console.error(`❌ users/${uid} does not exist.`);
    process.exit(1);
  }
  const data = userSnap.data();
  console.log(`\n👤 ${data.displayName || '(no name)'}  <${data.email || ''}>  [${uid}]`);
  console.log(`   notifDebug: ${fmtDebug(data.notifDebug)}`);

  const token = data.pushToken;
  if (!token) {
    console.log(
      '\n❌ No pushToken on this account → the server has nowhere to deliver.'
    );
    console.log(
      '   The device never registered an APNs/FCM token. The notifDebug above'
    );
    console.log(
      '   shows where it stopped (typically apns-token-not-set). Have the user'
    );
    console.log(
      '   open the latest build with network, then re-run --list to confirm a'
    );
    console.log('   token appears.');
    process.exit(2);
  }

  console.log(`\n📤 Sending a test push to token …${token.slice(-12)}`);
  try {
    const id = await admin.messaging().send({
      token,
      notification: {
        title: 'Test Outalma',
        body: args.message || 'Si tu vois ceci, les notifications marchent ✅',
      },
      data: { type: 'test' },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    console.log(`\n✅ FCM ACCEPTED the message — id: ${id}`);
    console.log(
      '   The token is valid and the push is queued for delivery. If it does not'
    );
    console.log(
      '   appear on the phone, the cause is device-side (OS notification setting'
    );
    console.log('   off, or no network) — not the backend.');
  } catch (e) {
    console.log(`\n❌ FCM REJECTED the send: ${e.code || ''} ${e.message}`);
    if (
      e.code === 'messaging/registration-token-not-registered' ||
      e.code === 'messaging/invalid-registration-token' ||
      e.code === 'messaging/invalid-argument'
    ) {
      console.log(
        '   This token is dead (app reinstalled / token rotated). The next time'
      );
      console.log(
        '   the user opens the app a fresh token registers; sendPushToUsers also'
      );
      console.log('   purges dead tokens automatically.');
    }
    process.exit(3);
  }
}

async function main() {
  const args = parseArgs(process.argv);
  init();
  if (args.list) {
    await list();
  } else {
    await sendTest(args);
  }
  process.exit(0);
}

main().catch((e) => {
  const msg = String(e && e.message);
  if (msg.includes('default credentials') || msg.includes('Could not load')) {
    console.error(
      '\n❌ Not authenticated against the project. Run ONE of:\n' +
        '   gcloud auth application-default login\n' +
        '   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json\n' +
        '   (the service account needs Firestore read + Cloud Messaging send)\n'
    );
    process.exit(1);
  }
  console.error('Unexpected error:', e);
  process.exit(1);
});
