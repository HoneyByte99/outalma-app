// ---------------------------------------------------------------------------
// Notification helpers (push + in-app)
// ---------------------------------------------------------------------------
//
// Moved out of index.ts unchanged so that new callables can reuse them without
// importing the entrypoint (which would create a cycle with a module that has
// side effects: initializeApp() and the callable registrations).
//
// Firestore is obtained LAZILY here. An eager `admin.firestore()` at module
// scope would run when index.ts requires this file, that is, BEFORE index.ts
// reaches admin.initializeApp(), and would throw "The default Firebase app does
// not exist". auth_phone.ts already does it this way for the same reason.

import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

const db = () => admin.firestore();

export async function sendPushToUsers(
  uids: string[],
  notification: { title: string; body: string },
  // Optional deep-link payload so the app can route on tap. All values must be
  // strings (FCM data payload constraint).
  data?: { [key: string]: string }
): Promise<void> {
  if (uids.length === 0) return;

  // Fetch push tokens from user documents, keeping the uid/token mapping so we
  // can purge a token that FCM reports as permanently invalid (below).
  const snapshots = await Promise.all(
    uids.map(uid => db().collection('users').doc(uid).get())
  );

  const entries: { uid: string; token: string }[] = [];
  for (const snap of snapshots) {
    const token = snap.data()?.pushToken as string | undefined;
    if (token) entries.push({ uid: snap.id, token });
  }

  if (entries.length === 0) return;

  // Send multicast. No Android `clickAction`: modern firebase_messaging routes
  // notification taps natively via onMessageOpenedApp/getInitialMessage, so the
  // legacy FLUTTER_NOTIFICATION_CLICK intent is unnecessary (and was a no-op
  // without a matching intent-filter).
  const result = await admin.messaging().sendEachForMulticast({
    tokens: entries.map(e => e.token),
    notification: {
      title: notification.title,
      body: notification.body,
    },
    ...(data ? { data } : {}),
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  logger.info('Push sent', {
    successCount: result.successCount,
    failureCount: result.failureCount,
  });

  // Purge tokens FCM reports as permanently invalid (uninstalled / reinstalled
  // app, expired token). Otherwise they linger forever and every send silently
  // fails. Delete only if the stored token still matches, never clobber a fresh
  // token registered in the meantime.
  const stale: { uid: string; token: string }[] = [];
  result.responses.forEach((resp, i) => {
    if (resp.success) return;
    const entry = entries[i];
    if (!entry) return;
    const code = resp.error?.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/invalid-argument'
    ) {
      stale.push(entry);
    }
  });
  await Promise.all(
    stale.map(async ({ uid, token }) => {
      try {
        const ref = db().collection('users').doc(uid);
        await db().runTransaction(async (tx) => {
          const cur = await tx.get(ref);
          if (cur.data()?.pushToken === token) {
            tx.update(ref, {
              pushToken: admin.firestore.FieldValue.delete(),
            });
          }
        });
      } catch {
        logger.warn('Failed to purge stale token', { uid });
      }
    })
  );
}

export async function createNotification(
  uid: string,
  data: {
    type: string;
    title: string;
    body: string;
    bookingId?: string;
    chatId?: string;
    // Which role this notification targets, drives the Client/Provider tabs in
    // the app. Required: every call site knows the recipient's role, and a
    // notification written without it silently falls back to `both` on the
    // client (see notificationAudienceFor in app_notification.dart), which is
    // exactly how the pre-audience stock (344/391 notifications, 2026-09
    // audit) leaked a provider's chats into the client tab and vice versa.
    // Runtime check below, not just the type: a caller compiled against a
    // stale .d.ts, or one reached from plain JS, would otherwise bypass this
    // at the type layer alone.
    audience: 'client' | 'provider';
  }
): Promise<void> {
  if (data.audience !== 'client' && data.audience !== 'provider') {
    throw new Error(
      `createNotification: missing/invalid audience for type "${data.type}" ` +
        `(uid=${uid}). Every caller must resolve the recipient's role; see ` +
        'scripts/backfill-notification-audience.py for what happens when it does not.'
    );
  }
  await db()
    .collection('notifications')
    .doc(uid)
    .collection('items')
    .add({
      type: data.type,
      title: data.title,
      body: data.body,
      bookingId: data.bookingId ?? null,
      chatId: data.chatId ?? null,
      audience: data.audience,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
