// Notification triggers + push delivery side-effects. admin.messaging() is
// mocked (no network / no FCM) so we can assert recipient selection, in-app
// notification docs, dead-token purge, and reminder timezone formatting.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  clearFirestore,
  seedBooking,
  seedUser,
  getUser,
  getNotifications,
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

    // ~24h out, inside the 23.5-24.5h window.
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
});
