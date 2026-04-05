/**
 * Firestore security rules — full test suite.
 *
 * Covers every collection defined in firebase/firestore.rules:
 *   users · providers · blocked_slots · service_types · services
 *   bookings · chats · chats/messages · bookings/phoneShares
 *   reviews · reports · user_roles · admin_logs · notifications
 *   user_sessions (direct + collectionGroup)
 *
 * Prerequisites:
 *   firebase emulators:start --only firestore   (from the project root)
 *   cd tests && npm install && npm test
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import {
  Timestamp,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { afterAll, beforeAll, describe, it } from 'vitest';

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

const __dirname = dirname(fileURLToPath(import.meta.url));
const RULES = readFileSync(resolve(__dirname, '../firebase/firestore.rules'), 'utf8');

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'outalmaservice-d1e59',
    firestore: { rules: RULES, host: 'localhost', port: 8080 },
  });

  // Seed all fixtures once (bypasses rules).
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    // users
    await setDoc(doc(db, 'users/u1'), { id: 'u1', email: 'u1@test.com' });

    // providers
    await setDoc(doc(db, 'providers/p1'), { id: 'p1', displayName: 'Alice' });

    // blocked_slots
    await setDoc(doc(db, 'providers/p1/blocked_slots/s1'), { providerId: 'p1' });

    // service_types
    await setDoc(doc(db, 'service_types/st1'), { label: 'Plomberie' });

    // services
    await setDoc(doc(db, 'services/svc1'), { providerId: 'p1', published: true });

    // bookings
    await setDoc(doc(db, 'bookings/b1'), {
      customerId: 'customer1',
      providerId: 'provider1',
      serviceId: 'svc1',
      status: 'requested',
    });
    await setDoc(doc(db, 'bookings/b_accepted'), {
      customerId: 'customer1',
      providerId: 'provider1',
      serviceId: 'svc1',
      status: 'accepted',
    });

    // chats
    await setDoc(doc(db, 'chats/chat1'), {
      participantIds: ['customer1', 'provider1'],
      bookingId: 'b1',
    });

    // messages
    await setDoc(doc(db, 'chats/chat1/messages/msg1'), {
      senderId: 'customer1',
      text: 'Hello',
      createdAt: Timestamp.now(),
      readBy: ['customer1'],
    });

    // phoneShares
    await setDoc(doc(db, 'bookings/b_accepted/phoneShares/customer1'), {
      phone: '+33600000000',
      createdAt: Timestamp.now(),
    });

    // reviews
    await setDoc(doc(db, 'reviews/r1'), {
      reviewerId: 'customer1',
      bookingId: 'b1',
      rating: 4,
    });

    // reports
    await setDoc(doc(db, 'reports/rep1'), {
      reporterId: 'customer1',
      targetId: 'svc1',
      status: 'open',
    });

    // user_roles
    await setDoc(doc(db, 'user_roles/admin-uid'), { uid: 'admin-uid', admin: true });

    // admin_logs
    await setDoc(doc(db, 'admin_logs/log1'), { action: 'test', actorUid: 'admin-uid' });

    // notifications
    await setDoc(doc(db, 'notifications/u1/items/n1'), {
      type: 'booking_accepted',
      title: 'Test',
      body: 'Body',
      read: false,
    });

    // user_sessions
    await setDoc(doc(db, 'user_sessions/u1'), { uid: 'u1', lastPlatform: 'android' });
    await setDoc(doc(db, 'user_sessions/u1/events/e1'), {
      uid: 'u1', platform: 'android', ip: '1.2.3.4',
      countryCode: 'FR', loggedAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'user_sessions/u2/events/e2'), {
      uid: 'u2', platform: 'ios', ip: '5.6.7.8',
      countryCode: 'SN', loggedAt: Timestamp.now(),
    });
  });
});

afterAll(() => env.cleanup());

// ---------------------------------------------------------------------------
// Shortcuts
// ---------------------------------------------------------------------------

const admin     = () => env.authenticatedContext('admin-uid',   { admin: true });
const moderator = () => env.authenticatedContext('mod-uid',     { moderator: true });
const customer1 = () => env.authenticatedContext('customer1');
const provider1 = () => env.authenticatedContext('provider1');
const prov_p1   = () => env.authenticatedContext('p1');          // owner of providers/p1
const user_u1   = () => env.authenticatedContext('u1');          // owner of users/u1
const stranger  = () => env.authenticatedContext('stranger-uid');
const anon      = () => env.unauthenticatedContext();

// ---------------------------------------------------------------------------
// USERS
// ---------------------------------------------------------------------------

describe('users', () => {
  it('signed-in user can read any user doc', async () => {
    await assertSucceeds(getDoc(doc(stranger().firestore(), 'users/u1')));
  });
  it('anonymous cannot read user doc', async () => {
    await assertFails(getDoc(doc(anon().firestore(), 'users/u1')));
  });
  it('user can create own doc', async () => {
    await assertSucceeds(setDoc(doc(user_u1().firestore(), 'users/u1'),
      { id: 'u1', email: 'u1@test.com' }));
  });
  it('user cannot create doc for another uid', async () => {
    await assertFails(setDoc(doc(stranger().firestore(), 'users/u1'),
      { id: 'u1', email: 'hack@test.com' }));
  });
  it('user can update own doc', async () => {
    await assertSucceeds(setDoc(doc(user_u1().firestore(), 'users/u1'),
      { id: 'u1', email: 'updated@test.com' }, { merge: true }));
  });
  it('user cannot update another user doc', async () => {
    await assertFails(setDoc(doc(stranger().firestore(), 'users/u1'),
      { email: 'hack@test.com' }, { merge: true }));
  });
  it('admin can delete user doc', async () => {
    // Use a throwaway doc so fixture stays intact
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'users/del_me'), { id: 'del_me' }));
    await assertSucceeds(deleteDoc(doc(admin().firestore(), 'users/del_me')));
  });
  it('non-admin cannot delete user doc', async () => {
    await assertFails(deleteDoc(doc(user_u1().firestore(), 'users/u1')));
  });
});

// ---------------------------------------------------------------------------
// PROVIDERS
// ---------------------------------------------------------------------------

describe('providers', () => {
  it('anonymous can read providers', async () => {
    await assertSucceeds(getDoc(doc(anon().firestore(), 'providers/p1')));
  });
  it('owner can update own provider doc', async () => {
    await assertSucceeds(setDoc(doc(prov_p1().firestore(), 'providers/p1'),
      { id: 'p1', bio: 'updated' }, { merge: true }));
  });
  it('stranger cannot update provider doc', async () => {
    await assertFails(setDoc(doc(stranger().firestore(), 'providers/p1'),
      { bio: 'hacked' }, { merge: true }));
  });
  it('admin can delete provider doc', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'providers/del_p'), { id: 'del_p' }));
    await assertSucceeds(deleteDoc(doc(admin().firestore(), 'providers/del_p')));
  });
  it('non-admin cannot delete provider doc', async () => {
    await assertFails(deleteDoc(doc(prov_p1().firestore(), 'providers/p1')));
  });
});

// ---------------------------------------------------------------------------
// BLOCKED SLOTS
// ---------------------------------------------------------------------------

describe('providers/{uid}/blocked_slots', () => {
  it('signed-in user can read blocked slots', async () => {
    await assertSucceeds(
      getDoc(doc(stranger().firestore(), 'providers/p1/blocked_slots/s1')));
  });
  it('anonymous cannot read blocked slots', async () => {
    await assertFails(
      getDoc(doc(anon().firestore(), 'providers/p1/blocked_slots/s1')));
  });
  it('provider owner can create a blocked slot', async () => {
    await assertSucceeds(setDoc(
      doc(prov_p1().firestore(), 'providers/p1/blocked_slots/new_slot'),
      { providerId: 'p1', start: Timestamp.now() }));
  });
  it('stranger cannot create a blocked slot for another provider', async () => {
    await assertFails(setDoc(
      doc(stranger().firestore(), 'providers/p1/blocked_slots/bad_slot'),
      { providerId: 'p1' }));
  });
  it('owner can delete own blocked slot', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'providers/p1/blocked_slots/del_slot'), {}));
    await assertSucceeds(
      deleteDoc(doc(prov_p1().firestore(), 'providers/p1/blocked_slots/del_slot')));
  });
});

// ---------------------------------------------------------------------------
// SERVICE TYPES
// ---------------------------------------------------------------------------

describe('service_types', () => {
  it('anonymous can read service types', async () => {
    await assertSucceeds(getDoc(doc(anon().firestore(), 'service_types/st1')));
  });
  it('admin can write service types', async () => {
    await assertSucceeds(setDoc(doc(admin().firestore(), 'service_types/st_new'),
      { label: 'Jardinage' }));
  });
  it('non-admin cannot write service types', async () => {
    await assertFails(setDoc(doc(stranger().firestore(), 'service_types/st2'),
      { label: 'Hack' }));
  });
  it('moderator cannot write service types', async () => {
    await assertFails(setDoc(doc(moderator().firestore(), 'service_types/st3'),
      { label: 'Nope' }));
  });
});

// ---------------------------------------------------------------------------
// SERVICES
// ---------------------------------------------------------------------------

describe('services', () => {
  it('anonymous can read services', async () => {
    await assertSucceeds(getDoc(doc(anon().firestore(), 'services/svc1')));
  });
  it('provider can create own service', async () => {
    await assertSucceeds(setDoc(doc(prov_p1().firestore(), 'services/svc_new'),
      { providerId: 'p1', title: 'New service', published: false }));
  });
  it('cannot create service for another provider', async () => {
    await assertFails(setDoc(doc(stranger().firestore(), 'services/svc_bad'),
      { providerId: 'p1', title: 'Impersonation' }));
  });
  it('owner can update own service (keepin providerId)', async () => {
    await assertSucceeds(setDoc(doc(prov_p1().firestore(), 'services/svc1'),
      { providerId: 'p1', published: true, title: 'Updated' }));
  });
  it('owner cannot change providerId on update', async () => {
    await assertFails(setDoc(doc(prov_p1().firestore(), 'services/svc1'),
      { providerId: 'other', title: 'Hijack' }));
  });
  it('owner can delete own service', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'services/svc_del'),
        { providerId: 'p1', published: false }));
    await assertSucceeds(deleteDoc(doc(prov_p1().firestore(), 'services/svc_del')));
  });
  it('stranger cannot delete someone else service', async () => {
    await assertFails(deleteDoc(doc(stranger().firestore(), 'services/svc1')));
  });
});

// ---------------------------------------------------------------------------
// BOOKINGS
// ---------------------------------------------------------------------------

describe('bookings', () => {
  it('customer (participant) can read own booking', async () => {
    await assertSucceeds(getDoc(doc(customer1().firestore(), 'bookings/b1')));
  });
  it('provider (participant) can read own booking', async () => {
    await assertSucceeds(getDoc(doc(provider1().firestore(), 'bookings/b1')));
  });
  it('stranger cannot read booking', async () => {
    await assertFails(getDoc(doc(stranger().firestore(), 'bookings/b1')));
  });
  it('admin can read any booking', async () => {
    await assertSucceeds(getDoc(doc(admin().firestore(), 'bookings/b1')));
  });
  it('anonymous cannot read booking', async () => {
    await assertFails(getDoc(doc(anon().firestore(), 'bookings/b1')));
  });

  it('customer can create booking with status=requested', async () => {
    await assertSucceeds(setDoc(doc(customer1().firestore(), 'bookings/b_new'),
      { customerId: 'customer1', providerId: 'provider1', serviceId: 'svc1',
        status: 'requested' }));
  });
  it('customer cannot create booking with status=accepted', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'bookings/b_bad'),
      { customerId: 'customer1', providerId: 'provider1', serviceId: 'svc1',
        status: 'accepted' }));
  });
  it('cannot create booking with wrong customerId', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'bookings/b_bad2'),
      { customerId: 'someone_else', providerId: 'provider1', serviceId: 'svc1',
        status: 'requested' }));
  });

  it('participant can update non-status fields', async () => {
    await assertSucceeds(setDoc(doc(customer1().firestore(), 'bookings/b1'),
      { customerId: 'customer1', providerId: 'provider1', serviceId: 'svc1',
        status: 'requested', requestMessage: 'Updated message' }));
  });
  it('participant cannot change status from client', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'bookings/b1'),
      { customerId: 'customer1', providerId: 'provider1', serviceId: 'svc1',
        status: 'accepted' }));
  });
  it('participant cannot change providerId', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'bookings/b1'),
      { customerId: 'customer1', providerId: 'hacker', serviceId: 'svc1',
        status: 'requested' }));
  });

  it('admin can delete booking', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'bookings/b_del'),
        { customerId: 'c', providerId: 'p', serviceId: 's', status: 'requested' }));
    await assertSucceeds(deleteDoc(doc(admin().firestore(), 'bookings/b_del')));
  });
  it('participant cannot delete booking', async () => {
    await assertFails(deleteDoc(doc(customer1().firestore(), 'bookings/b1')));
  });
});

// ---------------------------------------------------------------------------
// CHATS
// ---------------------------------------------------------------------------

describe('chats', () => {
  it('participant can read chat', async () => {
    await assertSucceeds(getDoc(doc(customer1().firestore(), 'chats/chat1')));
  });
  it('non-participant cannot read chat', async () => {
    await assertFails(getDoc(doc(stranger().firestore(), 'chats/chat1')));
  });
  it('admin can read chat', async () => {
    await assertSucceeds(getDoc(doc(admin().firestore(), 'chats/chat1')));
  });
  it('only admin can create chat', async () => {
    await assertSucceeds(setDoc(doc(admin().firestore(), 'chats/chat_new'),
      { participantIds: ['a', 'b'], bookingId: 'b1' }));
  });
  it('participant cannot create chat', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'chats/chat_hack'),
      { participantIds: ['customer1', 'x'], bookingId: 'b1' }));
  });
  it('only admin can update chat', async () => {
    await assertSucceeds(setDoc(doc(admin().firestore(), 'chats/chat1'),
      { participantIds: ['customer1', 'provider1'], lastMessageAt: Timestamp.now() },
      { merge: true }));
  });
  it('participant cannot update chat doc', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'chats/chat1'),
      { lastMessageAt: Timestamp.now() }, { merge: true }));
  });
  it('only admin can delete chat', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'chats/chat_del'),
        { participantIds: ['customer1', 'provider1'] }));
    await assertSucceeds(deleteDoc(doc(admin().firestore(), 'chats/chat_del')));
  });
});

// ---------------------------------------------------------------------------
// CHATS / MESSAGES
// ---------------------------------------------------------------------------

describe('chats/messages', () => {
  it('participant can read message', async () => {
    await assertSucceeds(
      getDoc(doc(customer1().firestore(), 'chats/chat1/messages/msg1')));
  });
  it('non-participant cannot read message', async () => {
    await assertFails(
      getDoc(doc(stranger().firestore(), 'chats/chat1/messages/msg1')));
  });
  it('admin can read message', async () => {
    await assertSucceeds(
      getDoc(doc(admin().firestore(), 'chats/chat1/messages/msg1')));
  });

  it('participant can create valid message (text)', async () => {
    await assertSucceeds(setDoc(
      doc(customer1().firestore(), 'chats/chat1/messages/msg_new'),
      { senderId: 'customer1', text: 'Hi!', createdAt: Timestamp.now() }));
  });
  it('participant can create valid message (mediaUrl)', async () => {
    await assertSucceeds(setDoc(
      doc(customer1().firestore(), 'chats/chat1/messages/msg_media'),
      { senderId: 'customer1', mediaUrl: 'https://x.com/img.jpg', createdAt: Timestamp.now() }));
  });
  it('cannot create message with wrong senderId', async () => {
    await assertFails(setDoc(
      doc(customer1().firestore(), 'chats/chat1/messages/msg_bad'),
      { senderId: 'someone_else', text: 'Fake', createdAt: Timestamp.now() }));
  });
  it('cannot create message without text or mediaUrl', async () => {
    await assertFails(setDoc(
      doc(customer1().firestore(), 'chats/chat1/messages/msg_empty'),
      { senderId: 'customer1', createdAt: Timestamp.now() }));
  });
  it('non-participant cannot create message', async () => {
    await assertFails(setDoc(
      doc(stranger().firestore(), 'chats/chat1/messages/msg_hack'),
      { senderId: 'stranger-uid', text: 'Hi', createdAt: Timestamp.now() }));
  });

  it('participant can update readBy field only', async () => {
    await assertSucceeds(updateDoc(
      doc(customer1().firestore(), 'chats/chat1/messages/msg1'),
      { readBy: ['customer1'] }));
  });
  it('participant cannot update other fields', async () => {
    await assertFails(updateDoc(
      doc(customer1().firestore(), 'chats/chat1/messages/msg1'),
      { text: 'Modified' }));
  });

  it('admin can delete message', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'chats/chat1/messages/msg_del'),
        { senderId: 'x', text: 'bye', createdAt: Timestamp.now() }));
    await assertSucceeds(
      deleteDoc(doc(admin().firestore(), 'chats/chat1/messages/msg_del')));
  });
  it('participant cannot delete message', async () => {
    await assertFails(
      deleteDoc(doc(customer1().firestore(), 'chats/chat1/messages/msg1')));
  });
});

// ---------------------------------------------------------------------------
// PHONE SHARES
// ---------------------------------------------------------------------------

describe('bookings/phoneShares', () => {
  it('participant can read phoneShare when booking is accepted', async () => {
    await assertSucceeds(
      getDoc(doc(customer1().firestore(),
        'bookings/b_accepted/phoneShares/customer1')));
  });
  it('non-participant cannot read phoneShare', async () => {
    await assertFails(
      getDoc(doc(stranger().firestore(),
        'bookings/b_accepted/phoneShares/customer1')));
  });
  it('participant cannot read phoneShare on non-accepted booking', async () => {
    // b1 has status=requested, not accessible
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'bookings/b1/phoneShares/customer1'),
        { phone: '+33600000000', createdAt: Timestamp.now() }));
    await assertFails(
      getDoc(doc(customer1().firestore(), 'bookings/b1/phoneShares/customer1')));
  });

  it('participant can create own phoneShare on accessible booking', async () => {
    await assertSucceeds(setDoc(
      doc(customer1().firestore(), 'bookings/b_accepted/phoneShares/customer1'),
      { phone: '+33612345678', createdAt: Timestamp.now() }));
  });
  it('participant cannot create phoneShare for another uid', async () => {
    await assertFails(setDoc(
      doc(customer1().firestore(), 'bookings/b_accepted/phoneShares/provider1'),
      { phone: '+33600000000', createdAt: Timestamp.now() }));
  });
  it('cannot create phoneShare without phone field', async () => {
    await assertFails(setDoc(
      doc(customer1().firestore(), 'bookings/b_accepted/phoneShares/customer1'),
      { createdAt: Timestamp.now() }));
  });
  it('admin can delete phoneShare', async () => {
    await assertSucceeds(deleteDoc(
      doc(admin().firestore(), 'bookings/b_accepted/phoneShares/customer1')));
  });
});

// ---------------------------------------------------------------------------
// REVIEWS
// ---------------------------------------------------------------------------

describe('reviews', () => {
  it('anonymous can read reviews', async () => {
    await assertSucceeds(getDoc(doc(anon().firestore(), 'reviews/r1')));
  });
  it('signed-in user can create valid review', async () => {
    await assertSucceeds(setDoc(doc(customer1().firestore(), 'reviews/r_new'),
      { reviewerId: 'customer1', bookingId: 'b1', rating: 5 }));
  });
  it('cannot create review with wrong reviewerId', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'reviews/r_bad'),
      { reviewerId: 'someone_else', bookingId: 'b1', rating: 5 }));
  });
  it('cannot create review with rating out of range', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'reviews/r_bad2'),
      { reviewerId: 'customer1', bookingId: 'b1', rating: 6 }));
  });
  it('cannot create review without bookingId', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'reviews/r_bad3'),
      { reviewerId: 'customer1', rating: 4 }));
  });
  it('anonymous cannot create review', async () => {
    await assertFails(setDoc(doc(anon().firestore(), 'reviews/r_anon'),
      { reviewerId: 'x', bookingId: 'b1', rating: 3 }));
  });
  it('admin can update review', async () => {
    await assertSucceeds(setDoc(doc(admin().firestore(), 'reviews/r1'),
      { reviewerId: 'customer1', bookingId: 'b1', rating: 3 }));
  });
  it('non-admin cannot update review', async () => {
    await assertFails(setDoc(doc(customer1().firestore(), 'reviews/r1'),
      { reviewerId: 'customer1', bookingId: 'b1', rating: 1 }));
  });
  it('admin can delete review', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'reviews/r_del'),
        { reviewerId: 'x', bookingId: 'b1', rating: 2 }));
    await assertSucceeds(deleteDoc(doc(admin().firestore(), 'reviews/r_del')));
  });
});

// ---------------------------------------------------------------------------
// REPORTS
// ---------------------------------------------------------------------------

describe('reports', () => {
  it('admin can read reports', async () => {
    await assertSucceeds(getDoc(doc(admin().firestore(), 'reports/rep1')));
  });
  it('moderator can read reports', async () => {
    await assertSucceeds(getDoc(doc(moderator().firestore(), 'reports/rep1')));
  });
  it('regular user cannot read reports', async () => {
    await assertFails(getDoc(doc(stranger().firestore(), 'reports/rep1')));
  });
  it('anonymous cannot read reports', async () => {
    await assertFails(getDoc(doc(anon().firestore(), 'reports/rep1')));
  });

  it('signed-in user can create a report', async () => {
    await assertSucceeds(setDoc(doc(stranger().firestore(), 'reports/rep_new'),
      { reporterId: 'stranger-uid', targetId: 'svc1', status: 'open' }));
  });
  it('anonymous cannot create a report', async () => {
    await assertFails(setDoc(doc(anon().firestore(), 'reports/rep_anon'),
      { reporterId: 'x', targetId: 'y', status: 'open' }));
  });

  it('admin can update report', async () => {
    await assertSucceeds(setDoc(doc(admin().firestore(), 'reports/rep1'),
      { status: 'resolved' }, { merge: true }));
  });
  it('moderator can update report', async () => {
    await assertSucceeds(setDoc(doc(moderator().firestore(), 'reports/rep1'),
      { status: 'open' }, { merge: true }));
  });
  it('regular user cannot update report', async () => {
    await assertFails(setDoc(doc(stranger().firestore(), 'reports/rep1'),
      { status: 'resolved' }, { merge: true }));
  });

  it('admin can delete report', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'reports/rep_del'), { status: 'open' }));
    await assertSucceeds(deleteDoc(doc(admin().firestore(), 'reports/rep_del')));
  });
  it('moderator cannot delete report', async () => {
    await assertFails(deleteDoc(doc(moderator().firestore(), 'reports/rep1')));
  });
});

// ---------------------------------------------------------------------------
// USER ROLES
// ---------------------------------------------------------------------------

describe('user_roles', () => {
  it('admin can read user_roles', async () => {
    await assertSucceeds(getDoc(doc(admin().firestore(), 'user_roles/admin-uid')));
  });
  it('moderator cannot read user_roles', async () => {
    await assertFails(getDoc(doc(moderator().firestore(), 'user_roles/admin-uid')));
  });
  it('regular user cannot read user_roles', async () => {
    await assertFails(getDoc(doc(stranger().firestore(), 'user_roles/admin-uid')));
  });
  it('anonymous cannot read user_roles', async () => {
    await assertFails(getDoc(doc(anon().firestore(), 'user_roles/admin-uid')));
  });
  it('nobody can write user_roles (even admin)', async () => {
    await assertFails(setDoc(doc(admin().firestore(), 'user_roles/x'),
      { uid: 'x', admin: true }));
  });
});

// ---------------------------------------------------------------------------
// ADMIN LOGS
// ---------------------------------------------------------------------------

describe('admin_logs', () => {
  it('admin can read admin_logs', async () => {
    await assertSucceeds(getDoc(doc(admin().firestore(), 'admin_logs/log1')));
  });
  it('moderator cannot read admin_logs', async () => {
    await assertFails(getDoc(doc(moderator().firestore(), 'admin_logs/log1')));
  });
  it('regular user cannot read admin_logs', async () => {
    await assertFails(getDoc(doc(stranger().firestore(), 'admin_logs/log1')));
  });
  it('nobody can write admin_logs (even admin)', async () => {
    await assertFails(setDoc(doc(admin().firestore(), 'admin_logs/log_fake'),
      { action: 'fake' }));
  });
});

// ---------------------------------------------------------------------------
// NOTIFICATIONS
// ---------------------------------------------------------------------------

describe('notifications', () => {
  it('owner can read own notification', async () => {
    await assertSucceeds(
      getDoc(doc(user_u1().firestore(), 'notifications/u1/items/n1')));
  });
  it('stranger cannot read another user notification', async () => {
    await assertFails(
      getDoc(doc(stranger().firestore(), 'notifications/u1/items/n1')));
  });
  it('admin can create notification', async () => {
    await assertSucceeds(setDoc(
      doc(admin().firestore(), 'notifications/u1/items/n_new'),
      { type: 'test', title: 'T', body: 'B', read: false }));
  });
  it('regular user cannot create notification', async () => {
    await assertFails(setDoc(
      doc(stranger().firestore(), 'notifications/u1/items/n_hack'),
      { type: 'test', title: 'T', body: 'B', read: false }));
  });
  it('owner can flip read field', async () => {
    await assertSucceeds(updateDoc(
      doc(user_u1().firestore(), 'notifications/u1/items/n1'),
      { read: true }));
  });
  it('owner cannot update other fields', async () => {
    await assertFails(updateDoc(
      doc(user_u1().firestore(), 'notifications/u1/items/n1'),
      { title: 'Modified' }));
  });
  it('owner can delete own notification', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'notifications/u1/items/n_del'),
        { type: 'x', read: false }));
    await assertSucceeds(
      deleteDoc(doc(user_u1().firestore(), 'notifications/u1/items/n_del')));
  });
  it('admin can delete any notification', async () => {
    await env.withSecurityRulesDisabled(async c =>
      setDoc(doc(c.firestore(), 'notifications/u1/items/n_adel'),
        { type: 'x', read: false }));
    await assertSucceeds(
      deleteDoc(doc(admin().firestore(), 'notifications/u1/items/n_adel')));
  });
  it('stranger cannot delete notification', async () => {
    await assertFails(
      deleteDoc(doc(stranger().firestore(), 'notifications/u1/items/n1')));
  });
});

// ---------------------------------------------------------------------------
// USER SESSIONS — direct reads
// ---------------------------------------------------------------------------

describe('user_sessions — direct reads', () => {
  it('admin can read session summary doc', async () => {
    await assertSucceeds(getDoc(doc(admin().firestore(), 'user_sessions/u1')));
  });
  it('admin can read session event doc', async () => {
    await assertSucceeds(
      getDoc(doc(admin().firestore(), 'user_sessions/u1/events/e1')));
  });
  it('moderator cannot read session docs', async () => {
    await assertFails(getDoc(doc(moderator().firestore(), 'user_sessions/u1')));
  });
  it('regular user cannot read session docs', async () => {
    await assertFails(getDoc(doc(stranger().firestore(), 'user_sessions/u1')));
  });
  it('anonymous cannot read session docs', async () => {
    await assertFails(getDoc(doc(anon().firestore(), 'user_sessions/u1')));
  });
  it('admin cannot write session docs from client', async () => {
    await assertFails(setDoc(doc(admin().firestore(), 'user_sessions/u1'),
      { uid: 'u1' }));
  });
  it('nobody can write session event docs from client', async () => {
    await assertFails(setDoc(
      doc(stranger().firestore(), 'user_sessions/u1/events/fake'),
      { uid: 'u1', loggedAt: Timestamp.now() }));
  });
});

// ---------------------------------------------------------------------------
// USER SESSIONS — collection group query
// ---------------------------------------------------------------------------

describe('user_sessions — collectionGroup(events)', () => {
  it('admin can query all events ordered by loggedAt', async () => {
    await assertSucceeds(getDocs(query(
      collectionGroup(admin().firestore(), 'events'),
      orderBy('loggedAt', 'desc'),
      limit(10),
    )));
  });
  it('admin can query events filtered by platform', async () => {
    await assertSucceeds(getDocs(query(
      collectionGroup(admin().firestore(), 'events'),
      where('platform', '==', 'android'),
      orderBy('loggedAt', 'desc'),
      limit(10),
    )));
  });
  it('moderator cannot query collectionGroup events', async () => {
    await assertFails(getDocs(query(
      collectionGroup(moderator().firestore(), 'events'),
      orderBy('loggedAt', 'desc'),
      limit(10),
    )));
  });
  it('regular user cannot query collectionGroup events', async () => {
    await assertFails(getDocs(query(
      collectionGroup(stranger().firestore(), 'events'),
      orderBy('loggedAt', 'desc'),
      limit(10),
    )));
  });
  it('anonymous cannot query collectionGroup events', async () => {
    await assertFails(getDocs(query(
      collectionGroup(anon().firestore(), 'events'),
      orderBy('loggedAt', 'desc'),
      limit(10),
    )));
  });
});

// ---------------------------------------------------------------------------
// DEFAULT DENY
// ---------------------------------------------------------------------------

describe('default deny', () => {
  it('admin cannot read from an unknown collection', async () => {
    await assertFails(getDoc(doc(admin().firestore(), 'unknown_collection/doc1')));
  });
  it('anonymous cannot read from an unknown collection', async () => {
    await assertFails(getDoc(doc(anon().firestore(), 'unknown_collection/doc1')));
  });
});
