/**
 * End-to-end smoke run of the OTP rate limit, against the REAL callables and
 * the REAL emulators. Not a unit test: it drives the whole guard once, in
 * order, and prints what it observes at each step.
 *
 * Run it through:
 *   firebase emulators:exec --only firestore,auth,storage --project demo-outalma \
 *     --config smoke.emulator.json "node scripts/smoke-otp.js"
 *
 * It exercises the compiled output in lib/, so it also proves the BUILD is the
 * thing that works, not only the TypeScript sources.
 *
 * What it is really watching is not the error codes, it is the Twilio double's
 * call count: every accepted request bills a message, so the only thing that
 * protects the money is that the double is NOT called past a refusal.
 *
 * No call is made from the simulator: `callable_function_client.dart` hard-codes
 * the production URL and `lib/` carries no `useFunctionsEmulator`, so driving
 * this from the app would send a real, billed SMS. The mobile half of the flow
 * (the resend countdown and its wording) is covered by widget tests instead.
 */
const admin = require('firebase-admin');
const functionsTest = require('firebase-functions-test');

const tf = functionsTest({
  projectId: 'demo-outalma',
  storageBucket: 'demo-outalma.appspot.com',
});

// Read by SecretParam.value() at call time. The guard refuses to serve without
// it, deliberately, so it has to exist before the module is required.
process.env.OTP_HASH_KEY = 'smoke-hmac-key';

const fns = require('../lib/index');
const { setTwilioClient } = require('../lib/auth_phone');
const {
  DEFAULT_LIMITS,
  OTP_ERROR,
  OTP_STATES,
  OTP_COUNTERS,
  OTP_CONFIG,
  OTP_CONFIG_DOC,
  dayKey,
  phoneHash,
} = require('../lib/otp_rate_limit');

const SN = '+221771234567';
const FR_TRUNK = '+330612345678';
const FR_CLEAN = '+33612345678';
const IT_FIXED = '+390612345678';
const OFF_LIST = '+79123456789';
const KEY = 'smoke-hmac-key';

const db = () => admin.firestore();

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

/** Records every call instead of reaching verify.twilio.com. */
const twilio = { sent: [], checked: [] };
setTwilioClient({
  async startVerification(phone, channel) {
    twilio.sent.push({ phone, channel });
  },
  async checkVerification(phone, code) {
    twilio.checked.push({ phone, code });
  },
});

const request = (data) => tf.wrap(fns.requestPhoneOtp)({ data });

/** A remaining delay is the step minus the real time already elapsed. */
const near = (value, step) => value > step - 5000 && value <= step;

/** Refuses, and says how. Throws if the call was ACCEPTED. */
async function refusal(data) {
  try {
    await request(data);
  } catch (e) {
    return { code: e.code, details: e.details ?? {} };
  }
  throw new Error(`expected a refusal for ${JSON.stringify(data)}`);
}

/** The emulator has no clock to move, so the credits are aged in place. */
async function ageCredits(phone, byMs) {
  const ref = db().collection(OTP_STATES).doc(phoneHash(phone, KEY));
  const snap = await ref.get();
  const ts = (snap.data() || {}).creditTimestampsMs || [];
  await ref.set({
    creditTimestampsMs: ts.map((t) => t - byMs),
    updatedAtMs: Date.now() - byMs,
  });
}

async function setGlobalCount(count) {
  await db()
    .collection(OTP_COUNTERS)
    .doc(dayKey(Date.now()))
    .set({ count, updatedAtMs: Date.now() }, { merge: true });
}

async function clearAll() {
  for (const name of [OTP_STATES, OTP_COUNTERS, OTP_CONFIG, 'security_alerts']) {
    const docs = await db().collection(name).get();
    await Promise.all(docs.docs.map((d) => d.ref.delete()));
  }
  twilio.sent.length = 0;
  twilio.checked.length = 0;
}

async function main() {
  console.log('\n=== SMOKE otp-rate-limit (real callables, real emulators) ===\n');
  await clearAll();

  // --- 1. A fresh number goes through ------------------------------------
  console.log('1. First request on a fresh +221');
  const first = await request({ phone: SN });
  must(twilio.sent.length === 1, 'Twilio called exactly once');
  must(first.channel === 'sms', 'the answer names the SMS channel');
  must(
    first.retryAfterMs === DEFAULT_LIMITS.backoffMs[0],
    `the answer carries the resend delay (${first.retryAfterMs} ms)`
  );

  // --- 2. The immediate retry is refused, and costs nothing ---------------
  console.log('\n2. Immediate second request');
  const backoff = await refusal({ phone: SN });
  must(backoff.code === 'resource-exhausted', 'refused with resource-exhausted');
  must(backoff.details.code === OTP_ERROR.backoff, 'stable code otp/backoff');
  // Slightly under the step: the delay is what REMAINS, and a few milliseconds
  // of real time have passed between the two calls.
  must(near(backoff.details.retryAfterMs, 60000), 'retryAfterMs is the 60 s step');
  must(twilio.sent.length === 1, 'Twilio NOT called: no message billed');

  // --- 3. The backoff climbs -----------------------------------------------
  console.log('\n3. The backoff climbs with the rank');
  await ageCredits(SN, 60_000);
  await request({ phone: SN });
  must(twilio.sent.length === 2, 'accepted once the first step has elapsed');
  const second = await refusal({ phone: SN });
  must(near(second.details.retryAfterMs, 120000), 'second step is the 120 s one');
  await ageCredits(SN, 120_000);
  await request({ phone: SN });
  const third = await refusal({ phone: SN });
  must(near(third.details.retryAfterMs, 300000), 'third step is the 300 s one');
  must(twilio.sent.length === 3, 'still three messages, not one more');

  // --- 4. The hourly ceiling ----------------------------------------------
  console.log('\n4. The seventh send of the hour');
  await clearAll();
  for (let i = 0; i < DEFAULT_LIMITS.maxPerWindow; i++) {
    await request({ phone: SN });
    await ageCredits(SN, 6 * 60 * 1000);
  }
  must(twilio.sent.length === 6, 'six messages went out');
  const hourly = await refusal({ phone: SN });
  must(hourly.details.code === OTP_ERROR.windowCap, 'refused on the hourly cap');
  must(
    hourly.details.retryAfterMs > DEFAULT_LIMITS.backoffMs[2],
    'and announces the window wait, not a backoff step'
  );
  must(twilio.sent.length === 6, 'Twilio NOT called: the 7th costs nothing');

  // --- 5. A country the product does not serve -----------------------------
  console.log('\n5. A dial code outside the allowlist');
  await clearAll();
  const prefix = await refusal({ phone: OFF_LIST });
  must(
    prefix.details.code === OTP_ERROR.prefixNotAllowed,
    'refused on the allowlist'
  );
  must(twilio.sent.length === 0, 'Twilio NOT called, and no state written');
  const states = await db().collection(OTP_STATES).get();
  must(states.empty, 'a refusal writes no guard document at all');

  // --- 6. The voice channel ------------------------------------------------
  console.log('\n6. The caller asks for the voice channel');
  const channel = await refusal({ phone: SN, channel: 'call' });
  must(channel.code === 'invalid-argument', 'refused with invalid-argument');
  must(twilio.sent.length === 0, 'Twilio NOT called on the dearer channel');

  // --- 7. One subscriber, one quota; and the raw string reaches Twilio -----
  console.log('\n7. Two spellings of one French number');
  await clearAll();
  await request({ phone: FR_TRUNK });
  const sameQuota = await refusal({ phone: FR_CLEAN });
  must(
    sameQuota.details.code === OTP_ERROR.backoff,
    'the trunk-zero spelling shares the quota of the clean one'
  );
  must(twilio.sent.length === 1, 'so the second spelling bills nothing');
  must(
    twilio.sent[0].phone === FR_TRUNK,
    'Twilio received the RAW string, not the normalised one'
  );
  await tf.wrap(fns.verifyPhoneOtpAndSignIn)({
    data: { phone: FR_TRUNK, code: '123456' },
  });
  must(
    twilio.checked[0].phone === twilio.sent[0].phone,
    'Start and Check received exactly the same string'
  );
  await clearAll();
  await request({ phone: IT_FIXED });
  const italy = await db().collection(OTP_STATES).get();
  must(
    italy.docs[0].id === phoneHash(IT_FIXED, KEY),
    'an Italian number keeps its zero: the quota key is not shared'
  );

  // --- 8. The global alert, then the global stop ---------------------------
  console.log('\n8. The service-wide alert and stop');
  await clearAll();
  await setGlobalCount(DEFAULT_LIMITS.alertAt - 1);
  await request({ phone: SN });
  let alerts = await db().collection('security_alerts').get();
  must(alerts.size === 1, 'crossing the alert threshold raises ONE alert');
  must(alerts.docs[0].data().type === 'otp_global_cap', 'typed for the dashboard');
  const alertId = alerts.docs[0].id;
  await db().collection('security_alerts').doc(alertId).update({ status: 'resolved' });
  await request({ phone: '+221770000002' });
  alerts = await db().collection('security_alerts').get();
  must(alerts.size === 1, 'a second crossing raises no duplicate');
  must(
    alerts.docs[0].data().status === 'resolved',
    'and does not reopen the one an admin just resolved'
  );

  await setGlobalCount(DEFAULT_LIMITS.stopAt);
  const sentBefore = twilio.sent.length;
  const stop = await refusal({ phone: '+221770000003' });
  must(stop.details.code === OTP_ERROR.globalCap, 'the global stop refuses');
  must(twilio.sent.length === sentBefore, 'Twilio NOT called past the stop');

  // The ceiling is tunable without a deploy, which is the point of otp_config.
  await db().collection(OTP_CONFIG).doc(OTP_CONFIG_DOC).set({ stopAt: 1e9 });
  const stillStopped = await refusal({ phone: '+221770000004' });
  must(
    stillStopped.details.code === OTP_ERROR.globalCap,
    'an absurd override is ignored rather than switching the guard off'
  );

  // --- 9. No phone number anywhere -----------------------------------------
  console.log('\n9. What the guard documents actually hold');
  await clearAll();
  await request({ phone: SN });
  const guards = await db().collection(OTP_STATES).get();
  const only = guards.docs[0];
  must(!only.id.includes('771234567'), 'no phone number in the document id');
  must(
    !JSON.stringify(only.data()).includes('771234567'),
    'no phone number in the document fields either'
  );
  must(/^[0-9a-f]{64}$/.test(only.id), 'the id is an HMAC digest and nothing else');

  // --- 10. The purge drains -------------------------------------------------
  console.log('\n10. Retention');
  const stale = Date.now() - 49 * 60 * 60 * 1000;
  await db()
    .collection(OTP_STATES)
    .doc('stale-guard')
    .set({ creditTimestampsMs: [stale], updatedAtMs: stale });
  await db()
    .collection(OTP_COUNTERS)
    .doc('2020-01-01')
    .set({ count: 1, updatedAtMs: stale });
  await tf.wrap(fns.purgeExpiredOtpStates)({});
  const afterPurge = await db().collection(OTP_STATES).get();
  must(
    afterPurge.docs.every((d) => d.id !== 'stale-guard'),
    'the expired guard document is gone'
  );
  must(
    (await db().collection(OTP_COUNTERS).doc('2020-01-01').get()).exists === false,
    'and so is the expired daily counter'
  );
  must(afterPurge.size === 1, 'while the fresh one is untouched');

  console.log(`\n=== SMOKE OK, ${step} checks ===\n`);
}

main()
  .then(() => process.exit(process.exitCode ?? 0))
  .catch((e) => {
    console.error('\n=== SMOKE FAILED ===\n', e.message);
    process.exit(1);
  });
