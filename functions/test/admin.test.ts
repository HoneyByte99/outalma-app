// RGPD (export / account deletion) + admin-moderation callables. Auth emulator
// is required (custom claims, getUser, deleteUser).
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  clearFirestore,
  seedUser,
  seedService_raw,
  seedReview,
  seedMessage,
  userExists,
  serviceExists,
  getService,
  getProvider,
  getMessage,
  getNotifications,
  createAuthUser,
  authUserExists,
} from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };

function call(fn: unknown, data: unknown, auth?: Auth): Promise<unknown> {
  const wrapped = tf.wrap(fn as never);
  return wrapped({ data, auth } as never);
}

async function expectReject(p: Promise<unknown>, code: string): Promise<void> {
  await expect(p).rejects.toMatchObject({ code: expect.stringContaining(code) });
}

beforeEach(async () => {
  await clearFirestore();
});

afterAll(async () => {
  tf.cleanup();
  await admin.firestore().terminate();
});

describe('exportMyData', () => {
  it('rejects an unauthenticated caller', async () => {
    await expectReject(call(fns.exportMyData, {}), 'unauthenticated');
  });

  it('returns the caller personal data bundle', async () => {
    await seedUser('u1', { email: 'u1@test.dev' });
    await seedService_raw('s1', { providerId: 'u1', published: true });
    await seedReview('r1', { reviewerId: 'u1', revieweeId: 'other' });

    const res = (await call(fns.exportMyData, {}, { uid: 'u1' })) as {
      user: { id: string } | null;
      services: unknown[];
      reviewsWritten: unknown[];
      exportedAt: string;
    };
    expect(res.user?.id).toBe('u1');
    expect(res.services).toHaveLength(1);
    expect(res.reviewsWritten).toHaveLength(1);
    expect(res.exportedAt).toBeTruthy();
  });
});

describe('requestDataExport', () => {
  it('rejects an unauthenticated caller', async () => {
    await expectReject(call(fns.requestDataExport, {}), 'unauthenticated');
  });

  it('files a pending request using the account email', async () => {
    await createAuthUser('u1'); // email = u1@test.dev
    const res = (await call(fns.requestDataExport, {}, { uid: 'u1' })) as {
      requestId: string;
      status: string;
    };
    expect(res.status).toBe('pending');
    const doc = await admin
      .firestore()
      .collection('data_export_requests')
      .doc(res.requestId)
      .get();
    expect(doc.data()?.userId).toBe('u1');
    expect(doc.data()?.email).toBe('u1@test.dev');
    expect(doc.data()?.status).toBe('pending');
  });

  it('accepts an explicit destination email (phone-only users)', async () => {
    await createAuthUser('u2');
    const res = (await call(
      fns.requestDataExport,
      { email: 'me@example.com' },
      { uid: 'u2' }
    )) as { requestId: string };
    const doc = await admin
      .firestore()
      .collection('data_export_requests')
      .doc(res.requestId)
      .get();
    expect(doc.data()?.email).toBe('me@example.com');
  });

  it('rejects an invalid email', async () => {
    await createAuthUser('u3');
    await expectReject(
      call(fns.requestDataExport, { email: 'not-an-email' }, { uid: 'u3' }),
      'invalid-argument'
    );
  });
});

describe('deleteMyAccount', () => {
  it('deletes the user doc, owned services, provider doc and auth account', async () => {
    await createAuthUser('u1');
    await seedUser('u1');
    await admin.firestore().collection('providers').doc('u1').set({ uid: 'u1' });
    await seedService_raw('s1', { providerId: 'u1' });
    await seedService_raw('s2', { providerId: 'u1' });

    const res = (await call(fns.deleteMyAccount, {}, { uid: 'u1' })) as {
      deleted: boolean;
    };
    expect(res.deleted).toBe(true);
    expect(await userExists('u1')).toBe(false);
    expect(await serviceExists('s1')).toBe(false);
    expect(await serviceExists('s2')).toBe(false);
    expect(await authUserExists('u1')).toBe(false);
  });
});

describe('setAdminClaim', () => {
  it('rejects a non-admin caller', async () => {
    await expectReject(
      call(fns.setAdminClaim, { uid: 'target', admin: true }, { uid: 'nobody' }),
      'permission-denied'
    );
  });

  it('lets an admin grant the admin claim and mirrors it to user_roles', async () => {
    await createAuthUser('target');
    const res = (await call(
      fns.setAdminClaim,
      { uid: 'target', admin: true },
      { uid: 'boss', token: { admin: true } }
    )) as { admin: boolean };
    expect(res.admin).toBe(true);

    const user = await admin.auth().getUser('target');
    expect(user.customClaims?.admin).toBe(true);

    const role = await admin
      .firestore()
      .collection('user_roles')
      .doc('target')
      .get();
    expect(role.data()?.admin).toBe(true);
  });
});

describe('suspendProvider / unsuspendProvider', () => {
  it('admin suspends a provider and unpublishes their services', async () => {
    await admin
      .firestore()
      .collection('providers')
      .doc('p1')
      .set({ uid: 'p1', suspended: false });
    await seedService_raw('s1', { providerId: 'p1', published: true });

    const res = (await call(
      fns.suspendProvider,
      { uid: 'p1', reason: 'spam' },
      { uid: 'mod', token: { moderator: true } }
    )) as { servicesUnpublished: number };
    expect(res.servicesUnpublished).toBe(1);
    expect((await getProvider('p1'))?.suspended).toBe(true);
    expect((await getService('s1'))?.published).toBe(false);

    // The provider is notified (provider-audience) that they are suspended.
    const notifs = await getNotifications('p1');
    expect(notifs).toHaveLength(1);
    expect(notifs[0]?.type).toBe('provider_suspended');
    expect(notifs[0]?.audience).toBe('provider');
  });

  it('rejects a caller without admin/moderator', async () => {
    await expectReject(
      call(fns.suspendProvider, { uid: 'p1' }, { uid: 'joe' }),
      'permission-denied'
    );
  });

  it('unsuspendProvider requires admin (moderator is not enough)', async () => {
    await admin
      .firestore()
      .collection('providers')
      .doc('p1')
      .set({ uid: 'p1', suspended: true });
    await expectReject(
      call(fns.unsuspendProvider, { uid: 'p1' }, { uid: 'mod', token: { moderator: true } }),
      'permission-denied'
    );
    await call(fns.unsuspendProvider, { uid: 'p1' }, { uid: 'boss', token: { admin: true } });
    expect((await getProvider('p1'))?.suspended).toBe(false);
  });
});

describe('removeService', () => {
  it('moderator unpublishes a service', async () => {
    await seedService_raw('s1', { providerId: 'p1', published: true });
    await call(fns.removeService, { serviceId: 's1' }, { uid: 'mod', token: { moderator: true } });
    expect((await getService('s1'))?.published).toBe(false);
  });

  it('returns not-found for an unknown service', async () => {
    await expectReject(
      call(fns.removeService, { serviceId: 'ghost' }, { uid: 'mod', token: { moderator: true } }),
      'not-found'
    );
  });
});

describe('deleteMessage', () => {
  it('moderator soft-deletes a message and strips its content', async () => {
    await seedMessage('c1', 'm1', { text: 'bad words', senderId: 'u9' });
    await call(
      fns.deleteMessage,
      { chatId: 'c1', messageId: 'm1' },
      { uid: 'mod', token: { moderator: true } }
    );
    const msg = await getMessage('c1', 'm1');
    expect(msg?.deleted).toBe(true);
    expect(msg?.text).toBeUndefined();
  });
});
