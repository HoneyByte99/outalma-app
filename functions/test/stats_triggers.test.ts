// Platform-stats counter triggers (incrementStatIdempotent dedup) + the
// lightweight posts/events analytics triggers. We invoke each trigger directly
// with a synthetic event and assert the counter on the stats doc.
//
// Two doc paths are in play (verified in src/index.ts):
//   STATS_REF           = platform_stats/global  (user/provider/booking/report)
//   ANALYTICS_STATS_REF = stats/global           (posts/events)
//
// Idempotency: incrementStatIdempotent writes a processed_events/{eventId}
// dedup doc in the same transaction as the increment. Re-firing the SAME event
// id must be a no-op. We assert this by firing twice and checking the counter
// only moved once.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import { clearFirestore } from './helpers';

const db = () => admin.firestore();

beforeEach(async () => {
  await clearFirestore();
});
afterAll(async () => {
  tf.cleanup();
  await admin.firestore().terminate();
});

// platform_stats/global is the STATS_REF doc the idempotent counters write to.
async function platformStats(): Promise<Record<string, unknown> | undefined> {
  return (await db().collection('platform_stats').doc('global').get()).data();
}

// stats/global is the ANALYTICS_STATS_REF doc the posts/events triggers write.
async function analyticsStats(): Promise<Record<string, unknown> | undefined> {
  return (await db().collection('stats').doc('global').get()).data();
}

async function dedupExists(eventId: string): Promise<boolean> {
  return (await db().collection('processed_events').doc(eventId).get()).exists;
}

function createEvent(
  data: Record<string, unknown>,
  path: string,
  params: Record<string, string>,
  id: string,
) {
  return {
    data: tf.firestore.makeDocumentSnapshot(data, path),
    params,
    id,
  } as never;
}

function updateEvent(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  path: string,
  params: Record<string, string>,
  id: string,
) {
  const change = tf.makeChange(
    tf.firestore.makeDocumentSnapshot(before, path),
    tf.firestore.makeDocumentSnapshot(after, path),
  );
  return { data: change, params, id } as never;
}

// ---------------------------------------------------------------------------
// onUserCreated → totalUsers
// ---------------------------------------------------------------------------
describe('onUserCreated → platform_stats.totalUsers', () => {
  it('increments totalUsers and writes a dedup doc', async () => {
    await tf.wrap(fns.onUserCreated)(
      createEvent({ displayName: 'U' }, 'users/u1', { userId: 'u1' }, 'evt-user-1'),
    );

    expect((await platformStats())?.totalUsers).toBe(1);
    expect(await dedupExists('evt-user-1')).toBe(true);
  });

  it('is idempotent: the same event id only counts once', async () => {
    const ev = createEvent({ displayName: 'U' }, 'users/u1', { userId: 'u1' }, 'evt-user-dup');
    await tf.wrap(fns.onUserCreated)(ev);
    await tf.wrap(fns.onUserCreated)(ev);

    expect((await platformStats())?.totalUsers).toBe(1);
  });

  it('distinct event ids each count', async () => {
    await tf.wrap(fns.onUserCreated)(
      createEvent({}, 'users/u1', { userId: 'u1' }, 'evt-user-a'),
    );
    await tf.wrap(fns.onUserCreated)(
      createEvent({}, 'users/u2', { userId: 'u2' }, 'evt-user-b'),
    );

    expect((await platformStats())?.totalUsers).toBe(2);
  });
});

// ---------------------------------------------------------------------------
// onProviderCreated → totalProviders
// ---------------------------------------------------------------------------
describe('onProviderCreated → platform_stats.totalProviders', () => {
  it('increments totalProviders', async () => {
    await tf.wrap(fns.onProviderCreated)(
      createEvent({ uid: 'p1' }, 'providers/p1', { providerId: 'p1' }, 'evt-prov-1'),
    );

    expect((await platformStats())?.totalProviders).toBe(1);
    expect(await dedupExists('evt-prov-1')).toBe(true);
  });

  it('is idempotent on the same event id', async () => {
    const ev = createEvent({ uid: 'p1' }, 'providers/p1', { providerId: 'p1' }, 'evt-prov-dup');
    await tf.wrap(fns.onProviderCreated)(ev);
    await tf.wrap(fns.onProviderCreated)(ev);

    expect((await platformStats())?.totalProviders).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// onBookingUpdatedStats → totalBookingsDone (only on transition INTO done)
// ---------------------------------------------------------------------------
describe('onBookingUpdatedStats → platform_stats.totalBookingsDone', () => {
  it('increments when status transitions to done', async () => {
    await tf.wrap(fns.onBookingUpdatedStats)(
      updateEvent(
        { status: 'in_progress' },
        { status: 'done' },
        'bookings/b1',
        { bookingId: 'b1' },
        'evt-book-done-1',
      ),
    );

    expect((await platformStats())?.totalBookingsDone).toBe(1);
    expect(await dedupExists('evt-book-done-1')).toBe(true);
  });

  it('is idempotent on the same event id', async () => {
    const ev = updateEvent(
      { status: 'in_progress' },
      { status: 'done' },
      'bookings/b1',
      { bookingId: 'b1' },
      'evt-book-done-dup',
    );
    await tf.wrap(fns.onBookingUpdatedStats)(ev);
    await tf.wrap(fns.onBookingUpdatedStats)(ev);

    expect((await platformStats())?.totalBookingsDone).toBe(1);
  });

  it('does nothing when status is unchanged', async () => {
    await tf.wrap(fns.onBookingUpdatedStats)(
      updateEvent(
        { status: 'accepted' },
        { status: 'accepted' },
        'bookings/b1',
        { bookingId: 'b1' },
        'evt-book-noop-1',
      ),
    );

    expect(await platformStats()).toBeUndefined();
    expect(await dedupExists('evt-book-noop-1')).toBe(false);
  });

  it('does nothing for a non-done transition', async () => {
    await tf.wrap(fns.onBookingUpdatedStats)(
      updateEvent(
        { status: 'requested' },
        { status: 'accepted' },
        'bookings/b1',
        { bookingId: 'b1' },
        'evt-book-accept-1',
      ),
    );

    expect(await platformStats()).toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// onReportCreatedStats → totalReports + totalReportsPending
// ---------------------------------------------------------------------------
describe('onReportCreatedStats → platform_stats report counters', () => {
  it('increments totalReports and totalReportsPending', async () => {
    await tf.wrap(fns.onReportCreatedStats)(
      createEvent(
        { reason: 'spam', status: 'open' },
        'reports/r1',
        { reportId: 'r1' },
        'evt-report-1',
      ),
    );

    const stats = await platformStats();
    expect(stats?.totalReports).toBe(1);
    expect(stats?.totalReportsPending).toBe(1);
    expect(await dedupExists('evt-report-1')).toBe(true);
  });

  it('is idempotent on the same event id', async () => {
    const ev = createEvent(
      { reason: 'spam', status: 'open' },
      'reports/r1',
      { reportId: 'r1' },
      'evt-report-dup',
    );
    await tf.wrap(fns.onReportCreatedStats)(ev);
    await tf.wrap(fns.onReportCreatedStats)(ev);

    const stats = await platformStats();
    expect(stats?.totalReports).toBe(1);
    expect(stats?.totalReportsPending).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// onReportUpdatedStats → totalReportsPending-- (only on open → not-open)
// ---------------------------------------------------------------------------
describe('onReportUpdatedStats → platform_stats.totalReportsPending', () => {
  it('decrements pending when a report leaves open status', async () => {
    await tf.wrap(fns.onReportUpdatedStats)(
      updateEvent(
        { status: 'open' },
        { status: 'resolved' },
        'reports/r1',
        { reportId: 'r1' },
        'evt-report-close-1',
      ),
    );

    expect((await platformStats())?.totalReportsPending).toBe(-1);
    expect(await dedupExists('evt-report-close-1')).toBe(true);
  });

  it('is idempotent on the same event id', async () => {
    const ev = updateEvent(
      { status: 'open' },
      { status: 'resolved' },
      'reports/r1',
      { reportId: 'r1' },
      'evt-report-close-dup',
    );
    await tf.wrap(fns.onReportUpdatedStats)(ev);
    await tf.wrap(fns.onReportUpdatedStats)(ev);

    expect((await platformStats())?.totalReportsPending).toBe(-1);
  });

  it('does nothing when status is unchanged', async () => {
    await tf.wrap(fns.onReportUpdatedStats)(
      updateEvent(
        { status: 'open' },
        { status: 'open' },
        'reports/r1',
        { reportId: 'r1' },
        'evt-report-noop-1',
      ),
    );

    expect(await platformStats()).toBeUndefined();
    expect(await dedupExists('evt-report-noop-1')).toBe(false);
  });

  it('does nothing when the report was not open before', async () => {
    await tf.wrap(fns.onReportUpdatedStats)(
      updateEvent(
        { status: 'resolved' },
        { status: 'dismissed' },
        'reports/r1',
        { reportId: 'r1' },
        'evt-report-reclose-1',
      ),
    );

    expect(await platformStats()).toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// posts/events analytics triggers → stats/global (no dedup, plain increment)
// ---------------------------------------------------------------------------
describe('onPostCreated / onPostDeleted → stats.postsCount', () => {
  it('onPostCreated increments postsCount', async () => {
    await tf.wrap(fns.onPostCreated)(
      createEvent({ title: 'hi' }, 'posts/post1', { postId: 'post1' }, 'evt-post-c1'),
    );

    expect((await analyticsStats())?.postsCount).toBe(1);
  });

  it('onPostDeleted decrements postsCount', async () => {
    await tf.wrap(fns.onPostCreated)(
      createEvent({ title: 'hi' }, 'posts/post1', { postId: 'post1' }, 'evt-post-c2'),
    );
    await tf.wrap(fns.onPostDeleted)(
      createEvent({ title: 'hi' }, 'posts/post1', { postId: 'post1' }, 'evt-post-d1'),
    );

    expect((await analyticsStats())?.postsCount).toBe(0);
  });
});

describe('onEventCreated / onEventDeleted → stats.eventsCount', () => {
  it('onEventCreated increments eventsCount', async () => {
    await tf.wrap(fns.onEventCreated)(
      createEvent({ name: 'meetup' }, 'events/e1', { eventId: 'e1' }, 'evt-event-c1'),
    );

    expect((await analyticsStats())?.eventsCount).toBe(1);
  });

  it('onEventDeleted decrements eventsCount', async () => {
    await tf.wrap(fns.onEventCreated)(
      createEvent({ name: 'meetup' }, 'events/e1', { eventId: 'e1' }, 'evt-event-c2'),
    );
    await tf.wrap(fns.onEventDeleted)(
      createEvent({ name: 'meetup' }, 'events/e1', { eventId: 'e1' }, 'evt-event-d1'),
    );

    expect((await analyticsStats())?.eventsCount).toBe(0);
  });
});
