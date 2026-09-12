// Retention and erasure of the OTP guard documents: the scheduled purge
// (budget line S11) and the account-deletion cleanup (S10).
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({
  projectId: 'demo-outalma',
  storageBucket: 'demo-outalma.appspot.com',
});

process.env.OTP_HASH_KEY = 'test-hmac-key';

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  OTP_COUNTERS,
  OTP_STATES,
  OTP_STATE_TTL_MS,
  phoneHash,
} from '../src/otp_rate_limit';
import { clearFirestore } from './helpers';

const db = () => admin.firestore();
const wrap = (fn: unknown) => tf.wrap(fn as never);
const KEY = 'test-hmac-key';

const SN = '+221771234567';
const FR_TRUNK = '+330612345678';

async function seedState(phone: string, ageMs: number): Promise<string> {
  const id = phoneHash(phone, KEY);
  await db()
    .collection(OTP_STATES)
    .doc(id)
    .set({ creditTimestampsMs: [Date.now() - ageMs], updatedAtMs: Date.now() - ageMs });
  return id;
}

async function deleteUser(uid: string): Promise<void> {
  try {
    await admin.auth().deleteUser(uid);
  } catch {
    /* not there */
  }
}

beforeEach(async () => {
  await clearFirestore();
});

afterAll(() => tf.cleanup());

describe('purgeExpiredOtpStates', () => {
  it('deletes guard documents past the TTL and keeps fresh ones', async () => {
    const stale = await seedState(SN, OTP_STATE_TTL_MS + 60_000);
    const fresh = await seedState('+221770000002', 60_000);

    await wrap(fns.purgeExpiredOtpStates)({} as never);

    expect((await db().collection(OTP_STATES).doc(stale).get()).exists).toBe(false);
    expect((await db().collection(OTP_STATES).doc(fresh).get()).exists).toBe(true);
  });

  it('sweeps the daily counters too, which would grow forever otherwise', async () => {
    await db()
      .collection(OTP_COUNTERS)
      .doc('2020-01-01')
      .set({ count: 12, updatedAtMs: Date.now() - OTP_STATE_TTL_MS - 60_000 });
    await db()
      .collection(OTP_COUNTERS)
      .doc('2026-09-12')
      .set({ count: 3, updatedAtMs: Date.now() });

    await wrap(fns.purgeExpiredOtpStates)({} as never);

    expect((await db().collection(OTP_COUNTERS).doc('2020-01-01').get()).exists).toBe(false);
    expect((await db().collection(OTP_COUNTERS).doc('2026-09-12').get()).exists).toBe(true);
  });

  it('keeps the TTL above the longest counting window', async () => {
    // A shorter TTL would erase a 24h counter before it expires and hand back
    // a fresh quota every night.
    expect(OTP_STATE_TTL_MS).toBeGreaterThan(24 * 60 * 60 * 1000);
  });
});

describe('deleteMyAccount and the guard document', () => {
  const UID = 'otp-del-1';

  beforeEach(() => deleteUser(UID));
  afterAll(() => deleteUser(UID));

  it('erases the guard document with the account', async () => {
    await admin.auth().createUser({ uid: UID, phoneNumber: SN });
    const id = await seedState(SN, 1000);
    await db().collection('users').doc(UID).set({ id: UID, displayName: 'X' });

    await wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: UID } } as never);

    expect((await db().collection(OTP_STATES).doc(id).get()).exists).toBe(false);
  });

  it('finds the document of an account created with a trunk zero', async () => {
    // Auth stores what sign-up sent, which may carry the national zero. The
    // guard is keyed on the NORMALISED form, so hashing the raw string here
    // would leave the document behind.
    await admin.auth().createUser({ uid: UID, phoneNumber: FR_TRUNK });
    const id = await seedState(FR_TRUNK, 1000);
    await db().collection('users').doc(UID).set({ id: UID, displayName: 'X' });

    await wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: UID } } as never);

    expect((await db().collection(OTP_STATES).doc(id).get()).exists).toBe(false);
  });

  it('still deletes the account when the hashing key is missing', async () => {
    // Erasure is a GDPR right and an App Store requirement: it must never fall
    // over on a cleanup of a denormalised index.
    await admin.auth().createUser({ uid: UID, phoneNumber: SN });
    await seedState(SN, 1000);
    await db().collection('users').doc(UID).set({ id: UID, displayName: 'X' });

    const saved = process.env.OTP_HASH_KEY;
    process.env.OTP_HASH_KEY = '';
    try {
      await wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: UID } } as never);
    } finally {
      process.env.OTP_HASH_KEY = saved;
    }

    await expect(admin.auth().getUser(UID)).rejects.toThrow();
  });

  it('skips the step for an account with no phone number', async () => {
    await admin.auth().createUser({ uid: UID, email: 'x@example.com' });
    await db().collection('users').doc(UID).set({ id: UID, displayName: 'X' });

    await wrap(fns.deleteMyAccount)({ data: {}, auth: { uid: UID } } as never);

    await expect(admin.auth().getUser(UID)).rejects.toThrow();
  });
});
