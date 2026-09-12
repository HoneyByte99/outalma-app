/**
 * Security-rules tests for the three OTP rate-limit collections, running the
 * REAL production rules (firebase/firestore.rules) against the emulator.
 *
 * These pass today thanks to the terminal `match /{document=**}` deny in the
 * rules file, and that is not a reason to skip them: this is a RATCHET, not
 * filler. It goes red the day someone opens `otp_config` for reading, which is
 * exactly the mistake worth catching, since publishing the stop threshold tells
 * an attacker how many requests close phone sign-in for everyone.
 */
import {
  initializeTestEnvironment,
  assertFails,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, Firestore } from 'firebase/firestore';
import { readFileSync } from 'fs';
import { resolve } from 'path';

let env: RulesTestEnvironment;

const asUser = () => env.authenticatedContext('u1').firestore() as unknown as Firestore;
const asAdmin = () =>
  env.authenticatedContext('boss', { admin: true }).firestore() as unknown as Firestore;
const asAnon = () => env.unauthenticatedContext().firestore() as unknown as Firestore;

const HASH = 'a'.repeat(64);

const targets = (db: Firestore) => [
  ['otp_request_states', doc(db, 'otp_request_states', HASH)] as const,
  ['otp_global_counters', doc(db, 'otp_global_counters', '2026-09-12')] as const,
  ['otp_config', doc(db, 'otp_config', 'thresholds')] as const,
];

beforeAll(async () => {
  const hostPort = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8085';
  const [host, port] = hostPort.split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-outalma',
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(resolve(__dirname, '../../firebase/firestore.rules'), 'utf8'),
    },
  });
});

afterAll(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'otp_request_states', HASH), {
      creditTimestampsMs: [1],
      updatedAtMs: 1,
    });
    await setDoc(doc(db, 'otp_global_counters', '2026-09-12'), { count: 3, updatedAtMs: 1 });
    await setDoc(doc(db, 'otp_config', 'thresholds'), { alertAt: 300, stopAt: 600 });
  });
});

describe('OTP rate-limit collections are invisible and untouchable', () => {
  for (const [label, role] of [
    ['an anonymous visitor', asAnon],
    ['a signed-in user', asUser],
    ['an admin', asAdmin],
  ] as const) {
    describe(label, () => {
      it('cannot READ any of the three', async () => {
        for (const [name, ref] of targets(role())) {
          await assertFails(getDoc(ref)).catch((e) => {
            throw new Error(`${name} was readable by ${label}: ${e}`);
          });
        }
      });

      it('cannot WRITE any of the three', async () => {
        for (const [name, ref] of targets(role())) {
          await assertFails(setDoc(ref, { count: 999 })).catch((e) => {
            throw new Error(`${name} was writable by ${label}: ${e}`);
          });
        }
      });

      it('cannot DELETE any of the three', async () => {
        for (const [name, ref] of targets(role())) {
          await assertFails(deleteDoc(ref)).catch((e) => {
            throw new Error(`${name} was deletable by ${label}: ${e}`);
          });
        }
      });
    });
  }

  it('keeps otp_config closed to reads, unlike the public config collection', async () => {
    // config/{docId} is `allow read: if true` and holds the pricing grid.
    // otp_config must NOT follow it: the stop threshold is a security value.
    await assertFails(getDoc(doc(asAnon(), 'otp_config', 'thresholds')));
  });
});
