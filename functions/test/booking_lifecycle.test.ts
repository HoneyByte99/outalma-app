// Booking state machine — server-authoritative transitions (the core the whole
// product trusts). Runs against the Firestore emulator via `npm test`.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

// Importing index initializes the default admin app (pointed at the emulator
// because emulators:exec sets FIRESTORE_EMULATOR_HOST). Import it BEFORE any
// admin.firestore() call.
import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  clearFirestore,
  seedService,
  seedService_raw,
  seedProvider,
  seedBooking,
  getBooking,
  chatExists,
} from './helpers';

const customer = 'cust1';
const provider = 'prov1';
const stranger = 'other9';

type Auth = { uid: string; token?: Record<string, unknown> };

function call(fn: unknown, data: unknown, auth?: Auth): Promise<unknown> {
  const wrapped = tf.wrap(fn as never);
  return wrapped({ data, auth } as never);
}

/// Asserts the call rejects with an HttpsError whose code contains `code`.
async function expectReject(p: Promise<unknown>, code: string): Promise<void> {
  await expect(p).rejects.toMatchObject({ code: expect.stringContaining(code) });
}

beforeEach(async () => {
  await clearFirestore();
});

afterAll(async () => {
  tf.cleanup();
  // Close the Firestore client so Jest doesn't warn about open handles.
  await admin.firestore().terminate();
});

describe('createBooking', () => {
  beforeEach(async () => {
    await seedService('svc1', { providerId: provider });
    await seedProvider(provider);
  });

  const validData = {
    providerId: provider,
    serviceId: 'svc1',
    requestMessage: 'I need a plumber',
  };

  it('rejects an unauthenticated caller', async () => {
    await expectReject(call(fns.createBooking, validData), 'unauthenticated');
  });

  it('rejects a missing requestMessage', async () => {
    await expectReject(
      call(
        fns.createBooking,
        { providerId: provider, serviceId: 'svc1' },
        { uid: customer }
      ),
      'invalid-argument'
    );
  });

  it('rejects an unknown service', async () => {
    await expectReject(
      call(
        fns.createBooking,
        { ...validData, serviceId: 'ghost' },
        { uid: customer }
      ),
      'not-found'
    );
  });

  it('rejects a service that belongs to a different provider', async () => {
    await seedService('svc2', { providerId: 'someoneElse' });
    await expectReject(
      call(
        fns.createBooking,
        { ...validData, serviceId: 'svc2' },
        { uid: customer }
      ),
      'failed-precondition'
    );
  });

  it('rejects an unpublished service', async () => {
    await seedService('draft', { providerId: provider, published: false });
    await expectReject(
      call(
        fns.createBooking,
        { ...validData, serviceId: 'draft' },
        { uid: customer }
      ),
      'failed-precondition'
    );
  });

  it('rejects when the provider is suspended', async () => {
    await seedProvider(provider, { suspended: true });
    await expectReject(
      call(fns.createBooking, validData, { uid: customer }),
      'failed-precondition'
    );
  });

  it('rejects when the provider is paused (active=false)', async () => {
    await seedProvider(provider, { active: false });
    await expectReject(
      call(fns.createBooking, validData, { uid: customer }),
      'failed-precondition'
    );
  });

  it('rejects when the customer has blocked the provider', async () => {
    await admin
      .firestore()
      .doc(`users/${customer}/blockedUsers/${provider}`)
      .set({ at: admin.firestore.FieldValue.serverTimestamp() });
    await expectReject(
      call(fns.createBooking, validData, { uid: customer }),
      'failed-precondition'
    );
  });

  it('rejects when the provider has blocked the customer', async () => {
    await admin
      .firestore()
      .doc(`users/${provider}/blockedUsers/${customer}`)
      .set({ at: admin.firestore.FieldValue.serverTimestamp() });
    await expectReject(
      call(fns.createBooking, validData, { uid: customer }),
      'failed-precondition'
    );
  });

  it('rejects a booking whose address is outside the service zones', async () => {
    await seedService_raw('svcZone', {
      providerId: provider,
      published: true,
      serviceZones: [{ label: 'Dakar', lat: 14.69, lng: -17.44, radiusKm: 10 }],
    });
    await expectReject(
      call(
        fns.createBooking,
        {
          providerId: provider,
          serviceId: 'svcZone',
          requestMessage: 'hi',
          addressSnapshot: { address: 'Paris', lat: 48.85, lng: 2.35 },
        },
        { uid: customer }
      ),
      'failed-precondition'
    );
  });

  it('accepts a booking whose address is inside a service zone', async () => {
    await seedService_raw('svcZone', {
      providerId: provider,
      published: true,
      serviceZones: [{ label: 'Dakar', lat: 14.69, lng: -17.44, radiusKm: 10 }],
    });
    const res = (await call(
      fns.createBooking,
      {
        providerId: provider,
        serviceId: 'svcZone',
        requestMessage: 'hi',
        addressSnapshot: { address: 'Dakar centre', lat: 14.70, lng: -17.45 },
      },
      { uid: customer }
    )) as { bookingId: string };
    expect(res.bookingId).toBeTruthy();
  });

  it('allows a zoned service when the address has no coordinates', async () => {
    await seedService_raw('svcZone', {
      providerId: provider,
      published: true,
      serviceZones: [{ label: 'Dakar', lat: 14.69, lng: -17.44, radiusKm: 10 }],
    });
    const res = (await call(
      fns.createBooking,
      {
        providerId: provider,
        serviceId: 'svcZone',
        requestMessage: 'hi',
        addressSnapshot: { address: 'no coords' },
      },
      { uid: customer }
    )) as { bookingId: string };
    expect(res.bookingId).toBeTruthy();
  });

  it('rejects a booking conflicting (±60min) with an existing one', async () => {
    const when = new Date(Date.now() + 7 * 24 * 3600 * 1000);
    await admin
      .firestore()
      .collection('bookings')
      .doc('existing')
      .set({
        customerId: 'other',
        providerId: provider,
        serviceId: 'svc1',
        status: 'accepted',
        requestMessage: 'x',
        scheduledAt: admin.firestore.Timestamp.fromDate(when),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    await expectReject(
      call(
        fns.createBooking,
        { ...validData, scheduledAt: when.toISOString() },
        { uid: customer }
      ),
      'failed-precondition'
    );
  });

  it('allows a booking 3h away from an existing one', async () => {
    const when = new Date(Date.now() + 7 * 24 * 3600 * 1000);
    const later = new Date(when.getTime() + 3 * 3600 * 1000);
    await admin
      .firestore()
      .collection('bookings')
      .doc('existing')
      .set({
        customerId: 'other',
        providerId: provider,
        serviceId: 'svc1',
        status: 'accepted',
        requestMessage: 'x',
        scheduledAt: admin.firestore.Timestamp.fromDate(when),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    const res = (await call(
      fns.createBooking,
      { ...validData, scheduledAt: later.toISOString() },
      { uid: customer }
    )) as { bookingId: string };
    expect(res.bookingId).toBeTruthy();
  });

  it('creates a booking with status=requested on the happy path', async () => {
    const res = (await call(fns.createBooking, validData, {
      uid: customer,
    })) as { bookingId: string };
    expect(res.bookingId).toBeTruthy();
    const booking = await getBooking(res.bookingId);
    expect(booking?.status).toBe('requested');
    expect(booking?.customerId).toBe(customer);
    expect(booking?.providerId).toBe(provider);
  });
});

describe('acceptBooking', () => {
  beforeEach(async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'requested' });
  });

  it('lets only the provider accept', async () => {
    await expectReject(
      call(fns.acceptBooking, { bookingId: 'b1' }, { uid: customer }),
      'permission-denied'
    );
  });

  it('accepts, creates the chat and sets chatId + acceptedAt', async () => {
    const res = (await call(fns.acceptBooking, { bookingId: 'b1' }, {
      uid: provider,
    })) as { chatId: string };
    const booking = await getBooking('b1');
    expect(booking?.status).toBe('accepted');
    expect(booking?.chatId).toBe(res.chatId);
    expect(booking?.acceptedAt).toBeTruthy();
    expect(await chatExists(res.chatId)).toBe(true);
  });

  it('refuses to accept a booking that is not requested', async () => {
    await seedBooking('b2', { customerId: customer, providerId: provider, status: 'accepted' });
    await expectReject(
      call(fns.acceptBooking, { bookingId: 'b2' }, { uid: provider }),
      'failed-precondition'
    );
  });
});

describe('rejectBooking', () => {
  beforeEach(async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'requested' });
  });

  it('rejects without creating a chat', async () => {
    await call(fns.rejectBooking, { bookingId: 'b1' }, { uid: provider });
    const booking = await getBooking('b1');
    expect(booking?.status).toBe('rejected');
    // chatIdForBooking is deterministic; the chat must NOT exist after a reject.
    expect(await chatExists('chat_b1')).toBe(false);
  });

  it('lets only the provider reject', async () => {
    await expectReject(
      call(fns.rejectBooking, { bookingId: 'b1' }, { uid: customer }),
      'permission-denied'
    );
  });
});

describe('cancelBooking', () => {
  it('lets a participant cancel a requested booking and records cancelledBy', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'requested' });
    await call(fns.cancelBooking, { bookingId: 'b1' }, { uid: customer });
    const booking = await getBooking('b1');
    expect(booking?.status).toBe('cancelled');
    expect(booking?.cancelledBy).toBe(customer);
  });

  it('stores an optional cancel reason', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'accepted' });
    await call(
      fns.cancelBooking,
      { bookingId: 'b1', reason: 'Client unavailable' },
      { uid: provider }
    );
    const booking = await getBooking('b1');
    expect(booking?.cancelReason).toBe('Client unavailable');
  });

  it('refuses to cancel a terminal (done) booking', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'done' });
    await expectReject(
      call(fns.cancelBooking, { bookingId: 'b1' }, { uid: customer }),
      'failed-precondition'
    );
  });

  it('refuses a non-participant', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'requested' });
    await expectReject(
      call(fns.cancelBooking, { bookingId: 'b1' }, { uid: stranger }),
      'permission-denied'
    );
  });
});

describe('markInProgress', () => {
  it('lets the provider move an accepted booking to in_progress', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'accepted' });
    await call(fns.markInProgress, { bookingId: 'b1' }, { uid: provider });
    expect((await getBooking('b1'))?.status).toBe('in_progress');
  });

  it('requires status=accepted', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'requested' });
    await expectReject(
      call(fns.markInProgress, { bookingId: 'b1' }, { uid: provider }),
      'failed-precondition'
    );
  });

  it('lets only the provider mark in progress', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'accepted' });
    await expectReject(
      call(fns.markInProgress, { bookingId: 'b1' }, { uid: customer }),
      'permission-denied'
    );
  });
});

describe('confirmDone', () => {
  it('lets the client confirm an in_progress booking as done', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'in_progress' });
    await call(fns.confirmDone, { bookingId: 'b1' }, { uid: customer });
    expect((await getBooking('b1'))?.status).toBe('done');
  });

  it('lets only the client confirm done (not the provider)', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'in_progress' });
    await expectReject(
      call(fns.confirmDone, { bookingId: 'b1' }, { uid: provider }),
      'permission-denied'
    );
  });

  it('requires status=in_progress', async () => {
    await seedBooking('b1', { customerId: customer, providerId: provider, status: 'accepted' });
    await expectReject(
      call(fns.confirmDone, { bookingId: 'b1' }, { uid: customer }),
      'failed-precondition'
    );
  });
});
