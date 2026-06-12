// Firestore security-rules tests — run the REAL production rules
// (firebase/firestore.rules) against the emulator via @firebase/rules-unit-testing.
// Locks the security fixes S2/S3/S4 and the core access invariants.
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  serverTimestamp,
  Timestamp,
  Firestore,
} from 'firebase/firestore';
import { readFileSync } from 'fs';
import { resolve } from 'path';

let env: RulesTestEnvironment;

beforeAll(async () => {
  const hostPort = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8085';
  const [host, port] = hostPort.split(':');
  // Same projectId as the emulator (single-project mode). The CF tests use the
  // Admin SDK which bypasses rules entirely, so loading the real (strict) rules
  // here never affects them; only these client-SDK tests are rule-checked.
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
});

// Seed data bypassing rules.
function seed(fn: (db: Firestore) => Promise<unknown>): Promise<void> {
  return env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore() as unknown as Firestore);
  });
}

const asUser = (uid: string, claims?: Record<string, unknown>) =>
  env.authenticatedContext(uid, claims).firestore() as unknown as Firestore;
const asAdmin = () => asUser('boss', { admin: true });
const anon = () => env.unauthenticatedContext().firestore() as unknown as Firestore;

// ---------------------------------------------------------------------------
// S2 — providers: owner cannot self-clear moderation fields
// ---------------------------------------------------------------------------
describe('S2 providers moderation fields', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'providers/p1'), { uid: 'p1', suspended: true, bio: 'x' })
    );
  });

  test('owner CANNOT set suspended:false on themselves', async () => {
    await assertFails(
      updateDoc(doc(asUser('p1'), 'providers/p1'), { suspended: false })
    );
  });

  test('owner CAN edit a non-moderation field (bio)', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser('p1'), 'providers/p1'), { bio: 'updated' })
    );
  });

  test('admin CAN lift suspension', async () => {
    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'providers/p1'), { suspended: false })
    );
  });
});

// ---------------------------------------------------------------------------
// S3 — bookings are server-authoritative; no client update
// ---------------------------------------------------------------------------
describe('S3 bookings update is admin-only', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'bookings/b1'), {
        customerId: 'alice',
        providerId: 'bob',
        serviceId: 's1',
        status: 'requested',
      })
    );
  });

  test('participant CANNOT update any booking field', async () => {
    await assertFails(
      updateDoc(doc(asUser('alice'), 'bookings/b1'), {
        scheduledAt: Timestamp.now(),
      })
    );
    await assertFails(
      updateDoc(doc(asUser('bob'), 'bookings/b1'), { chatId: 'forged' })
    );
  });

  test('participant CAN still read their booking', async () => {
    await assertSucceeds(getDoc(doc(asUser('alice'), 'bookings/b1')));
  });

  test('a non-participant cannot read the booking', async () => {
    await assertFails(getDoc(doc(asUser('stranger'), 'bookings/b1')));
  });

  test('admin can update the booking', async () => {
    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'bookings/b1'), { status: 'accepted' })
    );
  });

  test('client cannot create a booking directly', async () => {
    await assertFails(
      setDoc(doc(asUser('alice'), 'bookings/b2'), {
        customerId: 'alice',
        providerId: 'bob',
        serviceId: 's1',
        status: 'requested',
      })
    );
  });
});

// ---------------------------------------------------------------------------
// S4 — chat reactions own-key only; edit locked after booking done
// ---------------------------------------------------------------------------
describe('S4 chat message integrity', () => {
  async function seedChat(opts: { bookingId?: string; bookingStatus?: string }) {
    await seed(async (db) => {
      await setDoc(doc(db, 'chats/c1'), {
        participantIds: ['alice', 'bob'],
        bookingId: opts.bookingId ?? null,
      });
      await setDoc(doc(db, 'chats/c1/messages/m1'), {
        senderId: 'bob',
        text: 'hello',
        reactions: {},
        createdAt: Timestamp.now(),
      });
      if (opts.bookingId) {
        await setDoc(doc(db, `bookings/${opts.bookingId}`), {
          customerId: 'alice',
          providerId: 'bob',
          serviceId: 's1',
          status: opts.bookingStatus ?? 'accepted',
        });
      }
    });
  }

  test('participant CAN set their OWN reaction', async () => {
    await seedChat({});
    await assertSucceeds(
      updateDoc(doc(asUser('alice'), 'chats/c1/messages/m1'), {
        'reactions.alice': '❤️',
      })
    );
  });

  test("participant CANNOT set the OTHER user's reaction", async () => {
    await seedChat({});
    await assertFails(
      updateDoc(doc(asUser('alice'), 'chats/c1/messages/m1'), {
        'reactions.bob': '😂',
      })
    );
  });

  test('sender CAN edit own message while booking active', async () => {
    await seedChat({ bookingId: 'b1', bookingStatus: 'accepted' });
    await assertSucceeds(
      updateDoc(doc(asUser('bob'), 'chats/c1/messages/m1'), {
        text: 'edited',
        edited: true,
      })
    );
  });

  test('sender CANNOT edit once the booking is done (read-only)', async () => {
    await seedChat({ bookingId: 'b1', bookingStatus: 'done' });
    await assertFails(
      updateDoc(doc(asUser('bob'), 'chats/c1/messages/m1'), {
        text: 'sneaky edit',
        edited: true,
      })
    );
  });

  test('a non-participant cannot read messages', async () => {
    await seedChat({});
    await assertFails(getDoc(doc(asUser('stranger'), 'chats/c1/messages/m1')));
  });
});

// ---------------------------------------------------------------------------
// Message create gating — blocked pair cannot message
// ---------------------------------------------------------------------------
describe('message create gating', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'chats/c1'), {
        participantIds: ['alice', 'bob'],
        bookingId: null,
      })
    );
  });

  function newMessage(db: Firestore, id: string) {
    return setDoc(doc(db, `chats/c1/messages/${id}`), {
      senderId: 'alice',
      text: 'hi',
      createdAt: serverTimestamp(),
    });
  }

  test('participant CAN send when not blocked', async () => {
    await assertSucceeds(newMessage(asUser('alice'), 'msg1'));
  });

  test('sender CANNOT spoof another senderId', async () => {
    await assertFails(
      setDoc(doc(asUser('alice'), 'chats/c1/messages/spoof'), {
        senderId: 'bob',
        text: 'hi',
        createdAt: serverTimestamp(),
      })
    );
  });

  test('blocked pair CANNOT message', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users/bob/blockedUsers/alice'), { at: Timestamp.now() })
    );
    await assertFails(newMessage(asUser('alice'), 'msg2'));
  });
});

// ---------------------------------------------------------------------------
// Reviews create gating — bilateral after done, but never between a blocked
// pair (coupure totale).
// ---------------------------------------------------------------------------
describe('reviews block gating', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'bookings/b1'), {
        customerId: 'alice',
        providerId: 'bob',
        status: 'done',
      })
    );
  });

  function review(db: Firestore) {
    return setDoc(doc(db, 'reviews/b1_alice'), {
      bookingId: 'b1',
      reviewerId: 'alice',
      revieweeId: 'bob',
      rating: 5,
    });
  }

  test('client CAN review provider after done when not blocked', async () => {
    await assertSucceeds(review(asUser('alice')));
  });

  test('CANNOT review when the reviewer blocked the reviewee', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users/alice/blockedUsers/bob'), { at: Timestamp.now() })
    );
    await assertFails(review(asUser('alice')));
  });

  test('CANNOT review when the reviewee blocked the reviewer', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users/bob/blockedUsers/alice'), { at: Timestamp.now() })
    );
    await assertFails(review(asUser('alice')));
  });
});

// ---------------------------------------------------------------------------
// Services publish gate — a service goes live only with an active provider
// profile (E1). Drafts are always allowed.
// ---------------------------------------------------------------------------
describe('services publish gate', () => {
  function svc(db: Firestore, published: boolean) {
    return setDoc(doc(db, 'services/s1'), {
      providerId: 'alice',
      published,
      title: 'x',
      categoryId: 'menage',
    });
  }

  test('draft is allowed without any provider profile', async () => {
    await assertSucceeds(svc(asUser('alice'), false));
  });

  test('publish is blocked without a provider profile', async () => {
    await assertFails(svc(asUser('alice'), true));
  });

  test('publish is blocked when the provider profile is suspended', async () => {
    await seed((db) =>
      setDoc(doc(db, 'providers/alice'), { active: true, suspended: true })
    );
    await assertFails(svc(asUser('alice'), true));
  });

  test('publish is allowed with an active, non-suspended profile', async () => {
    await seed((db) =>
      setDoc(doc(db, 'providers/alice'), { active: true, suspended: false })
    );
    await assertSucceeds(svc(asUser('alice'), true));
  });

  test('rejects an off-catalogue categoryId', async () => {
    await assertFails(
      setDoc(doc(asUser('alice'), 'services/s2'), {
        providerId: 'alice',
        published: false,
        title: 'x',
        categoryId: 'hacking',
      })
    );
  });

  test('accepts a catalogue categoryId (draft)', async () => {
    await assertSucceeds(
      setDoc(doc(asUser('alice'), 'services/s2'), {
        providerId: 'alice',
        published: false,
        title: 'x',
        categoryId: 'plomberie',
      })
    );
  });
});

// ---------------------------------------------------------------------------
// Core invariants — users PII guard, notifications, default deny
// ---------------------------------------------------------------------------
describe('core access invariants', () => {
  test('user create cannot include phoneE164 (server-only)', async () => {
    await assertFails(
      setDoc(doc(asUser('alice'), 'users/alice'), {
        displayName: 'Alice',
        phoneE164: '+33600000000',
      })
    );
    await assertSucceeds(
      setDoc(doc(asUser('alice'), 'users/alice'), { displayName: 'Alice' })
    );
  });

  test('user cannot change their email after create', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users/alice'), { displayName: 'A', email: 'a@x.dev' })
    );
    await assertFails(
      updateDoc(doc(asUser('alice'), 'users/alice'), { email: 'evil@x.dev' })
    );
  });

  test('notifications: owner reads own, cannot create, can only flip read', async () => {
    await seed((db) =>
      setDoc(doc(db, 'notifications/alice/items/n1'), {
        type: 'x',
        read: false,
      })
    );
    await assertSucceeds(
      getDoc(doc(asUser('alice'), 'notifications/alice/items/n1'))
    );
    await assertFails(
      getDoc(doc(asUser('bob'), 'notifications/alice/items/n1'))
    );
    await assertFails(
      setDoc(doc(asUser('alice'), 'notifications/alice/items/n2'), {
        type: 'y',
        read: false,
      })
    );
    await assertSucceeds(
      updateDoc(doc(asUser('alice'), 'notifications/alice/items/n1'), {
        read: true,
      })
    );
    await assertFails(
      updateDoc(doc(asUser('alice'), 'notifications/alice/items/n1'), {
        type: 'tampered',
      })
    );
  });

  test('reviews reject out-of-range ratings / unauthenticated', async () => {
    await assertFails(
      setDoc(doc(anon(), 'reviews/x'), { rating: 5, reviewerId: 'a' })
    );
  });

  test('default-deny: unknown collection is not readable', async () => {
    await assertFails(getDoc(doc(asUser('alice'), 'secret_stuff/x')));
  });
});
