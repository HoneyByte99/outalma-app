// Role-claim setters (moderator / support / readonly) + session and stats
// admin callables. All require the auth emulator (custom claims, getUser,
// revokeRefreshTokens). Each setter sets a custom claim on the target auth
// user and mirrors the role into user_roles/{uid}.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import { clearFirestore } from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };

function call(fn: unknown, data: unknown, auth?: Auth): Promise<unknown> {
  const wrapped = tf.wrap(fn as never);
  return wrapped({ data, auth } as never);
}

async function expectReject(p: Promise<unknown>, code: string): Promise<void> {
  await expect(p).rejects.toMatchObject({ code: expect.stringContaining(code) });
}

// Recreates an auth user idempotently (claim setters + revokeUserSessions read
// the auth account, so it must exist before they run).
async function createAuthUser(
  uid: string,
  claims?: Record<string, unknown>
): Promise<void> {
  try {
    await admin.auth().deleteUser(uid);
  } catch {
    // didn't exist — fine
  }
  await admin.auth().createUser({ uid, email: `${uid}@test.dev` });
  if (claims) await admin.auth().setCustomUserClaims(uid, claims);
}

async function getRole(uid: string) {
  return (await admin.firestore().collection('user_roles').doc(uid).get()).data();
}

const ADMIN: Auth = { uid: 'boss', token: { admin: true } };

beforeEach(async () => {
  await clearFirestore();
});

afterAll(async () => {
  tf.cleanup();
  await admin.firestore().terminate();
});

describe('setModeratorClaim', () => {
  it('rejects a non-admin caller', async () => {
    await expectReject(
      call(fns.setModeratorClaim, { uid: 'target', moderator: true }, { uid: 'nobody' }),
      'permission-denied'
    );
  });

  it('lets an admin grant the moderator claim and mirrors it to user_roles', async () => {
    await createAuthUser('target');
    const res = (await call(
      fns.setModeratorClaim,
      { uid: 'target', moderator: true },
      ADMIN
    )) as { uid: string; moderator: boolean };
    expect(res.moderator).toBe(true);

    const user = await admin.auth().getUser('target');
    expect(user.customClaims?.moderator).toBe(true);

    const role = await getRole('target');
    expect(role?.moderator).toBe(true);
    expect(role?.admin).toBe(false);
  });

  it('preserves an existing admin claim when granting moderator', async () => {
    await createAuthUser('target', { admin: true });
    await call(fns.setModeratorClaim, { uid: 'target', moderator: true }, ADMIN);

    const user = await admin.auth().getUser('target');
    expect(user.customClaims?.admin).toBe(true);
    expect(user.customClaims?.moderator).toBe(true);

    const role = await getRole('target');
    expect(role?.admin).toBe(true);
    expect(role?.moderator).toBe(true);
  });
});

describe('setSupportClaim', () => {
  it('rejects a non-admin caller', async () => {
    await expectReject(
      call(fns.setSupportClaim, { uid: 'target', support: true }, { uid: 'nobody' }),
      'permission-denied'
    );
  });

  it('lets an admin grant the support claim and mirrors it to user_roles', async () => {
    await createAuthUser('target');
    const res = (await call(
      fns.setSupportClaim,
      { uid: 'target', support: true },
      ADMIN
    )) as { uid: string; support: boolean };
    expect(res.support).toBe(true);

    const user = await admin.auth().getUser('target');
    expect(user.customClaims?.support).toBe(true);

    const role = await getRole('target');
    expect(role?.support).toBe(true);
  });
});

describe('setReadonlyClaim', () => {
  it('rejects a non-admin caller', async () => {
    await expectReject(
      call(fns.setReadonlyClaim, { uid: 'target', readonly: true }, { uid: 'nobody' }),
      'permission-denied'
    );
  });

  it('lets an admin grant the readonly claim and mirrors it to user_roles', async () => {
    await createAuthUser('target');
    const res = (await call(
      fns.setReadonlyClaim,
      { uid: 'target', readonly: true },
      ADMIN
    )) as { uid: string; readonly: boolean };
    expect(res.readonly).toBe(true);

    const user = await admin.auth().getUser('target');
    expect(user.customClaims?.readonly).toBe(true);

    const role = await getRole('target');
    expect(role?.readonly).toBe(true);
  });
});

describe('revokeUserSessions', () => {
  it('rejects a non-admin caller', async () => {
    await expectReject(
      call(fns.revokeUserSessions, { uid: 'target' }, { uid: 'nobody' }),
      'permission-denied'
    );
  });

  it('lets an admin revoke a user\'s sessions', async () => {
    await createAuthUser('target');
    const before = (await admin.auth().getUser('target')).tokensValidAfterTime;

    const res = (await call(
      fns.revokeUserSessions,
      { uid: 'target' },
      ADMIN
    )) as { uid: string; revoked: boolean };
    expect(res.revoked).toBe(true);

    const after = (await admin.auth().getUser('target')).tokensValidAfterTime;
    // revokeRefreshTokens bumps tokensValidAfterTime forward.
    expect(after).toBeTruthy();
    if (before) {
      expect(new Date(after as string).getTime()).toBeGreaterThanOrEqual(
        new Date(before).getTime()
      );
    }
  });
});

describe('initializeStats', () => {
  it('rejects a non-admin caller', async () => {
    await expectReject(call(fns.initializeStats, {}, { uid: 'nobody' }), 'permission-denied');
  });

  it('rejects an unauthenticated caller', async () => {
    await expectReject(call(fns.initializeStats, {}), 'unauthenticated');
  });

  it('initializes the global stats doc when missing', async () => {
    const res = (await call(fns.initializeStats, {}, ADMIN)) as { initialized: boolean };
    expect(res.initialized).toBe(true);

    const snap = await admin.firestore().collection('stats').doc('global').get();
    expect(snap.exists).toBe(true);
    expect(snap.data()?.postsCount).toBe(0);
    expect(snap.data()?.eventsCount).toBe(0);
  });

  it('is a no-op when the stats doc already exists', async () => {
    await admin
      .firestore()
      .collection('stats')
      .doc('global')
      .set({ postsCount: 7, eventsCount: 3 });

    const res = (await call(fns.initializeStats, {}, ADMIN)) as {
      initialized: boolean;
      reason?: string;
    };
    expect(res.initialized).toBe(false);
    expect(res.reason).toBe('already_exists');

    // Existing counters must be left untouched.
    const snap = await admin.firestore().collection('stats').doc('global').get();
    expect(snap.data()?.postsCount).toBe(7);
    expect(snap.data()?.eventsCount).toBe(3);
  });
});
