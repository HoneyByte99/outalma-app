// `requestPhoneOtp` with the rate limit wired in. Admin SDK path, so the
// security rules are bypassed here by design; the rules themselves are covered
// by otp_rules.test.ts.
//
// The assertion that matters in this file is not the error code, it is
// `twilio.sent.length`: what protects the money is that Twilio is NOT called
// once the cap is reached.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({
  projectId: 'demo-outalma',
  storageBucket: 'demo-outalma.appspot.com',
});

// Read by SecretParam.value() at call time.
process.env.OTP_HASH_KEY = 'test-hmac-key';

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  setTwilioClient,
  resetTwilioClient,
  TwilioClient,
} from '../src/auth_phone';
import {
  DEFAULT_LIMITS,
  OTP_ERROR,
  OTP_COUNTERS,
  OTP_STATES,
  OTP_CONFIG,
  OTP_CONFIG_DOC,
  dayKey,
  phoneHash,
} from '../src/otp_rate_limit';
import { clearFirestore } from './helpers';

const db = () => admin.firestore();
const wrap = (fn: unknown) => tf.wrap(fn as never);

const SN = '+221771234567';
const FR_TRUNK = '+330612345678';
const FR_CLEAN = '+33612345678';

/** Records every call instead of reaching verify.twilio.com. */
function recordingTwilio() {
  const sent: Array<{ phone: string; channel: string }> = [];
  const checked: Array<{ phone: string; code: string }> = [];
  const client: TwilioClient = {
    async startVerification(phone, channel) {
      sent.push({ phone, channel });
    },
    async checkVerification(phone, code) {
      checked.push({ phone, code });
    },
  };
  return { sent, checked, client };
}

let twilio = recordingTwilio();

const request = (data: Record<string, unknown>) =>
  wrap(fns.requestPhoneOtp)({ data } as never);

/** Rewrites the guard document's timestamps: the emulator has no clock to move. */
async function ageCredits(phone: string, byMs: number): Promise<void> {
  const ref = db().collection(OTP_STATES).doc(phoneHash(phone, 'test-hmac-key'));
  const snap = await ref.get();
  const ts = (snap.data()?.creditTimestampsMs ?? []) as number[];
  await ref.set({
    creditTimestampsMs: ts.map((t) => t - byMs),
    updatedAtMs: Date.now() - byMs,
  });
}

async function setGlobalCount(count: number, alerted = false): Promise<void> {
  await db()
    .collection(OTP_COUNTERS)
    .doc(dayKey(Date.now()))
    .set({ count, alerted, updatedAtMs: Date.now() });
}

beforeEach(async () => {
  await clearFirestore();
  twilio = recordingTwilio();
  setTwilioClient(twilio.client);
});

afterAll(() => {
  resetTwilioClient();
  tf.cleanup();
});

describe('requestPhoneOtp, happy path', () => {
  it('sends once on a fresh number', async () => {
    const res = await request({ phone: SN });
    expect(res).toMatchObject({ channel: 'sms' });
    expect(twilio.sent).toEqual([{ phone: SN, channel: 'sms' }]);
  });

  it('sends the RAW string to Twilio, never the normalised one', async () => {
    await request({ phone: FR_TRUNK });
    expect(twilio.sent[0]?.phone).toBe(FR_TRUNK);
  });

  it('stores no phone number, in the document id nor in its fields', async () => {
    await request({ phone: SN });
    const docs = await db().collection(OTP_STATES).get();
    expect(docs.size).toBe(1);
    const only = docs.docs[0]!;
    expect(only.id).not.toContain('771234567');
    expect(JSON.stringify(only.data())).not.toContain('771234567');
  });
});

describe('requestPhoneOtp refusals do NOT call Twilio', () => {
  it('refuses a second send inside the backoff', async () => {
    await request({ phone: SN });
    await expect(request({ phone: SN })).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: { code: OTP_ERROR.backoff },
    });
    expect(twilio.sent).toHaveLength(1);
  });

  it('refuses a dial code outside the allowlist', async () => {
    await expect(request({ phone: '+79123456789' })).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: { code: OTP_ERROR.prefixNotAllowed },
    });
    expect(twilio.sent).toHaveLength(0);
  });

  it('refuses the voice channel outright', async () => {
    await expect(request({ phone: SN, channel: 'call' })).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    expect(twilio.sent).toHaveLength(0);
  });

  it('refuses once the global stop is reached', async () => {
    await setGlobalCount(DEFAULT_LIMITS.stopAt);
    await expect(request({ phone: SN })).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: { code: OTP_ERROR.globalCap },
    });
    expect(twilio.sent).toHaveLength(0);
  });

  it('refuses the 7th send inside the hour', async () => {
    for (let i = 0; i < DEFAULT_LIMITS.maxPerWindow; i++) {
      await request({ phone: SN });
      await ageCredits(SN, 6 * 60 * 1000);
    }
    await expect(request({ phone: SN })).rejects.toMatchObject({
      details: { code: OTP_ERROR.windowCap },
    });
    expect(twilio.sent).toHaveLength(DEFAULT_LIMITS.maxPerWindow);
  });

  it('carries retryAfterMs so the client can show a countdown', async () => {
    await request({ phone: SN });
    await expect(request({ phone: SN })).rejects.toMatchObject({
      details: { retryAfterMs: expect.any(Number) },
    });
  });
});

describe('quota key', () => {
  it('gives the two spellings of one French number a SINGLE quota', async () => {
    await request({ phone: FR_TRUNK });
    // Different string, same subscriber: must hit the backoff, not a fresh slot.
    await expect(request({ phone: FR_CLEAN })).rejects.toMatchObject({
      details: { code: OTP_ERROR.backoff },
    });
    expect(twilio.sent).toHaveLength(1);
  });
});

describe('concurrency', () => {
  it('lets exactly ONE of two simultaneous requests through', async () => {
    const results = await Promise.allSettled([
      request({ phone: SN }),
      request({ phone: SN }),
    ]);
    const ok = results.filter((r) => r.status === 'fulfilled');
    expect(ok).toHaveLength(1);
    expect(twilio.sent).toHaveLength(1);
  });
});

describe('global alert', () => {
  const alerts = () => db().collection('security_alerts').get();

  it('raises exactly one alert for the day, however many requests follow', async () => {
    await setGlobalCount(DEFAULT_LIMITS.alertAt - 1);
    await request({ phone: SN });
    expect((await alerts()).size).toBe(1);

    // A second crossing request must NOT write another alert, and must not
    // reopen the one an admin may have just resolved.
    const alertId = (await alerts()).docs[0]!.id;
    await db().collection('security_alerts').doc(alertId).update({ status: 'resolved' });
    await request({ phone: '+221770000001' });
    const after = await alerts();
    expect(after.size).toBe(1);
    expect(after.docs[0]!.data().status).toBe('resolved');
  });

  it('writes the same field set the admin dashboard already parses', async () => {
    await setGlobalCount(DEFAULT_LIMITS.alertAt - 1);
    await request({ phone: SN });
    const doc = (await alerts()).docs[0]!.data();
    expect(doc).toMatchObject({
      type: 'otp_global_cap',
      severity: 'high',
      status: 'open',
      resolvedAt: null,
      resolvedBy: null,
    });
    expect(doc.createdAt).toBeTruthy();
    expect(typeof doc.description).toBe('string');
  });

  it('stays silent below the alert threshold', async () => {
    await setGlobalCount(DEFAULT_LIMITS.alertAt - 5);
    await request({ phone: SN });
    expect((await alerts()).size).toBe(0);
  });
});

describe('live thresholds', () => {
  it('honours a sane override from otp_config', async () => {
    await db().collection(OTP_CONFIG).doc(OTP_CONFIG_DOC).set({ stopAt: 5, alertAt: 2 });
    await setGlobalCount(5);
    await expect(request({ phone: SN })).rejects.toMatchObject({
      details: { code: OTP_ERROR.globalCap },
    });
  });

  it('ignores an aberrant override rather than switching the guard off', async () => {
    await db().collection(OTP_CONFIG).doc(OTP_CONFIG_DOC).set({ stopAt: 1e9 });
    await setGlobalCount(DEFAULT_LIMITS.stopAt);
    await expect(request({ phone: SN })).rejects.toMatchObject({
      details: { code: OTP_ERROR.globalCap },
    });
    expect(twilio.sent).toHaveLength(0);
  });
});

describe('missing hash key', () => {
  it('refuses to serve rather than degrading to an unkeyed digest', async () => {
    const saved = process.env.OTP_HASH_KEY;
    process.env.OTP_HASH_KEY = '';
    try {
      await expect(request({ phone: SN })).rejects.toThrow();
      expect(twilio.sent).toHaveLength(0);
    } finally {
      process.env.OTP_HASH_KEY = saved;
    }
  });
});
