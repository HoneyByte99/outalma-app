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
      'FIRESTORE_EMULATOR_HOST is not set - run tests via "npm test" ' +
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
  opts: { suspended?: boolean; active?: boolean } = {}
): Promise<void> {
  await db().collection('providers').doc(id).set({
    uid: id,
    active: opts.active ?? true,
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

export async function seedUser(
  uid: string,
  data: Record<string, unknown> = {}
): Promise<void> {
  await db().collection('users').doc(uid).set({ displayName: 'U', ...data });
}

export async function getUser(uid: string) {
  return (await db().collection('users').doc(uid).get()).data();
}

export async function userExists(uid: string): Promise<boolean> {
  return (await db().collection('users').doc(uid).get()).exists;
}

/// Returns the in-app notification items written for a user
/// (notifications/{uid}/items).
export async function getNotifications(uid: string) {
  const q = await db()
    .collection('notifications')
    .doc(uid)
    .collection('items')
    .get();
  return q.docs.map((d) => d.data());
}

export async function seedService_raw(id: string, data: Record<string, unknown>) {
  await db().collection('services').doc(id).set(data);
}

export async function seedReview(
  id: string,
  data: { reviewerId: string; revieweeId: string }
): Promise<void> {
  await db().collection('reviews').doc(id).set({ rating: 5, ...data });
}

export async function serviceExists(id: string): Promise<boolean> {
  return (await db().collection('services').doc(id).get()).exists;
}

export async function getService(id: string) {
  return (await db().collection('services').doc(id).get()).data();
}

export async function getProvider(id: string) {
  return (await db().collection('providers').doc(id).get()).data();
}

export async function seedMessage(
  chatId: string,
  messageId: string,
  data: Record<string, unknown>
): Promise<void> {
  await db()
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .doc(messageId)
    .set({ text: 'hi', senderId: 'x', ...data });
}

export async function getMessage(chatId: string, messageId: string) {
  return (
    await db()
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId)
      .get()
  ).data();
}

export async function getReview(id: string) {
  return (await db().collection('reviews').doc(id).get()).data();
}

// ---- Firebase Auth emulator helpers ----

/// Recreates an auth user (idempotent across tests) with optional custom claims.
export async function createAuthUser(
  uid: string,
  claims?: Record<string, unknown>
): Promise<void> {
  try {
    await admin.auth().deleteUser(uid);
  } catch {
    // didn't exist - fine
  }
  await admin.auth().createUser({ uid, email: `${uid}@test.dev` });
  if (claims) await admin.auth().setCustomUserClaims(uid, claims);
}

export async function authUserExists(uid: string): Promise<boolean> {
  try {
    await admin.auth().getUser(uid);
    return true;
  } catch {
    return false;
  }
}

export async function authUserDisabled(uid: string): Promise<boolean> {
  const u = await admin.auth().getUser(uid);
  return u.disabled;
}
