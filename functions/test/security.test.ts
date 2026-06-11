// Security + scheduled functions: logSession (session/event logging on sign-in),
// resolveSecurityAlert (admin-only), and the daily purge jobs
// (purgeExpiredSessionData / purgeIpGeoCache). Auth emulator is used so the
// authenticated callable guards behave as in production.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import { clearFirestore } from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };

// Minimal Cloud Run request envelope. logSession reads
// request.rawRequest.headers['x-forwarded-for'] and
// request.rawRequest.socket?.remoteAddress to derive the client IP.
// Defaulting to a loopback address keeps `ip` null, so no external geolocation
// fetch, blocklist check, or anomaly detection side-effect is triggered — the
// happy path stays fully deterministic and offline.
function rawRequest(forwardedFor?: string, remoteAddress = '127.0.0.1') {
  return {
    headers: forwardedFor ? { 'x-forwarded-for': forwardedFor } : {},
    socket: { remoteAddress },
  };
}

function callLogSession(data: unknown, auth?: Auth, fwd?: string): Promise<unknown> {
  const wrapped = tf.wrap(fns.logSession as never);
  return wrapped({ data, auth, rawRequest: rawRequest(fwd) } as never);
}

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

describe('logSession', () => {
  it('rejects an unauthenticated caller', async () => {
    await expectReject(
      callLogSession({ platform: 'android' }, undefined),
      'unauthenticated'
    );
  });

  it('rejects an invalid platform value', async () => {
    await expectReject(
      callLogSession({ platform: 'windows' }, { uid: 'u1' }),
      'invalid-argument'
    );
  });

  it('writes the session doc and an event doc for an authenticated caller', async () => {
    const res = (await callLogSession(
      {
        platform: 'ios',
        deviceModel: 'iPhone15,2',
        appVersion: '1.2.3',
        sessionId: 'sess-abc',
      },
      { uid: 'u1' }
    )) as { logged: boolean };

    expect(res.logged).toBe(true);

    // Session summary doc (user_sessions/{uid}).
    const sessionSnap = await db().collection('user_sessions').doc('u1').get();
    expect(sessionSnap.exists).toBe(true);
    const session = sessionSnap.data()!;
    expect(session.uid).toBe('u1');
    expect(session.lastPlatform).toBe('ios');
    // Loopback IP is stripped to null.
    expect(session.lastIp).toBeNull();

    // Event doc in the events subcollection.
    const eventsSnap = await db()
      .collection('user_sessions')
      .doc('u1')
      .collection('events')
      .get();
    expect(eventsSnap.size).toBe(1);
    const event = eventsSnap.docs[0]!.data();
    expect(event.uid).toBe('u1');
    expect(event.platform).toBe('ios');
    expect(event.deviceModel).toBe('iPhone15,2');
    expect(event.appVersion).toBe('1.2.3');
    expect(event.sessionId).toBe('sess-abc');
    expect(event.ip).toBeNull();
    expect(event.loggedAt).toBeTruthy();
  });

  it('does not create a security alert when the IP is loopback (anomaly detection skipped)', async () => {
    await callLogSession({ platform: 'android' }, { uid: 'u2' });
    // detectAnomalies returns early when ip/countryCode are null, so no alert
    // is written for a plain loopback sign-in.
    const alerts = await db().collection('security_alerts').get();
    expect(alerts.empty).toBe(true);
  });
});

describe('resolveSecurityAlert', () => {
  async function seedAlert(
    id: string,
    data: Record<string, unknown> = {}
  ): Promise<void> {
    await db().collection('security_alerts').doc(id).set({
      uid: 'victim',
      type: 'unusual_country',
      severity: 'medium',
      status: 'open',
      description: 'First login from SN',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedAt: null,
      resolvedBy: null,
      ...data,
    });
  }

  it('rejects an unauthenticated caller', async () => {
    await seedAlert('a1');
    await expectReject(
      call(fns.resolveSecurityAlert, { alertId: 'a1' }, undefined),
      'unauthenticated'
    );
  });

  it('rejects a non-admin caller', async () => {
    await seedAlert('a1');
    await expectReject(
      call(fns.resolveSecurityAlert, { alertId: 'a1' }, { uid: 'mod', token: { moderator: true } }),
      'permission-denied'
    );
  });

  it('lets an admin resolve an open alert', async () => {
    await seedAlert('a1');
    const res = (await call(
      fns.resolveSecurityAlert,
      { alertId: 'a1', notes: 'verified safe' },
      { uid: 'boss', token: { admin: true } }
    )) as { alertId: string; status: string };

    expect(res.alertId).toBe('a1');
    expect(res.status).toBe('resolved');

    const alert = (await db().collection('security_alerts').doc('a1').get()).data()!;
    expect(alert.status).toBe('resolved');
    expect(alert.resolvedBy).toBe('boss');
    expect(alert.resolutionNotes).toBe('verified safe');
    expect(alert.resolvedAt).toBeTruthy();
  });

  it('rejects resolving an alert that is not open', async () => {
    await seedAlert('a1', { status: 'resolved' });
    await expectReject(
      call(fns.resolveSecurityAlert, { alertId: 'a1' }, { uid: 'boss', token: { admin: true } }),
      'failed-precondition'
    );
  });

  it('returns not-found for an unknown alert', async () => {
    await expectReject(
      call(fns.resolveSecurityAlert, { alertId: 'ghost' }, { uid: 'boss', token: { admin: true } }),
      'not-found'
    );
  });
});

describe('purgeExpiredSessionData', () => {
  // Retention is 90 days; events with loggedAt older than the cutoff are deleted.
  const daysAgo = (n: number) =>
    admin.firestore.Timestamp.fromDate(new Date(Date.now() - n * 24 * 60 * 60 * 1000));

  it('deletes expired session events and keeps fresh ones', async () => {
    const events = db()
      .collection('user_sessions')
      .doc('u1')
      .collection('events');
    await events.doc('old').set({ uid: 'u1', loggedAt: daysAgo(120) });
    await events.doc('fresh').set({ uid: 'u1', loggedAt: daysAgo(10) });

    await (tf.wrap(fns.purgeExpiredSessionData as never) as () => Promise<void>)();

    expect((await events.doc('old').get()).exists).toBe(false);
    expect((await events.doc('fresh').get()).exists).toBe(true);
  });

  it('is a no-op when nothing is expired', async () => {
    const events = db()
      .collection('user_sessions')
      .doc('u2')
      .collection('events');
    await events.doc('fresh').set({ uid: 'u2', loggedAt: daysAgo(1) });

    await (tf.wrap(fns.purgeExpiredSessionData as never) as () => Promise<void>)();

    expect((await events.doc('fresh').get()).exists).toBe(true);
  });
});

describe('purgeIpGeoCache', () => {
  // Cache entries older than 30 days (by cachedAt) are deleted.
  const daysAgo = (n: number) =>
    admin.firestore.Timestamp.fromDate(new Date(Date.now() - n * 24 * 60 * 60 * 1000));

  it('deletes stale geo cache entries and keeps fresh ones', async () => {
    const cache = db().collection('ip_geo_cache');
    await cache.doc('stale').set({ countryCode: 'FR', cachedAt: daysAgo(45) });
    await cache.doc('fresh').set({ countryCode: 'SN', cachedAt: daysAgo(5) });

    await (tf.wrap(fns.purgeIpGeoCache as never) as () => Promise<void>)();

    expect((await cache.doc('stale').get()).exists).toBe(false);
    expect((await cache.doc('fresh').get()).exists).toBe(true);
  });

  it('is a no-op when the cache has no stale entries', async () => {
    const cache = db().collection('ip_geo_cache');
    await cache.doc('fresh').set({ countryCode: 'FR', cachedAt: daysAgo(2) });

    await (tf.wrap(fns.purgeIpGeoCache as never) as () => Promise<void>)();

    expect((await cache.doc('fresh').get()).exists).toBe(true);
  });
});
