/**
 * Storage security-rules tests, running the REAL production rules
 * (firebase/storage.rules) against the emulator.
 *
 * This is the FIRST Storage rules suite in the project: until now only the
 * Firestore rules were covered, so nothing checked who could read an object.
 * That gap mattered little for avatars and chat media; it is unacceptable in
 * front of identity documents.
 *
 * The refusals are the point. In particular the two that protect the human
 * decision: a provider must not be able to swap the recto after the server has
 * read it, nor delete the evidence once approved.
 */
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
  FirebaseStorage,
} from 'firebase/storage';
import { readFileSync } from 'fs';
import { resolve } from 'path';

let env: RulesTestEnvironment;

const OWNER = 'p1';
const OTHER = 'p2';

// A FRESH prefix per test, and not a shared one cleaned between tests.
// `env.clearStorage()` is not recursive: it lists the bucket root and deletes
// only the items it finds there, never walking into prefixes. With a shared
// path, the object written by the first test survived, and every later test
// aiming at it was refused by `resource == null` instead of by the guard it
// names. The suite stayed green even with `isSelf(uid)` relaxed to `signedIn()`,
// the image check removed and the ceiling raised to 500 MB.
let BATCH = 'batch0000';
let RECTO = '';

const JPEG = { contentType: 'image/jpeg' };
const bytes = (n = 16) => new Uint8Array(n).fill(1);

const asOwner = () =>
  env.authenticatedContext(OWNER).storage() as unknown as FirebaseStorage;
const asOther = () =>
  env.authenticatedContext(OTHER).storage() as unknown as FirebaseStorage;
const asAdmin = () =>
  env.authenticatedContext('boss', { admin: true }).storage() as unknown as FirebaseStorage;
const asModerator = () =>
  env.authenticatedContext('mod', { moderator: true }).storage() as unknown as FirebaseStorage;
const asSupport = () =>
  env.authenticatedContext('sup', { support: true }).storage() as unknown as FirebaseStorage;
const asAnon = () =>
  env.unauthenticatedContext().storage() as unknown as FirebaseStorage;

beforeAll(async () => {
  const hostPort = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199';
  const [host, port] = hostPort.split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-outalma',
    storage: {
      host,
      port: Number(port),
      rules: readFileSync(
        resolve(__dirname, '../../firebase/storage.rules'),
        'utf8'
      ),
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

let counter = 0;

beforeEach(() => {
  counter += 1;
  BATCH = `batch${String(counter).padStart(4, '0')}`;
  RECTO = `private/identity/${OWNER}/${BATCH}/recto.jpg`;
});

/// Puts an object in place bypassing the rules, so a later denial can only come
/// from the rule under test.
async function seedObject(path: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const storage = ctx.storage() as unknown as FirebaseStorage;
    await uploadBytes(ref(storage, path), bytes(), JPEG);
  });
}

describe('upload: who may put an identity document in place', () => {
  it('lets the provider upload the three expected files under their own prefix', async () => {
    const storage = asOwner();
    for (const name of ['recto.jpg', 'verso.jpg', 'selfie.jpg']) {
      await assertSucceeds(
        uploadBytes(
          ref(storage, `private/identity/${OWNER}/${BATCH}/${name}`),
          bytes(),
          JPEG
        )
      );
    }
  });

  it('refuses an upload under another provider prefix', async () => {
    await assertFails(
      uploadBytes(
        ref(asOther(), RECTO),
        bytes(),
        JPEG
      )
    );
  });

  it('refuses an anonymous upload', async () => {
    await assertFails(uploadBytes(ref(asAnon(), RECTO), bytes(), JPEG));
  });

  it('refuses a filename outside the expected three', async () => {
    // Otherwise an authenticated user could pile up arbitrary objects under
    // their own prefix, which nothing would ever purge.
    await assertFails(
      uploadBytes(
        ref(asOwner(), `private/identity/${OWNER}/${BATCH}/payload.jpg`),
        bytes(),
        JPEG
      )
    );
  });

  it('refuses a non-image content type', async () => {
    await assertFails(
      uploadBytes(ref(asOwner(), RECTO), bytes(), {
        contentType: 'application/pdf',
      })
    );
  });

  it('refuses an image above the 5 MB ceiling', async () => {
    // Enforced by the rule, not only by a client that could be bypassed.
    const tooBig = new Uint8Array(5 * 1024 * 1024 + 1).fill(1);
    await assertFails(uploadBytes(ref(asOwner(), RECTO), tooBig, JPEG));
  });
});

describe('immutability: a submitted document cannot change', () => {
  it('refuses an overwrite by the owner', async () => {
    // The guard this proves: the server reads the MRZ, freezes the number and
    // the checksum verdict from the bytes at submission time, and a human
    // compares the selfie against the recto up to 48h later. If the owner could
    // swap the recto in between, the reviewer would be deciding on bytes the
    // client still controls, next to review aids computed from an image that no
    // longer exists.
    await seedObject(RECTO);
    await assertFails(uploadBytes(ref(asOwner(), RECTO), bytes(32), JPEG));
  });

  it('refuses a delete by the owner', async () => {
    // And once approved, the holder of the badge must not be able to erase the
    // evidence of their own verification (decision D4: kept until the account
    // is deleted).
    await seedObject(RECTO);
    await assertFails(deleteObject(ref(asOwner(), RECTO)));
  });

  it('refuses an overwrite and a delete by a third party', async () => {
    await seedObject(RECTO);
    await assertFails(uploadBytes(ref(asOther(), RECTO), bytes(32), JPEG));
    await assertFails(deleteObject(ref(asOther(), RECTO)));
  });
});

describe('read: who may look at an identity document', () => {
  beforeEach(async () => {
    await seedObject(RECTO);
  });

  it('allows admin and moderator', async () => {
    await assertSucceeds(getBytes(ref(asAdmin(), RECTO)));
    await assertSucceeds(getBytes(ref(asModerator(), RECTO)));
  });

  it('refuses support, which the service moderation helper would have allowed', async () => {
    // approveService uses assertMinSupportClaim; reusing that helper here would
    // widen the circle that sees identity documents (decision D8).
    await assertFails(getBytes(ref(asSupport(), RECTO)));
  });

  it('refuses another provider and an anonymous caller', async () => {
    await assertFails(getBytes(ref(asOther(), RECTO)));
    await assertFails(getBytes(ref(asAnon(), RECTO)));
  });

  it('refuses the owner, who has no reason to read their own submission back', async () => {
    // Deliberate departure from the other private paths (avatar, chat media),
    // which allow any signed-in reader because they rely on an unguessable
    // tokenised URL. No such URL is ever stored here, so this rule is the only
    // way in and it stays closed.
    await assertFails(getBytes(ref(asOwner(), RECTO)));
  });
});
