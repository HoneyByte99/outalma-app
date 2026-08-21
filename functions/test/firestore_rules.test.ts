// Firestore security-rules tests, run the REAL production rules
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

// The pricing grid, as it lives in config/pricing (archi section 3.1). Seeded
// (rules disabled) before any test that writes a service, since the price guard
// reads it on every service create/update.
const PRICING_GRID = {
  version: 1,
  currency: 'XOF',
  boundedCategories: ['menage', 'cuisine', 'gardeEnfants', 'repassage'],
  maxExtraTasks: 3,
  modes: {
    hourly: { min: 1000, max: 3500, extraBonusPercent: 25 },
    daily: { min: 2000, max: 10000, extraBonusPercent: 25 },
    monthly: { min: 50000, max: 150000, extraBonusPercent: 0, isRange: true },
  },
};
const seedPricing = () =>
  seed((db) => setDoc(doc(db, 'config/pricing'), PRICING_GRID));

// ---------------------------------------------------------------------------
// S2, providers: owner cannot self-clear moderation fields
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

  test('owner CAN flip their own availability (active)', async () => {
    // `active` is the owner-controlled Disponible/En pause switch, not a
    // moderation field, so self-writes are allowed.
    await assertSucceeds(
      updateDoc(doc(asUser('p1'), 'providers/p1'), { active: false })
    );
  });

  test('admin CAN lift suspension', async () => {
    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'providers/p1'), { suspended: false })
    );
  });
});

// ---------------------------------------------------------------------------
// S3, bookings are server-authoritative; no client update
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
// S4, chat reactions own-key only; edit locked after booking done
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
// Message create gating, blocked pair cannot message
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
// Reviews create gating, bilateral after done, but never between a blocked
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
// Services publish gate, a service goes live only with an active provider
// profile (E1). Drafts are always allowed.
// ---------------------------------------------------------------------------
describe('services publish gate', () => {
  // menage is a bounded category, so the price guard now applies: seed the grid
  // and give the service an in-range hourly price + empty extraTasks.
  beforeEach(seedPricing);

  function svc(db: Firestore, published: boolean) {
    return setDoc(doc(db, 'services/s1'), {
      providerId: 'alice',
      published,
      title: 'x',
      categoryId: 'menage',
      priceType: 'hourly',
      price: 2000,
      extraTasks: [],
    });
  }

  test('draft is allowed without any provider profile', async () => {
    await assertSucceeds(svc(asUser('alice'), false));
  });

  test('publish is allowed without a profile (active by default)', async () => {
    await assertSucceeds(svc(asUser('alice'), true));
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
// Encadre pricing guard (spec pricing-ranges): the server, not the app, is the
// source of truth for price bounds. Reads config/pricing on every write.
// ---------------------------------------------------------------------------
describe('pricing guard', () => {
  beforeEach(seedPricing);

  const base = (over: Record<string, unknown> = {}) => ({
    providerId: 'alice',
    published: false,
    title: 'x',
    categoryId: 'menage',
    priceType: 'hourly',
    price: 2000,
    extraTasks: [] as string[],
    ...over,
  });
  const write = (over: Record<string, unknown> = {}, id = 's1') =>
    setDoc(doc(asUser('alice'), `services/${id}`), base(over));

  // Validates the three rule constructs the design assumes (archi 4.2, R4):
  // let-bindings, toSet().hasOnly() on a list, nested ternary. If any were
  // unsupported the in-range accept below would error out instead of passing.
  test('accepts an in-range hourly price', async () => {
    await assertSucceeds(write());
  });

  test('rejects a price below the floor', async () => {
    await assertFails(write({ price: 999 }));
  });

  test('rejects a price above the ceiling', async () => {
    await assertFails(write({ price: 3501 }));
  });

  test('accepts the exact floor and ceiling', async () => {
    await assertSucceeds(write({ price: 1000 }, 'floor'));
    await assertSucceeds(write({ price: 3500 }, 'ceil'));
  });

  test('one extra task raises the ceiling to 4375', async () => {
    await assertSucceeds(write({ price: 4375, extraTasks: ['cuisine'] }, 'x1'));
    await assertFails(write({ price: 4376, extraTasks: ['cuisine'] }, 'x2'));
  });

  test('the floor never moves with extra tasks', async () => {
    // Still 1000, not raised by the extra task (spec decision 10).
    await assertSucceeds(write({ price: 1000, extraTasks: ['cuisine'] }, 'f1'));
    await assertFails(write({ price: 999, extraTasks: ['cuisine'] }, 'f2'));
  });

  test('rejects more than three extra tasks', async () => {
    await assertFails(
      write({
        price: 3000,
        extraTasks: ['cuisine', 'gardeEnfants', 'repassage', 'menage'],
      })
    );
  });

  test('rejects an extra task equal to the main category', async () => {
    await assertFails(write({ extraTasks: ['menage'] }));
  });

  test('rejects an extra task outside the bounded categories', async () => {
    await assertFails(write({ extraTasks: ['plomberie'] }));
  });

  test('rejects an unknown priceType', async () => {
    await assertFails(write({ priceType: 'weekly', price: 2000 }));
  });

  test('rejects a priceMax present outside the monthly mode', async () => {
    await assertFails(write({ price: 2000, priceMax: 3000 }));
  });

  describe('monthly range', () => {
    const monthly = (over: Record<string, unknown> = {}, id = 'm1') =>
      setDoc(
        doc(asUser('alice'), `services/${id}`),
        base({
          priceType: 'monthly',
          price: 60000,
          priceMax: 90000,
          ...over,
        })
      );

    test('accepts a valid min/max range', async () => {
      await assertSucceeds(monthly());
    });

    test('rejects a max below the min', async () => {
      await assertFails(monthly({ price: 90000, priceMax: 60000 }));
    });

    test('rejects a min below the floor', async () => {
      await assertFails(monthly({ price: 49000, priceMax: 90000 }));
    });

    test('rejects a max above the ceiling', async () => {
      await assertFails(monthly({ price: 60000, priceMax: 150001 }));
    });

    test('rejects a monthly listing missing priceMax', async () => {
      await assertFails(
        setDoc(
          doc(asUser('alice'), 'services/m_nomax'),
          base({ priceType: 'monthly', price: 60000 })
        )
      );
    });
  });

  test('leaves the five off-launch categories at a free price', async () => {
    await assertSucceeds(
      setDoc(doc(asUser('alice'), 'services/free1'), {
        providerId: 'alice',
        published: false,
        title: 'x',
        categoryId: 'plomberie',
        priceType: 'hourly',
        price: 999999,
      })
    );
  });

  test('rejects an out-of-range price on UPDATE too', async () => {
    await seed((db) =>
      setDoc(doc(db, 'services/upd'), base({ price: 2000 }))
    );
    await assertFails(
      updateDoc(doc(asUser('alice'), 'services/upd'), { price: 50000 })
    );
    await assertSucceeds(
      updateDoc(doc(asUser('alice'), 'services/upd'), { price: 3000 })
    );
  });

  test('fails closed when config/pricing is absent', async () => {
    await env.clearFirestore(); // remove the seeded grid
    await assertFails(write({ price: 2000 }));
  });

  describe('config/pricing document', () => {
    test('is readable by an anonymous client', async () => {
      await assertSucceeds(getDoc(doc(anon(), 'config/pricing')));
    });

    test('cannot be written by an authenticated client', async () => {
      await assertFails(
        setDoc(doc(asUser('alice'), 'config/pricing'), PRICING_GRID)
      );
    });

    test('cannot be written even by an admin (console-only)', async () => {
      await assertFails(
        setDoc(doc(asAdmin(), 'config/pricing'), PRICING_GRID)
      );
    });
  });
});

// ---------------------------------------------------------------------------
// Data export requests, owner + support read; client cannot self-create
// ---------------------------------------------------------------------------
describe('data export requests', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'data_export_requests/r1'), {
        userId: 'alice',
        email: 'alice@example.com',
        status: 'pending',
      })
    );
  });

  test('owner can read their own request', async () => {
    await assertSucceeds(getDoc(doc(asUser('alice'), 'data_export_requests/r1')));
  });

  test('another user cannot read it', async () => {
    await assertFails(getDoc(doc(asUser('bob'), 'data_export_requests/r1')));
  });

  test('support can read it', async () => {
    await assertSucceeds(
      getDoc(doc(asUser('sup', { support: true }), 'data_export_requests/r1'))
    );
  });

  test('a client cannot create a request directly (Cloud Function only)', async () => {
    await assertFails(
      setDoc(doc(asUser('alice'), 'data_export_requests/r2'), {
        userId: 'alice',
        email: 'alice@example.com',
        status: 'pending',
      })
    );
  });
});

// ---------------------------------------------------------------------------
// Core invariants, users PII guard, notifications, default deny
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
