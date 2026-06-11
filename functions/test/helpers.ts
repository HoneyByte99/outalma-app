import * as admin from 'firebase-admin';

// The default app is initialized when ../src/index is imported by the test
// file (admin.initializeApp() at module load). Always grab firestore lazily.
const db = () => admin.firestore();

const projectId =
  process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? 'demo-outalma';

/// Wipes all documents in the Firestore emulator between tests so each case
/// starts from a clean slate. Uses the emulator's REST clear endpoint.
export async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set — run tests via "npm test" ' +
        '(firebase emulators:exec), not bare jest.'
    );
  }
  const res = await fetch(
    `http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
  if (!res.ok) {
    throw new Error(`Failed to clear emulator: ${res.status}`);
  }
}

export async function seedService(
  id: string,
  opts: { providerId: string; published?: boolean }
): Promise<void> {
  await db().collection('services').doc(id).set({
    providerId: opts.providerId,
    published: opts.published ?? true,
    title: 'Test service',
    priceType: 'fixed',
    priceCents: 1000,
  });
}

export async function seedProvider(
  id: string,
  opts: { suspended?: boolean } = {}
): Promise<void> {
  await db().collection('providers').doc(id).set({
    uid: id,
    active: true,
    suspended: opts.suspended ?? false,
  });
}

/// Seeds a booking document directly (bypassing createBooking) so transition
/// handlers can be tested from any starting status.
export async function seedBooking(
  id: string,
  data: {
    customerId: string;
    providerId: string;
    status: string;
    chatId?: string;
  }
): Promise<void> {
  await db().collection('bookings').doc(id).set({
    serviceId: 'svc1',
    requestMessage: 'hello',
    ...data,
  });
}

export async function getBooking(id: string) {
  const snap = await db().collection('bookings').doc(id).get();
  return snap.data();
}

export async function chatExists(chatId: string): Promise<boolean> {
  const snap = await db().collection('chats').doc(chatId).get();
  return snap.exists;
}
