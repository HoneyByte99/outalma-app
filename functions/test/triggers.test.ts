// Firestore triggers with side-effects beyond notifications: onServiceCreated
// auto-provisions a providers/{id} doc so the public profile is never empty.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import { clearFirestore, getProvider } from './helpers';

const db = () => admin.firestore();

beforeEach(async () => {
  await clearFirestore();
});
afterAll(async () => {
  tf.cleanup();
  await admin.firestore().terminate();
});

function serviceSnapshot(data: Record<string, unknown>, id = 'svc1') {
  return tf.firestore.makeDocumentSnapshot(data, `services/${id}`);
}

describe('onServiceCreated → provider auto-provision', () => {
  it('creates a providers/{id} doc when none exists', async () => {
    await tf.wrap(fns.onServiceCreated)({
      data: serviceSnapshot({ providerId: 'p1', published: true }),
      params: { serviceId: 'svc1' },
      id: 'evt-svc-1',
    } as never);

    const provider = await getProvider('p1');
    expect(provider).toBeDefined();
    expect(provider?.uid).toBe('p1');
    expect(provider?.active).toBe(true);
    expect(provider?.suspended).toBe(false);
  });

  it('does NOT overwrite an existing provider profile', async () => {
    await db()
      .collection('providers')
      .doc('p1')
      .set({ uid: 'p1', bio: 'Experienced plumber', suspended: true });

    await tf.wrap(fns.onServiceCreated)({
      data: serviceSnapshot({ providerId: 'p1' }),
      params: { serviceId: 'svc1' },
      id: 'evt-svc-2',
    } as never);

    const provider = await getProvider('p1');
    // Existing fields preserved - the trigger must not clobber onboarding data.
    expect(provider?.bio).toBe('Experienced plumber');
    expect(provider?.suspended).toBe(true);
  });
});
