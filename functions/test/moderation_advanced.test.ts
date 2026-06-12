// Advanced moderation + safety callables: user bans, review moderation, report
// resolution, the service moderation queue, and the IP blocklist. Auth emulator
// required (ban/unban toggle the auth account's disabled flag).
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import {
  clearFirestore,
  seedUser,
  seedService_raw,
  seedReview,
  getService,
  getReview,
  getNotifications,
  createAuthUser,
  authUserDisabled,
} from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };
const ADMIN: Auth = { uid: 'boss', token: { admin: true } };
const MOD: Auth = { uid: 'mod', token: { moderator: true } };
const SUPPORT: Auth = { uid: 'sup', token: { support: true } };

function call(fn: unknown, data: unknown, auth?: Auth): Promise<unknown> {
  const wrapped = tf.wrap(fn as never);
  return wrapped({ data, auth } as never);
}
async function expectReject(p: Promise<unknown>, code: string): Promise<void> {
  await expect(p).rejects.toMatchObject({ code: expect.stringContaining(code) });
}
const db = () => admin.firestore();

beforeEach(async () => {
  await clearFirestore();
});
afterAll(async () => {
  tf.cleanup();
  await admin.firestore().terminate();
});

describe('banUser / unbanUser', () => {
  it('admin bans: disables the auth account, records the ban and flags the user', async () => {
    await createAuthUser('bad');
    await seedUser('bad');
    await call(fns.banUser, { uid: 'bad', reason: 'fraud' }, ADMIN);

    expect(await authUserDisabled('bad')).toBe(true);
    expect((await db().collection('user_bans').doc('bad').get()).data()?.type).toBe('banned');
    expect((await db().collection('users').doc('bad').get()).data()?.isBanned).toBe(true);
  });

  it('admin unban re-enables the account and clears the flag', async () => {
    await createAuthUser('bad');
    await seedUser('bad');
    await call(fns.banUser, { uid: 'bad', reason: 'fraud' }, ADMIN);
    await call(fns.unbanUser, { uid: 'bad' }, ADMIN);

    expect(await authUserDisabled('bad')).toBe(false);
    expect((await db().collection('users').doc('bad').get()).data()?.isBanned).toBe(false);
  });

  it('a moderator cannot ban (admin-only)', async () => {
    await expectReject(call(fns.banUser, { uid: 'x', reason: 'r' }, MOD), 'permission-denied');
  });

  it('requires a reason', async () => {
    await expectReject(call(fns.banUser, { uid: 'x' }, ADMIN), 'invalid-argument');
  });
});

describe('shadowBanUser', () => {
  it('moderator shadow-bans: flags the user without disabling auth', async () => {
    await seedUser('ghost');
    await call(fns.shadowBanUser, { uid: 'ghost', reason: 'spam' }, MOD);
    expect((await db().collection('users').doc('ghost').get()).data()?.isShadowBanned).toBe(true);
    expect((await db().collection('user_bans').doc('ghost').get()).data()?.type).toBe('shadow_banned');
  });
});

describe('suspendUser', () => {
  it('support can suspend with a future expiry', async () => {
    await seedUser('s');
    const future = new Date(Date.now() + 86400000).toISOString();
    await call(fns.suspendUser, { uid: 's', reason: 'cooldown', expiresAt: future }, SUPPORT);
    expect((await db().collection('users').doc('s').get()).data()?.isSuspended).toBe(true);
    expect((await db().collection('user_bans').doc('s').get()).data()?.type).toBe('suspended');
  });

  it('rejects a past expiry', async () => {
    await seedUser('s');
    const past = new Date(Date.now() - 1000).toISOString();
    await expectReject(
      call(fns.suspendUser, { uid: 's', reason: 'x', expiresAt: past }, SUPPORT),
      'invalid-argument'
    );
  });
});

describe('review moderation', () => {
  beforeEach(async () => {
    await seedReview('rv1', { reviewerId: 'a', revieweeId: 'b' });
  });

  it('moderator hides and unhides a review', async () => {
    await call(fns.hideReview, { reviewId: 'rv1' }, MOD);
    expect((await getReview('rv1'))?.hidden).toBe(true);
    await call(fns.unhideReview, { reviewId: 'rv1' }, MOD);
    expect((await getReview('rv1'))?.hidden).toBe(false);
  });

  it('only an admin can delete a review', async () => {
    await expectReject(call(fns.deleteReview, { reviewId: 'rv1' }, MOD), 'permission-denied');
    await call(fns.deleteReview, { reviewId: 'rv1' }, ADMIN);
    expect(await getReview('rv1')).toBeUndefined();
  });
});

describe('resolveReport', () => {
  beforeEach(async () => {
    await db().collection('reports').doc('rep1').set({ status: 'open', reason: 'abuse' });
  });

  it('support resolves an open report', async () => {
    await call(fns.resolveReport, { reportId: 'rep1', action: 'resolved' }, SUPPORT);
    expect((await db().collection('reports').doc('rep1').get()).data()?.status).toBe('resolved');
  });

  it('rejects an invalid action', async () => {
    await expectReject(
      call(fns.resolveReport, { reportId: 'rep1', action: 'maybe' }, SUPPORT),
      'invalid-argument'
    );
  });

  it('refuses to resolve an already-closed report', async () => {
    await db().collection('reports').doc('rep1').update({ status: 'resolved' });
    await expectReject(
      call(fns.resolveReport, { reportId: 'rep1', action: 'resolved' }, SUPPORT),
      'failed-precondition'
    );
  });
});

describe('service moderation queue', () => {
  it('owner submits a service for review → unpublished + queue item', async () => {
    await seedService_raw('svc1', { providerId: 'owner', published: true });
    await call(fns.submitServiceForReview, { serviceId: 'svc1' }, { uid: 'owner' });
    const svc = await getService('svc1');
    expect(svc?.published).toBe(false);
    expect(svc?.status).toBe('pending_review');
    const queue = await db().collection('moderation_queue').where('serviceId', '==', 'svc1').get();
    expect(queue.size).toBe(1);
  });

  it('a non-owner cannot submit', async () => {
    await seedService_raw('svc1', { providerId: 'owner' });
    await expectReject(
      call(fns.submitServiceForReview, { serviceId: 'svc1' }, { uid: 'intruder' }),
      'permission-denied'
    );
  });

  it('support approves a pending queue item → service published', async () => {
    await seedService_raw('svc1', { providerId: 'owner', published: false, status: 'pending_review' });
    const q = await db().collection('moderation_queue').add({ serviceId: 'svc1', status: 'pending' });
    await call(fns.approveService, { queueItemId: q.id }, SUPPORT);
    expect((await getService('svc1'))?.published).toBe(true);
    expect((await db().collection('moderation_queue').doc(q.id).get()).data()?.status).toBe('approved');
    // Provider is notified (provider-audience) that their service is live.
    const notifs = await getNotifications('owner');
    expect(notifs).toHaveLength(1);
    expect(notifs[0]?.type).toBe('service_approved');
    expect(notifs[0]?.audience).toBe('provider');
  });

  it('reject requires a reason and marks the service rejected', async () => {
    await seedService_raw('svc1', { providerId: 'owner', status: 'pending_review' });
    const q = await db().collection('moderation_queue').add({ serviceId: 'svc1', status: 'pending' });
    await expectReject(call(fns.rejectService, { queueItemId: q.id }, SUPPORT), 'invalid-argument');
    await call(fns.rejectService, { queueItemId: q.id, reason: 'not allowed' }, SUPPORT);
    expect((await getService('svc1'))?.status).toBe('rejected');
    // Provider is notified (provider-audience) of the rejection.
    const notifs = await getNotifications('owner');
    expect(notifs).toHaveLength(1);
    expect(notifs[0]?.type).toBe('service_rejected');
    expect(notifs[0]?.audience).toBe('provider');
  });

  it('republish is blocked for a service still in moderation', async () => {
    await seedService_raw('svc1', { providerId: 'owner', status: 'rejected', published: false });
    await expectReject(call(fns.republishService, { serviceId: 'svc1' }, MOD), 'permission-denied');
  });

  it('republish works for an approved service', async () => {
    await seedService_raw('svc1', { providerId: 'owner', status: 'approved', published: false });
    await call(fns.republishService, { serviceId: 'svc1' }, MOD);
    expect((await getService('svc1'))?.published).toBe(true);
  });
});

describe('IP blocklist', () => {
  it('admin adds an IP, and a duplicate active entry is rejected', async () => {
    await call(fns.addToIpBlocklist, { ip: '1.2.3.4', reason: 'attack' }, ADMIN);
    const active = await db()
      .collection('ip_blocklist')
      .where('ip', '==', '1.2.3.4')
      .where('active', '==', true)
      .get();
    expect(active.size).toBe(1);
    await expectReject(
      call(fns.addToIpBlocklist, { ip: '1.2.3.4' }, ADMIN),
      'already-exists'
    );
  });

  it('admin removes a blocklist entry (deactivates it)', async () => {
    const res = (await call(fns.addToIpBlocklist, { ip: '9.9.9.9' }, ADMIN)) as { id: string };
    await call(fns.removeFromIpBlocklist, { entryId: res.id }, ADMIN);
    expect((await db().collection('ip_blocklist').doc(res.id).get()).data()?.active).toBe(false);
  });

  it('a non-admin cannot touch the blocklist', async () => {
    await expectReject(call(fns.addToIpBlocklist, { ip: '1.1.1.1' }, MOD), 'permission-denied');
  });
});
