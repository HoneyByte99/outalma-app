/**
 * Firestore security-rules tests for identity verification, running the REAL
 * production rules (firebase/firestore.rules) against the emulator.
 *
 * The valuable cases here are the refusals. Each one proves a specific guard,
 * not merely the absence of a document: the file is seeded first with rules
 * disabled, so a denial can only come from the rule under test.
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

const OWNER = 'p1';
const OTHER = 'p2';
const VERIF = 'v1';

const asOwner = () => env.authenticatedContext(OWNER).firestore() as unknown as Firestore;
const asOther = () => env.authenticatedContext(OTHER).firestore() as unknown as Firestore;
const asAdmin = () => env.authenticatedContext('boss', { admin: true }).firestore() as unknown as Firestore;
const asModerator = () => env.authenticatedContext('mod', { moderator: true }).firestore() as unknown as Firestore;
const asSupport = () => env.authenticatedContext('sup', { support: true }).firestore() as unknown as Firestore;
const asReadonly = () => env.authenticatedContext('ro', { readonly: true }).firestore() as unknown as Firestore;
const asAnon = () => env.unauthenticatedContext().firestore() as unknown as Firestore;

const verifDoc = (db: Firestore) => doc(db, 'identity_verifications', VERIF);
const internalDoc = (db: Firestore) =>
  doc(db, 'identity_verifications', VERIF, 'identity_internal', 'review');
const stateDoc = (db: Firestore) => doc(db, 'identity_verification_states', OWNER);

beforeAll(async () => {
  const hostPort = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8085';
  const [host, port] = hostPort.split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-outalma',
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(
        resolve(__dirname, '../../firebase/firestore.rules'),
        'utf8'
      ),
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore() as unknown as Firestore;
    await setDoc(doc(db, 'identity_verifications', VERIF), {
      providerId: OWNER,
      status: 'pending',
      batchId: 'batch1234',
      cniNumber: '12345678901234567',
      cniNom: 'NDIAYE',
      rejectionReason: null,
    });
    await setDoc(
      doc(db, 'identity_verifications', VERIF, 'identity_internal', 'review'),
      {
        providerId: OWNER,
        rectoPath: `private/identity/${OWNER}/batch1234/recto.jpg`,
        cniNumberKey: '12345678901234567',
        doublonPotentiel: true,
        // The whole reason for the split: this is another provider's file id.
        doublonReferenceId: 'v-someone-else',
      }
    );
    await setDoc(doc(db, 'identity_verification_states', OWNER), {
      pendingId: VERIF,
      verified: false,
      rejectedCount: 0,
    });
  });
});

describe('identity_verifications: who may read a file', () => {
  it('lets the provider read their own file', async () => {
    await assertSucceeds(getDoc(verifDoc(asOwner())));
  });

  it('refuses another provider', async () => {
    await assertFails(getDoc(verifDoc(asOther())));
  });

  it('refuses an anonymous caller', async () => {
    await assertFails(getDoc(verifDoc(asAnon())));
  });

  it('allows admin and moderator', async () => {
    await assertSucceeds(getDoc(verifDoc(asAdmin())));
    await assertSucceeds(getDoc(verifDoc(asModerator())));
  });

  it('refuses support and readonly', async () => {
    // Decision D8: the circle that can see identity documents stops at
    // moderator. approveService uses assertMinSupportClaim, which would have
    // let support in; that helper must not be reused here.
    await assertFails(getDoc(verifDoc(asSupport())));
    await assertFails(getDoc(verifDoc(asReadonly())));
  });
});

describe('identity_verifications: nobody writes from a client', () => {
  it('refuses the owner', async () => {
    await assertFails(updateDoc(verifDoc(asOwner()), { status: 'approved' }));
    await assertFails(deleteDoc(verifDoc(asOwner())));
    await assertFails(
      setDoc(doc(asOwner(), 'identity_verifications', 'forged'), {
        providerId: OWNER,
        status: 'approved',
      })
    );
  });

  it('refuses admin and moderator too', async () => {
    // A verdict is written by a callable, which also traces it and updates the
    // guard document atomically. A console-side write would skip all of that.
    await assertFails(updateDoc(verifDoc(asAdmin()), { status: 'approved' }));
    await assertFails(updateDoc(verifDoc(asModerator()), { status: 'approved' }));
  });
});

describe('identity_internal: the review aids never reach the owner', () => {
  it('refuses the owner, who would otherwise learn a third party file id', async () => {
    await assertFails(getDoc(internalDoc(asOwner())));
  });

  it('refuses another provider, support and anonymous', async () => {
    await assertFails(getDoc(internalDoc(asOther())));
    await assertFails(getDoc(internalDoc(asSupport())));
    await assertFails(getDoc(internalDoc(asAnon())));
  });

  it('allows admin and moderator', async () => {
    await assertSucceeds(getDoc(internalDoc(asAdmin())));
    await assertSucceeds(getDoc(internalDoc(asModerator())));
  });

  it('refuses every client write', async () => {
    await assertFails(updateDoc(internalDoc(asOwner()), { doublonPotentiel: false }));
    await assertFails(updateDoc(internalDoc(asAdmin()), { doublonPotentiel: false }));
  });
});

describe('identity_verification_states: the guard document', () => {
  it('refuses the provider it describes', async () => {
    await assertFails(getDoc(stateDoc(asOwner())));
  });

  it('allows admin and moderator', async () => {
    await assertSucceeds(getDoc(stateDoc(asAdmin())));
    await assertSucceeds(getDoc(stateDoc(asModerator())));
  });

  it('refuses every client write, including the owner clearing their own limit', async () => {
    // Otherwise the rate limit and the "one pending file" guard would both be
    // client-resettable, which is the same as not existing.
    await assertFails(updateDoc(stateDoc(asOwner()), { pendingId: null }));
    await assertFails(updateDoc(stateDoc(asAdmin()), { rejectedCount: 0 }));
    await assertFails(deleteDoc(stateDoc(asOwner())));
  });
});

describe('providers/{uid}: the identity badge flag is server-owned (D6-a)', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore() as unknown as Firestore;
      await setDoc(doc(db, 'providers', OWNER), {
        uid: OWNER,
        active: true,
        suspended: false,
      });
    });
  });

  it('lets the owner write an ordinary profile field, badge or no badge', async () => {
    // E1 (Amath, 2026-08-22) replaced D6-a: the badge left `providers/{uid}`
    // for its own collection, so there is nothing to deny here any more. The
    // owner edits their profile freely, and no key of this document decides
    // anything about trust. Budget line S4 is satisfied by absence, which is
    // the only way it can be satisfied: a deny list only covers the keys
    // someone remembered to list.
    const db = asOwner();
    await assertSucceeds(updateDoc(doc(db, 'providers', OWNER), { bio: 'hello' }));
  });

  it('lets nobody write the public trust projection, whatever their claim', async () => {
    // The projection is derived by the decision transaction through the Admin
    // SDK, which bypasses rules. Every client is refused, INCLUDING the
    // provider it describes and including admin: a value nobody can type by
    // hand cannot be forged, and cannot drift from the verdict it mirrors.
    await assertFails(
      setDoc(doc(asOwner(), 'provider_trust', OWNER), { identityStatus: 'verified' })
    );
    await assertFails(
      setDoc(doc(asOther(), 'provider_trust', OWNER), { identityStatus: 'verified' })
    );
    await assertFails(
      setDoc(doc(asSupport(), 'provider_trust', OWNER), { identityStatus: 'verified' })
    );
    await assertFails(
      setDoc(doc(asModerator(), 'provider_trust', OWNER), { identityStatus: 'verified' })
    );
    await assertFails(
      setDoc(doc(asAdmin(), 'provider_trust', OWNER), { identityStatus: 'verified' })
    );
  });

  it('lets anyone read the public trust projection, signed in or not', async () => {
    // The badge is meant to be read by a client deciding whether to book, and
    // that client may not even have an account yet. The document holds no
    // personal data precisely so that this read is safe.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore() as unknown as Firestore, 'provider_trust', OWNER),
        { identityStatus: 'verified' }
      );
    });
    await assertSucceeds(getDoc(doc(asAnon(), 'provider_trust', OWNER)));
    await assertSucceeds(getDoc(doc(asOther(), 'provider_trust', OWNER)));
  });

  it('refuses the three moderation keys the denylist does name', async () => {
    const db = asOwner();
    await assertFails(
      updateDoc(doc(db, 'providers', OWNER), { suspended: false, suspendedAt: null })
    );
  });

  it('keeps the real verification state out of the client reach', async () => {
    // The invariant that actually protects the badge: the verdict is in a
    // collection where every client write is denied, so the denylist above is
    // never what stands between a provider and their own verification.
    const db = asOwner();
    await assertFails(
      setDoc(doc(db, 'identity_verifications', 'forged-by-owner'), {
        providerId: OWNER,
        status: 'approved',
      })
    );
    await assertFails(
      setDoc(doc(db, 'identity_verification_states', OWNER), { verified: true })
    );
  });
});
