/**
 * Security-rules tests for the public rating aggregate, running the REAL
 * production rules (firebase/firestore.rules) against the emulator, not the
 * permissive emulator ruleset the rest of the suite runs under.
 *
 * The refusals are the point: a reputation the subject can type is not a
 * reputation (budget line S1), so `write: if false` must hold for the provider
 * it describes, for a stranger, and for an admin alike.
 */
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, Firestore } from 'firebase/firestore';
import { readFileSync } from 'fs';
import { resolve } from 'path';

let env: RulesTestEnvironment;

const PROVIDER = 'p1';
const OTHER = 'p2';

const asProvider = () => env.authenticatedContext(PROVIDER).firestore() as unknown as Firestore;
const asOther = () => env.authenticatedContext(OTHER).firestore() as unknown as Firestore;
const asAdmin = () => env.authenticatedContext('boss', { admin: true }).firestore() as unknown as Firestore;
const asAnon = () => env.unauthenticatedContext().firestore() as unknown as Firestore;

const ratingDoc = (db: Firestore) => doc(db, 'provider_ratings', PROVIDER);
const eventDoc = (db: Firestore) => doc(db, 'rating_events', 'r1');

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
    await setDoc(doc(db, 'provider_ratings', PROVIDER), {
      ratingSum: 12,
      ratingCount: 3,
    });
    await setDoc(doc(db, 'rating_events', 'r1'), { counted: true });
  });
});

describe('provider_ratings', () => {
  it('is readable by anyone, including a visitor with no account', async () => {
    await assertSucceeds(getDoc(ratingDoc(asAnon())));
    await assertSucceeds(getDoc(ratingDoc(asOther())));
  });

  it('cannot be written by the provider it describes', async () => {
    await assertFails(updateDoc(ratingDoc(asProvider()), { ratingSum: 999 }));
    await assertFails(setDoc(ratingDoc(asProvider()), { ratingSum: 999, ratingCount: 200 }));
    await assertFails(deleteDoc(ratingDoc(asProvider())));
  });

  it('cannot be written by a stranger, nor by an admin', async () => {
    await assertFails(updateDoc(ratingDoc(asOther()), { ratingSum: 0 }));
    await assertFails(updateDoc(ratingDoc(asAdmin()), { ratingSum: 0 }));
  });

  it('cannot be CREATED by a client on an absent document either', async () => {
    // The refusal must not depend on the document already existing: inventing
    // a reputation for a provider who has none is the same attack.
    const fresh = doc(asOther() as Firestore, 'provider_ratings', 'never_rated');
    await assertFails(setDoc(fresh, { ratingSum: 25, ratingCount: 5 }));
  });
});

describe('rating_events', () => {
  it('is invisible and untouchable from any client', async () => {
    await assertFails(getDoc(eventDoc(asAnon())));
    await assertFails(getDoc(eventDoc(asProvider())));
    await assertFails(getDoc(eventDoc(asAdmin())));
    await assertFails(setDoc(eventDoc(asProvider()), { counted: false }));
  });
});
