// Notification triggers + push delivery side-effects. admin.messaging() is
// mocked (no network / no FCM) so we can assert recipient selection, in-app
// notification docs, dead-token purge, and reminder timezone formatting.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma', storageBucket: 'demo-outalma.appspot.com' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import { createNotification, resolveDisplayName, titleWithSender } from '../src/notify';
import {
  clearFirestore,
  seedBooking,
  seedUser,
  getUser,
  getNotifications,
  seedNotification,
} from './helpers';

const customer = 'cust1';
const provider = 'prov1';

let sendSpy: jest.SpyInstance<any, any>;

function allSuccess(n: number) {
  return {
    successCount: n,
    failureCount: 0,
    responses: Array.from({ length: n }, () => ({ success: true })),
  };
}

beforeAll(() => {
  sendSpy = jest.spyOn(admin.messaging(), 'sendEachForMulticast');
});

beforeEach(async () => {
  await clearFirestore();
  sendSpy.mockReset();
  sendSpy.mockResolvedValue(allSuccess(1) as never);
});

afterAll(async () => {
  sendSpy.mockRestore();
  tf.cleanup();
  await admin.firestore().terminate();
});

function bookingSnapshot(data: Record<string, unknown>, id = 'b1') {
  return tf.firestore.makeDocumentSnapshot(data, `bookings/${id}`);
}

describe('onMessageCreate → notify the other participant', () => {
  async function seedChat(data: Record<string, unknown>) {
    await admin.firestore().collection('chats').doc('c1').set(data);
  }

  function fireMessage(message: Record<string, unknown>) {
    return tf.wrap(fns.onMessageCreate)({
      data: tf.firestore.makeDocumentSnapshot(message, 'chats/c1/messages/m1'),
      params: { chatId: 'c1', messageId: 'm1' },
      id: 'evt-msg-1',
    } as never);
  }

  it('pushes to the recipient (not the sender) with the chat deep-link + role', async () => {
    await seedChat({
      participantIds: [customer, provider],
      bookingId: 'b1',
      customerId: customer,
    });
    await seedUser(customer, { pushToken: 'tok-cust' });
    await seedUser(provider, { pushToken: 'tok-prov' });

    await fireMessage({ senderId: customer, text: 'Bonjour', type: 'text' });

    expect(sendSpy).toHaveBeenCalledTimes(1);
    const arg = sendSpy.mock.calls[0][0] as {
      tokens: string[];
      data?: { type?: string; chatId?: string };
    };
    expect(arg.tokens).toEqual(['tok-prov']); // recipient only, not the sender
    expect(arg.data?.type).toBe('new_message');
    expect(arg.data?.chatId).toBe('c1');

    const provNotifs = await getNotifications(provider);
    expect(provNotifs).toHaveLength(1);
    // The customer sent it → the recipient (provider) is notified in provider role.
    expect(provNotifs[0]?.audience).toBe('provider');
    expect(await getNotifications(customer)).toHaveLength(0);
  });

  // Hypothesis A (tmp/outalma-notif-tap/BRIEF.md): the push `data` payload
  // omits `audience`, while the in-app notification written right after gets
  // it. The client's activeModeForAudience(notificationAudienceFor(data))
  // (app_notification.dart) needs it from the PUSH payload at tap time - the
  // Firestore notification doc is a separate read the tap handler never
  // makes. Without it, a tap on a message meant for the other mode never
  // switches mode and can misroute.
  it('carries the same audience in the push payload as the in-app notification', async () => {
    await seedChat({
      participantIds: [customer, provider],
      bookingId: 'b1',
      customerId: customer,
    });
    await seedUser(customer, { pushToken: 'tok-cust' });
    await seedUser(provider, { pushToken: 'tok-prov' });

    await fireMessage({ senderId: customer, text: 'Bonjour', type: 'text' });

    const arg = sendSpy.mock.calls[0][0] as { data?: { audience?: string } };
    const provNotifs = await getNotifications(provider);
    // The push payload's audience must match what was just written to
    // Firestore for the same recipient/event.
    expect(arg.data?.audience).toBe(provNotifs[0]?.audience);
  });

  it('tags the message notification client when the recipient is the customer', async () => {
    await seedChat({
      participantIds: [customer, provider],
      customerId: customer,
    });
    await seedUser(customer, { pushToken: 'tok-cust' });
    // Provider sends → recipient is the customer → client role.
    await fireMessage({ senderId: provider, text: 'Réponse', type: 'text' });
    expect((await getNotifications(customer))[0]?.audience).toBe('client');
  });

  it('denormalizes the sender name into the notification, and drops the raw message text', async () => {
    await seedChat({
      participantIds: [customer, provider],
      bookingId: 'b1',
      customerId: customer,
    });
    await seedUser(customer, { pushToken: 'tok-cust', displayName: 'Fatou' });
    await seedUser(provider, { pushToken: 'tok-prov' });

    await fireMessage({ senderId: customer, text: 'texte du message', type: 'text' });

    const notif = (await getNotifications(provider))[0];
    // The name arrives in the document, denormalised at creation time.
    expect(notif?.senderId).toBe(customer);
    expect(notif?.senderName).toBe('Fatou');
    expect(notif?.title).toContain('Fatou');
    // And the raw message text must NOT arrive in it (lock-screen leak).
    expect(notif?.body).not.toContain('texte du message');
    expect(notif?.body).toBe('Vous avez reçu un nouveau message.');

    const pushArg = sendSpy.mock.calls[0][0] as { notification?: { title?: string; body?: string } };
    expect(pushArg.notification?.title).toContain('Fatou');
    expect(pushArg.notification?.body).not.toContain('texte du message');
  });

  it('falls back to the bare title when the sender has no resolvable name', async () => {
    await seedChat({ participantIds: [customer, provider], customerId: customer });
    // No seedUser for the sender at all: users/{customer} does not exist.
    await seedUser(provider, { pushToken: 'tok-prov' });

    await fireMessage({ senderId: customer, text: 'hi', type: 'text' });

    const notif = (await getNotifications(provider))[0];
    expect(notif?.senderId).toBe(customer);
    expect(notif?.senderName).toBeNull();
    expect(notif?.title).toBe('Nouveau message');
  });

  it('uses a media-aware body for an image message', async () => {
    await seedChat({ participantIds: [customer, provider] });
    await seedUser(provider, { pushToken: 'tok-prov' });

    await fireMessage({ senderId: customer, type: 'image', mediaUrl: 'x' });

    const imgNotif = (await getNotifications(provider))[0];
    expect(imgNotif?.body).toContain('image');
  });

  it('updates lastMessageAt on the chat', async () => {
    await seedChat({ participantIds: [customer, provider] });
    await seedUser(provider, { pushToken: 'tok-prov' });

    await fireMessage({ senderId: customer, text: 'hi', type: 'text' });

    const chat = await admin.firestore().collection('chats').doc('c1').get();
    expect(chat.data()?.lastMessageAt).toBeTruthy();
  });
});

describe('onBookingCreated → provider notification', () => {
  it('pushes and writes an in-app notification to the provider', async () => {
    await seedUser(provider, { pushToken: 'tok-prov' });
    const snap = bookingSnapshot({
      customerId: customer,
      providerId: provider,
      status: 'requested',
    });
    await tf.wrap(fns.onBookingCreated)({
      data: snap,
      params: { bookingId: 'b1' },
      id: 'evt-create-1',
    } as never);

    expect(sendSpy).toHaveBeenCalledTimes(1);
    const arg = sendSpy.mock.calls[0][0] as { tokens: string[] };
    expect(arg.tokens).toEqual(['tok-prov']);

    const notifs = await getNotifications(provider);
    expect(notifs).toHaveLength(1);
    expect(notifs[0]?.type).toBe('booking_requested');
    expect(notifs[0]?.audience).toBe('provider');
  });

  it('denormalizes the requesting customer name into the notification', async () => {
    await seedUser(provider, { pushToken: 'tok-prov' });
    await seedUser(customer, { displayName: 'Moussa' });
    const snap = bookingSnapshot({
      customerId: customer,
      providerId: provider,
      status: 'requested',
    });
    await tf.wrap(fns.onBookingCreated)({
      data: snap,
      params: { bookingId: 'b1' },
      id: 'evt-create-name-1',
    } as never);

    const notif = (await getNotifications(provider))[0];
    expect(notif?.senderId).toBe(customer);
    expect(notif?.senderName).toBe('Moussa');
    expect(notif?.title).toContain('Moussa');
  });
});

describe('onReviewCreated → notify the reviewee', () => {
  function reviewSnapshot(data: Record<string, unknown>, id = 'rev1') {
    return tf.firestore.makeDocumentSnapshot(data, `reviews/${id}`);
  }

  it('a client review notifies the provider (audience provider)', async () => {
    await seedUser(provider, { pushToken: 'tok-prov' });
    const snap = reviewSnapshot({
      revieweeId: provider,
      reviewerId: customer,
      reviewerRole: 'client',
      bookingId: 'b1',
      rating: 5,
    });
    await tf.wrap(fns.onReviewCreated)({
      data: snap,
      params: { reviewId: `b1_${customer}` },
      id: 'evt-rev-1',
    } as never);

    expect(sendSpy).toHaveBeenCalledTimes(1);
    const notifs = await getNotifications(provider);
    expect(notifs).toHaveLength(1);
    expect(notifs[0]?.type).toBe('review_received');
    expect(notifs[0]?.audience).toBe('provider');
    expect(notifs[0]?.bookingId).toBe('b1');
  });

  it('a provider review notifies the client (audience client)', async () => {
    await seedUser(customer, { pushToken: 'tok-cust' });
    const snap = reviewSnapshot({
      revieweeId: customer,
      reviewerId: provider,
      reviewerRole: 'provider',
      bookingId: 'b1',
    });
    await tf.wrap(fns.onReviewCreated)({
      data: snap,
      params: { reviewId: `b1_${provider}` },
      id: 'evt-rev-2',
    } as never);

    const notifs = await getNotifications(customer);
    expect(notifs).toHaveLength(1);
    expect(notifs[0]?.audience).toBe('client');
  });

  it('denormalizes the reviewer name into the notification', async () => {
    await seedUser(provider, { pushToken: 'tok-prov' });
    await seedUser(customer, { displayName: 'Khady' });
    const snap = reviewSnapshot({
      revieweeId: provider,
      reviewerId: customer,
      reviewerRole: 'client',
      bookingId: 'b1',
      rating: 5,
    });
    await tf.wrap(fns.onReviewCreated)({
      data: snap,
      params: { reviewId: `b1_${customer}` },
      id: 'evt-rev-name-1',
    } as never);

    const notif = (await getNotifications(provider))[0];
    expect(notif?.senderId).toBe(customer);
    expect(notif?.senderName).toBe('Khady');
    expect(notif?.title).toContain('Khady');
  });
});

// The public read rule on `reviews` is `resource.data.hidden == false`. A
// document that LACKS the field cannot satisfy it and cannot be matched by the
// visitor query either, so a review written by a build older than the
// serializer change would be invisible to every visitor, for ever. The current
// client writes the field; this trigger is the net under the clients already
// installed on real phones.
describe('onReviewCreated normalises the hidden field', () => {
  const db = () => admin.firestore();

  async function fire(id: string, data: Record<string, unknown>) {
    await db().collection('reviews').doc(id).set(data);
    const snap = await db().collection('reviews').doc(id).get();
    await tf.wrap(fns.onReviewCreated)({
      data: tf.firestore.makeDocumentSnapshot(
        snap.data() as Record<string, unknown>,
        `reviews/${id}`
      ),
      params: { reviewId: id },
      id: `evt-hidden-${id}`,
    } as never);
    return (await db().collection('reviews').doc(id).get()).data();
  }

  const base = {
    revieweeId: provider,
    reviewerId: customer,
    reviewerRole: 'client',
    bookingId: 'b1',
    rating: 5,
  };

  it('adds hidden false when the field is ABSENT', async () => {
    const after = await fire('rev-absent', base);
    expect(after?.hidden).toBe(false);
  });

  it('leaves an explicit hidden false alone', async () => {
    const after = await fire('rev-false', { ...base, hidden: false });
    expect(after?.hidden).toBe(false);
  });

  it('NEVER unhides a review that is already hidden', async () => {
    // The one way this net could do damage: a moderated review is hidden:true,
    // and a trigger replay must not reset it to false. It writes only when the
    // field is absent, which is what makes a replay harmless.
    const after = await fire('rev-true', { ...base, hidden: true });
    expect(after?.hidden).toBe(true);
  });

  it('is idempotent across a replay', async () => {
    await fire('rev-replay', base);
    // Second pass over the SAME document, now carrying the field.
    const snap = await db().collection('reviews').doc('rev-replay').get();
    await tf.wrap(fns.onReviewCreated)({
      data: tf.firestore.makeDocumentSnapshot(
        snap.data() as Record<string, unknown>,
        'reviews/rev-replay'
      ),
      params: { reviewId: 'rev-replay' },
      id: 'evt-hidden-replay-2',
    } as never);
    const after = (await db().collection('reviews').doc('rev-replay').get()).data();
    expect(after?.hidden).toBe(false);
  });
});

describe('onBookingStatusChange → recipient selection', () => {
  function runChange(
    before: Record<string, unknown>,
    after: Record<string, unknown>
  ) {
    const change = tf.makeChange(
      bookingSnapshot(before),
      bookingSnapshot(after)
    );
    return tf.wrap(fns.onBookingStatusChange)({
      data: change,
      params: { bookingId: 'b1' },
      id: 'evt-status-1',
    } as never);
  }

  it('notifies only the customer on accept', async () => {
    await seedUser(customer, { pushToken: 'tok-cust' });
    await seedUser(provider, { pushToken: 'tok-prov' });
    await runChange(
      { status: 'requested', customerId: customer, providerId: provider },
      { status: 'accepted', customerId: customer, providerId: provider }
    );
    const cust = await getNotifications(customer);
    expect(cust).toHaveLength(1);
    expect(cust[0]?.audience).toBe('client'); // recipient acts as client
    expect(await getNotifications(provider)).toHaveLength(0);
  });

  it('notifies both parties on done, each in their own role', async () => {
    await seedUser(customer, { pushToken: 'tok-cust' });
    await seedUser(provider, { pushToken: 'tok-prov' });
    await runChange(
      { status: 'in_progress', customerId: customer, providerId: provider },
      { status: 'done', customerId: customer, providerId: provider }
    );
    expect((await getNotifications(customer))[0]?.audience).toBe('client');
    expect((await getNotifications(provider))[0]?.audience).toBe('provider');
  });

  it('denormalizes the other party name into each side of the accept/done notifications', async () => {
    await seedUser(customer, { pushToken: 'tok-cust', displayName: 'Astou' });
    await seedUser(provider, { pushToken: 'tok-prov', displayName: 'Ibrahima' });

    await runChange(
      { status: 'requested', customerId: customer, providerId: provider },
      { status: 'accepted', customerId: customer, providerId: provider }
    );
    const accepted = (await getNotifications(customer))[0];
    // The customer is told the PROVIDER accepted: the provider's name.
    expect(accepted?.senderId).toBe(provider);
    expect(accepted?.senderName).toBe('Ibrahima');
    expect(accepted?.title).toContain('Ibrahima');

    await runChange(
      { status: 'in_progress', customerId: customer, providerId: provider },
      { status: 'done', customerId: customer, providerId: provider }
    );
    const custDone = (await getNotifications(customer)).find(
      (n) => n?.type === 'booking_done'
    );
    const provDone = (await getNotifications(provider)).find(
      (n) => n?.type === 'booking_done'
    );
    // Each side sees the OTHER party's name.
    expect(custDone?.senderName).toBe('Ibrahima');
    expect(provDone?.senderName).toBe('Astou');
  });

  it('on cancel, notifies the party who did NOT cancel', async () => {
    await seedUser(customer, { pushToken: 'tok-cust' });
    await seedUser(provider, { pushToken: 'tok-prov' });
    // customer cancels → only provider is told
    await runChange(
      { status: 'accepted', customerId: customer, providerId: provider },
      {
        status: 'cancelled',
        customerId: customer,
        providerId: provider,
        cancelledBy: customer,
      }
    );
    const provNotifs = await getNotifications(provider);
    const custNotifs = await getNotifications(customer);
    expect(provNotifs).toHaveLength(1);
    expect(provNotifs[0]?.type).toBe('booking_cancelled');
    expect(provNotifs[0]?.audience).toBe('provider'); // notified in provider role
    expect(custNotifs).toHaveLength(0);
  });
});

describe('sendPushToUsers → dead-token purge', () => {
  it('deletes a token FCM reports as unregistered', async () => {
    await seedUser(provider, { pushToken: 'dead-token' });
    sendSpy.mockResolvedValue({
      successCount: 0,
      failureCount: 1,
      responses: [
        {
          success: false,
          error: { code: 'messaging/registration-token-not-registered' },
        },
      ],
    } as never);

    await tf.wrap(fns.onBookingCreated)({
      data: bookingSnapshot({
        customerId: customer,
        providerId: provider,
        status: 'requested',
      }),
      params: { bookingId: 'b1' },
      id: 'evt-purge-1',
    } as never);

    const user = await getUser(provider);
    expect(user?.pushToken).toBeUndefined();
  });

  it('keeps a token when delivery succeeds', async () => {
    await seedUser(provider, { pushToken: 'good-token' });
    await tf.wrap(fns.onBookingCreated)({
      data: bookingSnapshot({
        customerId: customer,
        providerId: provider,
        status: 'requested',
      }),
      params: { bookingId: 'b1' },
      id: 'evt-keep-1',
    } as never);

    const user = await getUser(provider);
    expect(user?.pushToken).toBe('good-token');
  });
});

describe('sendBookingReminders → timezone-correct 24h reminder', () => {
  it('formats the time in the customer country timezone (FR=Europe/Paris)', async () => {
    await seedUser(customer, { pushToken: 'tok-cust', country: 'FR' });
    await seedUser(provider, { pushToken: 'tok-prov', country: 'FR' });

    // ~24h out, inside the 23.5 to 24.5h window.
    const scheduled = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await seedBooking('b1', {
      customerId: customer,
      providerId: provider,
      status: 'accepted',
    });
    await admin
      .firestore()
      .collection('bookings')
      .doc('b1')
      .update({ scheduledAt: admin.firestore.Timestamp.fromDate(scheduled) });

    // Cast: the scheduled-function type doesn't match wrap's v2 CloudEvent
    // overload, but it runs fine. The scheduled wrapper takes no event arg.
    await (tf.wrap(fns.sendBookingReminders as never) as () => Promise<void>)();

    const expectedParis = scheduled.toLocaleTimeString('fr-FR', {
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'Europe/Paris',
    });
    const custNotifs = await getNotifications(customer);
    const reminder = custNotifs.find((n) => n?.type === 'booking_reminder');
    expect(reminder).toBeDefined();
    expect(reminder?.body).toContain(expectedParis);
    // And it must NOT be the (wrong) UTC time when they differ.
    const utc = scheduled.toLocaleTimeString('fr-FR', {
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'UTC',
    });
    if (utc !== expectedParis) {
      expect(reminder?.body).not.toContain(utc);
    }
  });

  it('denormalizes the OTHER party name into each side of a 24h reminder', async () => {
    await seedUser(customer, { pushToken: 'tok-cust', country: 'FR', displayName: 'Ndeye' });
    await seedUser(provider, { pushToken: 'tok-prov', country: 'FR', displayName: 'Modou' });

    const scheduled = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await seedBooking('b1', {
      customerId: customer,
      providerId: provider,
      status: 'accepted',
    });
    await admin
      .firestore()
      .collection('bookings')
      .doc('b1')
      .update({ scheduledAt: admin.firestore.Timestamp.fromDate(scheduled) });

    await (tf.wrap(fns.sendBookingReminders as never) as () => Promise<void>)();

    const custReminder = (await getNotifications(customer)).find(
      (n) => n?.type === 'booking_reminder'
    );
    const provReminder = (await getNotifications(provider)).find(
      (n) => n?.type === 'booking_reminder'
    );
    // The customer's reminder names the provider, and vice versa.
    expect(custReminder?.senderId).toBe(provider);
    expect(custReminder?.senderName).toBe('Modou');
    expect(custReminder?.title).toContain('Modou');
    expect(provReminder?.senderId).toBe(customer);
    expect(provReminder?.senderName).toBe('Ndeye');
    expect(provReminder?.title).toContain('Ndeye');
  });
});

// ---------------------------------------------------------------------------
// Notification cascade: deleting a booking or a chat must not leave a
// notification pointing at it. 475 production notifications were audited: 85
// pointed at a bookingId that no longer existed, 50 at a chatId that no
// longer existed. onBookingDeleted and onChatDeleted close that hole.
// ---------------------------------------------------------------------------
describe('onBookingDeleted → notification cascade', () => {
  it('deletes every notification (any recipient) referencing the deleted booking', async () => {
    await seedNotification(customer, 'n1', { type: 'booking_accepted', bookingId: 'b1' });
    await seedNotification(provider, 'n2', { type: 'booking_requested', bookingId: 'b1' });
    // A different booking's notification must survive.
    await seedNotification(customer, 'n3', { type: 'booking_accepted', bookingId: 'b2' });

    await tf.wrap(fns.onBookingDeleted)({
      data: bookingSnapshot({ status: 'cancelled' }, 'b1'),
      params: { bookingId: 'b1' },
      id: 'evt-cascade-1',
    } as never);

    const custNotifs = await getNotifications(customer);
    const provNotifs = await getNotifications(provider);
    expect(custNotifs.some((n) => n?.bookingId === 'b1')).toBe(false);
    expect(provNotifs.some((n) => n?.bookingId === 'b1')).toBe(false);
    // The other booking's notification is untouched.
    expect(custNotifs.some((n) => n?.bookingId === 'b2')).toBe(true);
  });

  it('is idempotent: replaying the delete event finds nothing left and does not throw', async () => {
    await seedNotification(customer, 'n1', { type: 'booking_accepted', bookingId: 'b1' });
    const event = {
      data: bookingSnapshot({ status: 'cancelled' }, 'b1'),
      params: { bookingId: 'b1' },
      id: 'evt-cascade-idem',
    } as never;

    await tf.wrap(fns.onBookingDeleted)(event);
    await expect(tf.wrap(fns.onBookingDeleted)(event)).resolves.not.toThrow();

    expect(await getNotifications(customer)).toHaveLength(0);
  });

  it('does nothing (no throw) when no notification references the booking', async () => {
    await expect(
      tf.wrap(fns.onBookingDeleted)({
        data: bookingSnapshot({ status: 'requested' }, 'b-none'),
        params: { bookingId: 'b-none' },
        id: 'evt-cascade-none',
      } as never)
    ).resolves.not.toThrow();
  });
});

describe('onChatDeleted → notification cascade', () => {
  function chatSnapshot(data: Record<string, unknown>, id = 'c1') {
    return tf.firestore.makeDocumentSnapshot(data, `chats/${id}`);
  }

  it('deletes every notification (any recipient) referencing the deleted chat', async () => {
    await seedNotification(customer, 'n1', { type: 'new_message', chatId: 'c1' });
    await seedNotification(provider, 'n2', { type: 'new_message', chatId: 'c1' });
    await seedNotification(customer, 'n3', { type: 'new_message', chatId: 'c2' });

    await tf.wrap(fns.onChatDeleted)({
      data: chatSnapshot({ participantIds: [customer, provider] }, 'c1'),
      params: { chatId: 'c1' },
      id: 'evt-chat-cascade-1',
    } as never);

    const custNotifs = await getNotifications(customer);
    const provNotifs = await getNotifications(provider);
    expect(custNotifs.some((n) => n?.chatId === 'c1')).toBe(false);
    expect(provNotifs.some((n) => n?.chatId === 'c1')).toBe(false);
    expect(custNotifs.some((n) => n?.chatId === 'c2')).toBe(true);
  });

  it('is idempotent: replaying the delete event finds nothing left and does not throw', async () => {
    await seedNotification(customer, 'n1', { type: 'new_message', chatId: 'c1' });
    const event = {
      data: chatSnapshot({ participantIds: [customer, provider] }, 'c1'),
      params: { chatId: 'c1' },
      id: 'evt-chat-cascade-idem',
    } as never;

    await tf.wrap(fns.onChatDeleted)(event);
    await expect(tf.wrap(fns.onChatDeleted)(event)).resolves.not.toThrow();

    expect(await getNotifications(customer)).toHaveLength(0);
  });
});

describe('titleWithSender / resolveDisplayName → the fallback guards', () => {
  // These are what keep the 391 pre-migration notifications, and any future
  // caller that cannot resolve a name, from ever showing a literal "null" or
  // a dangling separator instead of the bare original title.
  it('titleWithSender leaves the base title untouched when the name is null', () => {
    expect(titleWithSender('Demande acceptée', null)).toBe('Demande acceptée');
  });

  it('titleWithSender appends the name when known', () => {
    expect(titleWithSender('Demande acceptée', 'Awa')).toBe('Demande acceptée · Awa');
  });

  it('resolveDisplayName resolves null for an undefined uid, without touching Firestore', async () => {
    await expect(resolveDisplayName(undefined)).resolves.toBeNull();
  });

  it('resolveDisplayName resolves null for a uid with no user document', async () => {
    await expect(resolveDisplayName('no-such-user')).resolves.toBeNull();
  });

  it('resolveDisplayName resolves null for a user document with a blank displayName', async () => {
    await seedUser('blank-name-user', { displayName: '   ' });
    await expect(resolveDisplayName('blank-name-user')).resolves.toBeNull();
  });

  it('resolveDisplayName resolves the real name when present', async () => {
    await seedUser('named-user', { displayName: 'Ousmane' });
    await expect(resolveDisplayName('named-user')).resolves.toBe('Ousmane');
  });
});

describe('createNotification → audience guard', () => {
  // 344 of the 391 notifications in production predate `audience` (2026-09
  // audit) precisely because the field used to be optional: this guard is
  // what stops the stock from growing again. Every real call site already
  // passes a valid audience (see the other describe blocks in this file); this
  // block exercises the guard itself, in isolation, the way none of them do.
  const base = { type: 'new_message', title: 't', body: 'b' };

  // Matched against createNotification's own error message, not just "rejects
  // with something": Firestore's admin SDK independently refuses an
  // `undefined` field value, so a looser `.rejects.toThrow()` on the
  // "no audience at all" case would pass even with the guard deleted, and
  // mutation testing caught exactly that on the first draft of this test.
  const guardMessage = /createNotification: missing\/invalid audience/;

  it('rejects a creation with no audience at all, and writes nothing', async () => {
    await expect(
      createNotification(customer, { ...base } as never)
    ).rejects.toThrow(guardMessage);
    expect(await getNotifications(customer)).toHaveLength(0);
  });

  it('rejects a creation with an audience outside client/provider, and writes nothing', async () => {
    await expect(
      createNotification(customer, { ...base, audience: 'both' } as never)
    ).rejects.toThrow(guardMessage);
    expect(await getNotifications(customer)).toHaveLength(0);
  });

  it('accepts a valid audience and writes it through unchanged', async () => {
    await createNotification(customer, { ...base, audience: 'client' });
    const notifs = await getNotifications(customer);
    expect(notifs).toHaveLength(1);
    expect(notifs[0]?.audience).toBe('client');
  });
});
