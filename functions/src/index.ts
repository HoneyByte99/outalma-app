import * as admin from 'firebase-admin';
import { createHash } from 'crypto';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import { assertAdminClaim, assertAdminOrModeratorClaim, assertMinSupportClaim, assertAuthenticated, requireBoolean, requireString } from './common';

admin.initializeApp();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// IP geolocation cache (ipapi.co has 1 000 req/day on free tier)
// ---------------------------------------------------------------------------

const IP_GEO_CACHE_TTL_DAYS = 7;

interface GeoData {
  countryCode: string | null;
  country: string | null;
  city: string | null;
  region: string | null;
  isp: string | null;
  asn: string | null;
  latitude: number | null;
  longitude: number | null;
}

function ipHash(ip: string): string {
  return createHash('sha256').update(ip).digest('hex').substring(0, 32);
}

async function getGeoForIp(ip: string): Promise<GeoData> {
  const empty: GeoData = {
    countryCode: null, country: null, city: null, region: null,
    isp: null, asn: null, latitude: null, longitude: null,
  };

  const hash = ipHash(ip);
  const cacheRef = db.collection('ip_geo_cache').doc(hash);
  const cached = await cacheRef.get();

  if (cached.exists) {
    const data = cached.data()!;
    const cachedAt = data.cachedAt as admin.firestore.Timestamp;
    const ageMs = Date.now() - cachedAt.toMillis();
    if (ageMs < IP_GEO_CACHE_TTL_DAYS * 24 * 60 * 60 * 1000) {
      return {
        countryCode: data.countryCode ?? null,
        country: data.country ?? null,
        city: data.city ?? null,
        region: data.region ?? null,
        isp: data.isp ?? null,
        asn: data.asn ?? null,
        latitude: data.latitude ?? null,
        longitude: data.longitude ?? null,
      };
    }
  }

  try {
    const geoResp = await fetch(`https://ipapi.co/${ip}/json/`);
    if (geoResp.ok) {
      const geo = (await geoResp.json()) as {
        country_code?: string; country_name?: string;
        city?: string; region?: string; org?: string; asn?: string;
        latitude?: number; longitude?: number; error?: boolean;
      };
      if (!geo.error) {
        const result: GeoData = {
          countryCode: geo.country_code ?? null,
          country: geo.country_name ?? null,
          city: geo.city ?? null,
          region: geo.region ?? null,
          isp: geo.org ?? null,
          asn: geo.asn ?? null,
          latitude: geo.latitude ?? null,
          longitude: geo.longitude ?? null,
        };
        await cacheRef.set({
          ...result,
          cachedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return result;
      }
    }
  } catch (e) {
    logger.warn('IP geolocation failed', { ip, error: String(e) });
  }

  return empty;
}

// ---------------------------------------------------------------------------
// Phone authentication — production OTP flow (Twilio Verify backend)
// ---------------------------------------------------------------------------
export {
  requestPhoneOtp,
  verifyPhoneOtpAndSignIn,
  verifyPhoneOtpAndSignUp,
} from './auth_phone';

// NOTE: legacy `sendOtpTwilio` / `verifyOtpTwilio` callables (file
// `otp_twilio.ts`) are intentionally NOT exported. They share the canonical
// pipeline's surface area but lack the hardening done in `auth_phone.ts`
// (Auth-side uniqueness, displayName sanitisation, race protection).
// Re-enable behind a feature flag only if a future benchmark needs them.

// ---------------------------------------------------------------------------
// Push notification helper
// ---------------------------------------------------------------------------

async function sendPushToUsers(
  uids: string[],
  notification: { title: string; body: string },
  // Optional deep-link payload so the app can route on tap. All values must be
  // strings (FCM data payload constraint).
  data?: { [key: string]: string }
): Promise<void> {
  if (uids.length === 0) return;

  // Fetch push tokens from user documents
  const snapshots = await Promise.all(
    uids.map(uid => db.collection('users').doc(uid).get())
  );

  const tokens: string[] = [];
  for (const snap of snapshots) {
    const token = snap.data()?.pushToken as string | undefined;
    if (token) tokens.push(token);
  }

  if (tokens.length === 0) return;

  // Send multicast
  const result = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    ...(data ? { data } : {}),
    android: {
      priority: 'high',
      // Ensures the tap intent carries the data payload on Android.
      notification: { clickAction: 'FLUTTER_NOTIFICATION_CLICK' },
    },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  logger.info('Push sent', {
    successCount: result.successCount,
    failureCount: result.failureCount,
  });
}

// ---------------------------------------------------------------------------
// In-app notification helper
// ---------------------------------------------------------------------------

async function createNotification(
  uid: string,
  data: {
    type: string;
    title: string;
    body: string;
    bookingId?: string;
    chatId?: string;
  }
): Promise<void> {
  await db
    .collection('notifications')
    .doc(uid)
    .collection('items')
    .add({
      type: data.type,
      title: data.title,
      body: data.body,
      bookingId: data.bookingId ?? null,
      chatId: data.chatId ?? null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

type BookingStatus =
  | 'requested'
  | 'accepted'
  | 'rejected'
  | 'cancelled'
  | 'in_progress'
  | 'done';

function chatIdForBooking(bookingId: string): string {
  return `chat_${bookingId}`;
}

export const createBooking = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const providerId = requireString(request.data?.providerId, 'providerId');
  const serviceId = requireString(request.data?.serviceId, 'serviceId');
  const requestMessage = requireString(request.data?.requestMessage, 'requestMessage');
  if (requestMessage.length > 2000) {
    throw new HttpsError('invalid-argument', 'requestMessage is too long (max 2000 chars).');
  }

  // schedule/addressSnapshot are intentionally permissive for MVP; validate in app + tighten later.
  const schedule = request.data?.schedule ?? null;
  const addressSnapshot = request.data?.addressSnapshot ?? null;
  const audioMessageUrl = typeof request.data?.audioMessageUrl === 'string'
    ? request.data.audioMessageUrl.trim()
    : null;
  // Only accept a Firebase Storage URL that lives in the caller's own
  // booking-voice folder — prevents storing arbitrary/phishing URLs that the
  // provider would later open.
  if (audioMessageUrl !== null) {
    const okHost = audioMessageUrl.startsWith('https://firebasestorage.googleapis.com/');
    const okOwner = audioMessageUrl.includes(uid);
    if (!okHost || !okOwner) {
      throw new HttpsError('invalid-argument', 'audioMessageUrl is not a valid booking voice URL.');
    }
  }
  const scheduledAtRaw = request.data?.scheduledAt ?? null;
  let scheduledAt: admin.firestore.Timestamp | null = null;
  if (scheduledAtRaw) {
    const parsed = new Date(scheduledAtRaw);
    if (isNaN(parsed.getTime())) {
      throw new HttpsError('invalid-argument', 'scheduledAt is not a valid date.');
    }
    if (parsed.getTime() < Date.now()) {
      throw new HttpsError('invalid-argument', 'scheduledAt must be in the future.');
    }
    scheduledAt = admin.firestore.Timestamp.fromDate(parsed);
  }

  const bookingRef = db.collection('bookings').doc();

  await db.runTransaction(async (tx) => {
    // Validate the target service exists, is published, and belongs to the
    // claimed provider — and that the provider is not suspended. Prevents
    // bookings against fantom/unpublished services or suspended providers.
    const serviceSnap = await tx.get(db.collection('services').doc(serviceId));
    if (!serviceSnap.exists) {
      throw new HttpsError('not-found', 'Service not found.');
    }
    const service = serviceSnap.data() as { providerId?: string; published?: boolean };
    if (service.providerId !== providerId) {
      throw new HttpsError('failed-precondition', 'Service does not belong to this provider.');
    }
    if (service.published !== true) {
      throw new HttpsError('failed-precondition', 'Service is not published.');
    }

    const providerSnap = await tx.get(db.collection('providers').doc(providerId));
    if (providerSnap.exists && (providerSnap.data() as { suspended?: boolean }).suspended === true) {
      throw new HttpsError('failed-precondition', 'Provider is currently unavailable.');
    }

    tx.set(bookingRef, {
      customerId: uid,
      providerId,
      serviceId,
      status: 'requested' as BookingStatus,
      requestMessage,
      scheduledAt,
      schedule,
      addressSnapshot,
      ...(audioMessageUrl ? { audioMessageUrl } : {}),
      reminded24h: false,
      reminded1h: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  return { bookingId: bookingRef.id };
});

export const acceptBooking = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const bookingId = requireString(request.data?.bookingId, 'bookingId');
  const bookingRef = db.collection('bookings').doc(bookingId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Booking not found.');

    const booking = snap.data() as {
      customerId?: string;
      providerId?: string;
      status?: BookingStatus;
      chatId?: string;
    };

    if (!booking.providerId || !booking.customerId) {
      throw new HttpsError('failed-precondition', 'Booking is missing required fields.');
    }

    if (booking.status !== 'requested') {
      throw new HttpsError(
        'failed-precondition',
        `Booking is not requested (status=${booking.status ?? 'unknown'}).`
      );
    }

    // Provider-only accept (admins can bypass)
    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin && booking.providerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the provider can accept this booking.');
    }

    const chatId = booking.chatId ?? chatIdForBooking(bookingId);
    const chatRef = db.collection('chats').doc(chatId);

    // Create chat only on accept (booking-gated chat)
    tx.set(
      chatRef,
      {
        bookingId,
        participantIds: [booking.customerId, booking.providerId],
        customerId: booking.customerId,
        providerId: booking.providerId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: null
      },
      { merge: true }
    );

    tx.update(bookingRef, {
      status: 'accepted' as BookingStatus,
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      chatId
    });

    return { bookingId, chatId };
  });

  return result;
});

export const rejectBooking = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const bookingId = requireString(request.data?.bookingId, 'bookingId');
  const bookingRef = db.collection('bookings').doc(bookingId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Booking not found.');

    const booking = snap.data() as {
      providerId?: string;
      status?: BookingStatus;
    };

    if (!booking.providerId) {
      throw new HttpsError('failed-precondition', 'Booking is missing providerId.');
    }

    if (booking.status !== 'requested') {
      throw new HttpsError(
        'failed-precondition',
        `Booking is not requested (status=${booking.status ?? 'unknown'}).`
      );
    }

    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin && booking.providerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the provider can reject this booking.');
    }

    // IMPORTANT: do NOT create a chat on reject.
    tx.update(bookingRef, {
      status: 'rejected' as BookingStatus,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { bookingId };
  });

  return result;
});

export const onMessageCreate = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const { chatId } = event.params;
    const message = event.data?.data() as {
      senderId?: string;
      text?: string;
      type?: string;
      mediaUrl?: string;
    } | undefined;

    if (!message) return;

    // Get chat to find participants and bookingId
    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;
    const chat = chatSnap.data() as {
      participantIds?: string[];
      bookingId?: string;
    };
    const participants = chat.participantIds ?? [];
    const bookingId = chat.bookingId;

    // Update lastMessageAt on the chat document
    await db.collection('chats').doc(chatId).update({
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify all participants except the sender
    const recipients = participants.filter(uid => uid !== message.senderId);
    const notifTitle = 'Nouveau message';
    const msgType = message.type as string | undefined;
    let notifBody: string;
    if (msgType === 'image') {
      notifBody = 'A envoy\u00e9 une image \ud83d\udcf7';
    } else if (msgType === 'voice') {
      notifBody = 'A envoy\u00e9 un message vocal \ud83c\udfa4';
    } else {
      notifBody = (message.text as string | undefined) ?? 'Message re\u00e7u';
    }

    await sendPushToUsers(
      recipients,
      { title: notifTitle, body: notifBody },
      {
        type: 'new_message',
        chatId,
        ...(bookingId ? { bookingId } : {}),
      }
    );

    for (const uid of recipients) {
      await createNotification(uid, {
        type: 'new_message',
        title: notifTitle,
        body: notifBody,
        chatId,
        bookingId,
      });
    }
  }
);

export const onBookingStatusChange = onDocumentUpdated(
  'bookings/{bookingId}',
  async (event) => {
    const before = event.data?.before.data() as {
      status?: string;
      customerId?: string;
      providerId?: string;
    } | undefined;
    const after = event.data?.after.data() as {
      status?: string;
      customerId?: string;
      providerId?: string;
    } | undefined;

    if (!before || !after) return;
    if (before.status === after.status) return;

    const { customerId, providerId } = after;
    const status = after.status;

    logger.info('Booking status changed', { from: before.status, to: status });

    const bookingId = event.params.bookingId;

    type NotifEntry = {
      uids: string[];
      type: string;
      title: string;
      body: string;
    };
    const notifications: NotifEntry[] = [];

    switch (status) {
      case 'accepted':
        if (customerId) {
          notifications.push({
            uids: [customerId],
            type: 'booking_accepted',
            title: 'Demande acceptée',
            body: 'Votre prestataire a accepté votre demande. Vous pouvez maintenant discuter.',
          });
        }
        break;
      case 'rejected':
        if (customerId) {
          notifications.push({
            uids: [customerId],
            type: 'booking_rejected',
            title: 'Demande refusée',
            body: 'Votre demande a été refusée. Vous pouvez en soumettre une nouvelle.',
          });
        }
        break;
      case 'in_progress':
        if (customerId) {
          notifications.push({
            uids: [customerId],
            type: 'booking_in_progress',
            title: 'Service démarré',
            body: 'Votre prestataire a démarré le service.',
          });
        }
        break;
      case 'done':
        if (customerId) {
          notifications.push({
            uids: [customerId],
            type: 'booking_done',
            title: 'Service terminé',
            body: 'Le service est terminé. Laissez un avis !',
          });
        }
        if (providerId) {
          notifications.push({
            uids: [providerId],
            type: 'booking_done',
            title: 'Service terminé',
            body: 'Le service est marqué comme terminé. Laissez un avis au client !',
          });
        }
        break;
    }

    for (const n of notifications) {
      await sendPushToUsers(
        n.uids,
        { title: n.title, body: n.body },
        { type: n.type, bookingId }
      );
      for (const uid of n.uids) {
        await createNotification(uid, {
          type: n.type,
          title: n.title,
          body: n.body,
          bookingId,
        });
      }
    }
  }
);

export const cancelBooking = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const bookingId = requireString(request.data?.bookingId, 'bookingId');
  // Optional cancellation reason (bounded). Empty string allowed.
  const reasonRaw = typeof request.data?.reason === 'string'
    ? (request.data.reason as string).trim()
    : '';
  if (reasonRaw.length > 500) {
    throw new HttpsError('invalid-argument', 'reason is too long (max 500 chars).');
  }
  const bookingRef = db.collection('bookings').doc(bookingId);

  // A booking may be cancelled by either participant while it is still active
  // (requested → before accept, or accepted/in_progress → after, with a reason).
  // done/rejected/cancelled are terminal.
  const cancellable: BookingStatus[] = ['requested', 'accepted', 'in_progress'];

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Booking not found.');

    const booking = snap.data() as {
      customerId?: string;
      providerId?: string;
      status?: BookingStatus;
    };

    if (!booking.customerId || !booking.providerId) {
      throw new HttpsError('failed-precondition', 'Booking is missing required fields.');
    }

    if (!cancellable.includes(booking.status as BookingStatus)) {
      throw new HttpsError(
        'failed-precondition',
        `Booking cannot be cancelled from status=${booking.status ?? 'unknown'}.`
      );
    }

    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin && booking.customerId !== uid && booking.providerId !== uid) {
      throw new HttpsError('permission-denied', 'Only a booking participant can cancel.');
    }

    tx.update(bookingRef, {
      status: 'cancelled' as BookingStatus,
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: uid,
      ...(reasonRaw ? { cancelReason: reasonRaw } : {}),
    });

    return { bookingId };
  });

  return result;
});

export const markInProgress = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const bookingId = requireString(request.data?.bookingId, 'bookingId');
  const bookingRef = db.collection('bookings').doc(bookingId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Booking not found.');

    const booking = snap.data() as {
      providerId?: string;
      status?: BookingStatus;
    };

    if (!booking.providerId) {
      throw new HttpsError('failed-precondition', 'Booking is missing providerId.');
    }

    if (booking.status !== 'accepted') {
      throw new HttpsError(
        'failed-precondition',
        `Booking is not accepted (status=${booking.status ?? 'unknown'}).`
      );
    }

    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin && booking.providerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the provider can mark a booking in progress.');
    }

    tx.update(bookingRef, {
      status: 'in_progress' as BookingStatus,
      startedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { bookingId };
  });

  return result;
});

export const confirmDone = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const bookingId = requireString(request.data?.bookingId, 'bookingId');
  const bookingRef = db.collection('bookings').doc(bookingId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Booking not found.');

    const booking = snap.data() as {
      customerId?: string;
      status?: BookingStatus;
    };

    if (!booking.customerId) {
      throw new HttpsError('failed-precondition', 'Booking is missing customerId.');
    }

    if (booking.status !== 'in_progress') {
      throw new HttpsError(
        'failed-precondition',
        `Booking is not in_progress (status=${booking.status ?? 'unknown'}).`
      );
    }

    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin && booking.customerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the client can confirm the booking as done.');
    }

    tx.update(bookingRef, {
      status: 'done' as BookingStatus,
      doneAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { bookingId };
  });

  return result;
});

// ---------------------------------------------------------------------------
// Account self-deletion (App Store 5.1.1(v) / Google Play requirement)
// Server-authoritative: purges the user's auth account + personal data.
// ---------------------------------------------------------------------------
export const deleteMyAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  // Delete owned services (a provider's listings) + provider profile + user doc
  // in a batch. Booking/review/chat history is retained but de-referenced; the
  // personal profile and credentials are removed.
  const services = await db
    .collection('services')
    .where('providerId', '==', uid)
    .get();

  const batch = db.batch();
  services.forEach((d) => batch.delete(d.ref));
  batch.delete(db.collection('providers').doc(uid));
  batch.delete(db.collection('users').doc(uid));
  await batch.commit();

  // Best-effort cleanup of the user's avatar folder.
  try {
    await admin.storage().bucket().deleteFiles({
      prefix: `private/users/${uid}/`,
    });
  } catch (e) {
    console.warn(`deleteMyAccount: avatar cleanup failed for ${uid}: ${e}`);
  }

  // Remove the Firebase Auth account last so the client is fully signed out.
  await admin.auth().deleteUser(uid);

  return { deleted: true };
});

// ---------------------------------------------------------------------------
// Personal data export (RGPD right to portability)
// ---------------------------------------------------------------------------
export const exportMyData = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const [user, provider, services, bkCustomer, bkProvider, revWritten, revReceived] =
    await Promise.all([
      db.collection('users').doc(uid).get(),
      db.collection('providers').doc(uid).get(),
      db.collection('services').where('providerId', '==', uid).get(),
      db.collection('bookings').where('customerId', '==', uid).get(),
      db.collection('bookings').where('providerId', '==', uid).get(),
      db.collection('reviews').where('reviewerId', '==', uid).get(),
      db.collection('reviews').where('revieweeId', '==', uid).get(),
    ]);

  const one = (s: admin.firestore.DocumentSnapshot) =>
    s.exists ? { id: s.id, ...s.data() } : null;
  const many = (q: admin.firestore.QuerySnapshot) =>
    q.docs.map((d) => ({ id: d.id, ...d.data() }));

  return {
    exportedAt: new Date().toISOString(),
    user: one(user),
    providerProfile: one(provider),
    services: many(services),
    bookingsAsCustomer: many(bkCustomer),
    bookingsAsProvider: many(bkProvider),
    reviewsWritten: many(revWritten),
    reviewsReceived: many(revReceived),
  };
});

export const setAdminClaim = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);

  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');
  const isAdmin = requireBoolean(request.data?.admin, 'admin');

  // Merge with existing claims
  const user = await admin.auth().getUser(targetUid);
  const current = (user.customClaims ?? {}) as Record<string, unknown>;
  await admin.auth().setCustomUserClaims(targetUid, { ...current, admin: isAdmin });

  // Mirror role to Firestore for admin panel visibility
  await db.collection('user_roles').doc(targetUid).set({
    uid: targetUid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    admin: isAdmin,
    moderator: (current.moderator as boolean | undefined) ?? false,
    support: (current.support as boolean | undefined) ?? false,
    readonly: (current.readonly as boolean | undefined) ?? false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: isAdmin ? 'set_admin_claim' : 'revoke_admin_claim',
    targetType: 'user',
    targetId: targetUid,
  });

  return { uid: targetUid, admin: isAdmin };
});

// ---------------------------------------------------------------------------
// Scheduled: booking reminders (every 30 min)
// ---------------------------------------------------------------------------

export const sendBookingReminders = onSchedule(
  { schedule: 'every 30 minutes', timeZone: 'Europe/Paris' },
  async () => {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in24h30 = new Date(in24h.getTime() + 30 * 60 * 1000);

    // Find bookings with scheduledAt that are accepted or in_progress
    const snap = await db
      .collection('bookings')
      .where('scheduledAt', '>=', admin.firestore.Timestamp.fromDate(now))
      .where('scheduledAt', '<=', admin.firestore.Timestamp.fromDate(in24h30))
      .get();

    let sent = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const status = data.status as BookingStatus;
      if (status !== 'accepted' && status !== 'in_progress') continue;

      const scheduledAt = (data.scheduledAt as admin.firestore.Timestamp).toDate();
      const diffMs = scheduledAt.getTime() - now.getTime();
      const diffHours = diffMs / (1000 * 60 * 60);

      const participants = [data.customerId, data.providerId].filter(Boolean);

      // 24h reminder (between 23.5h and 24.5h before)
      if (!data.reminded24h && diffHours >= 23.5 && diffHours <= 24.5) {
        const timeStr = scheduledAt.toLocaleTimeString('fr-FR', {
          hour: '2-digit',
          minute: '2-digit',
        });
        // Wrap flag-check + flag-set in a transaction to prevent double-send on scheduler retry
        let shouldSend24h = false;
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(doc.ref);
          if (snap.data()?.reminded24h) return; // already processed (retry guard)
          tx.update(doc.ref, { reminded24h: true });
          shouldSend24h = true;
        });
        if (shouldSend24h) {
          await sendPushToUsers(participants, {
            title: 'Rappel — RDV demain',
            body: `Votre prestation est prévue demain à ${timeStr}.`,
          });
          for (const uid of participants) {
            await createNotification(uid, {
              type: 'booking_reminder',
              title: 'Rappel — RDV demain',
              body: `Votre prestation est prévue demain à ${timeStr}.`,
              bookingId: doc.id,
            });
          }
          sent++;
        }
      }

      // 1h reminder (between 0.5h and 1.5h before)
      if (!data.reminded1h && diffHours >= 0.5 && diffHours <= 1.5) {
        // Wrap flag-check + flag-set in a transaction to prevent double-send on scheduler retry
        let shouldSend1h = false;
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(doc.ref);
          if (snap.data()?.reminded1h) return; // already processed (retry guard)
          tx.update(doc.ref, { reminded1h: true });
          shouldSend1h = true;
        });
        if (shouldSend1h) {
          await sendPushToUsers(participants, {
            title: 'Rappel — RDV dans 1h',
            body: 'Votre prestation commence bientôt !',
          });
          for (const uid of participants) {
            await createNotification(uid, {
              type: 'booking_reminder',
              title: 'Rappel — RDV dans 1h',
              body: 'Votre prestation commence bientôt !',
              bookingId: doc.id,
            });
          }
          sent++;
        }
      }
    }

    logger.info(`Booking reminders: checked ${snap.size}, sent ${sent}`);
  }
);

// ---------------------------------------------------------------------------
// Admin audit log helper
// ---------------------------------------------------------------------------

async function writeAdminLog(data: {
  actorUid: string;
  action: string;
  targetType: string;
  targetId: string;
  notes?: string;
}): Promise<void> {
  await db.collection('admin_logs').add({
    actorUid: data.actorUid,
    action: data.action,
    targetType: data.targetType,
    targetId: data.targetId,
    notes: data.notes ?? null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ---------------------------------------------------------------------------
// setModeratorClaim — admin only
// ---------------------------------------------------------------------------

export const setModeratorClaim = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');
  const isModerator = requireBoolean(request.data?.moderator, 'moderator');

  // Merge with existing claims to avoid wiping admin claim
  const user = await admin.auth().getUser(targetUid);
  const currentClaims = (user.customClaims ?? {}) as Record<string, unknown>;
  await admin.auth().setCustomUserClaims(targetUid, { ...currentClaims, moderator: isModerator });

  // Mirror role to Firestore for admin panel visibility
  await db.collection('user_roles').doc(targetUid).set({
    uid: targetUid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    admin: (currentClaims.admin as boolean | undefined) ?? false,
    moderator: isModerator,
    support: (currentClaims.support as boolean | undefined) ?? false,
    readonly: (currentClaims.readonly as boolean | undefined) ?? false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: isModerator ? 'set_moderator_claim' : 'revoke_moderator_claim',
    targetType: 'user',
    targetId: targetUid,
  });

  return { uid: targetUid, moderator: isModerator };
});

// ---------------------------------------------------------------------------
// setSupportClaim — admin only
// ---------------------------------------------------------------------------

export const setSupportClaim = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');
  const isSupport = requireBoolean(request.data?.support, 'support');

  const user = await admin.auth().getUser(targetUid);
  const currentClaims = (user.customClaims ?? {}) as Record<string, unknown>;
  await admin.auth().setCustomUserClaims(targetUid, { ...currentClaims, support: isSupport });

  await db.collection('user_roles').doc(targetUid).set({
    uid: targetUid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    admin: (currentClaims.admin as boolean | undefined) ?? false,
    moderator: (currentClaims.moderator as boolean | undefined) ?? false,
    support: isSupport,
    readonly: (currentClaims.readonly as boolean | undefined) ?? false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: isSupport ? 'set_support_claim' : 'revoke_support_claim',
    targetType: 'user',
    targetId: targetUid,
  });

  return { uid: targetUid, support: isSupport };
});

// ---------------------------------------------------------------------------
// setReadonlyClaim — admin only
// ---------------------------------------------------------------------------

export const setReadonlyClaim = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');
  const isReadonly = requireBoolean(request.data?.readonly, 'readonly');

  const user = await admin.auth().getUser(targetUid);
  const currentClaims = (user.customClaims ?? {}) as Record<string, unknown>;
  await admin.auth().setCustomUserClaims(targetUid, { ...currentClaims, readonly: isReadonly });

  await db.collection('user_roles').doc(targetUid).set({
    uid: targetUid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    admin: (currentClaims.admin as boolean | undefined) ?? false,
    moderator: (currentClaims.moderator as boolean | undefined) ?? false,
    support: (currentClaims.support as boolean | undefined) ?? false,
    readonly: isReadonly,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: isReadonly ? 'set_readonly_claim' : 'revoke_readonly_claim',
    targetType: 'user',
    targetId: targetUid,
  });

  return { uid: targetUid, readonly: isReadonly };
});

// ---------------------------------------------------------------------------
// suspendProvider — admin or moderator
// ---------------------------------------------------------------------------

export const suspendProvider = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const targetUid = requireString(request.data?.uid, 'uid');
  const reason = typeof request.data?.reason === 'string' ? request.data.reason.trim() : null;

  const providerRef = db.collection('providers').doc(targetUid);

  // Read the published services BEFORE the transaction to get their refs.
  // The transaction then re-reads the provider doc atomically before writing,
  // ensuring the suspend + service unpublish are a single atomic operation.
  const servicesSnap = await db
    .collection('services')
    .where('providerId', '==', targetUid)
    .where('published', '==', true)
    .get();

  const serviceRefs = servicesSnap.docs.map(d => d.ref);

  await db.runTransaction(async (tx) => {
    const providerSnap = await tx.get(providerRef);
    if (!providerSnap.exists) {
      throw new HttpsError('not-found', 'Provider not found.');
    }

    // Re-read each service doc inside the transaction for atomicity
    const serviceSnaps = await Promise.all(serviceRefs.map(ref => tx.get(ref)));

    tx.update(providerRef, {
      suspended: true,
      suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
      suspendedReason: reason,
    });
    for (const snap of serviceSnaps) {
      if (snap.exists) {
        tx.update(snap.ref, { published: false });
      }
    }
  });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'suspend_provider',
    targetType: 'provider',
    targetId: targetUid,
    notes: reason ?? undefined,
  });

  return { uid: targetUid, suspended: true, servicesUnpublished: servicesSnap.size };
});

// ---------------------------------------------------------------------------
// unsuspendProvider — admin only
// ---------------------------------------------------------------------------

export const unsuspendProvider = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');

  const providerRef = db.collection('providers').doc(targetUid);
  const providerSnap = await providerRef.get();
  if (!providerSnap.exists) {
    throw new HttpsError('not-found', 'Provider not found.');
  }

  await providerRef.update({
    suspended: false,
    suspendedAt: admin.firestore.FieldValue.delete(),
    suspendedReason: admin.firestore.FieldValue.delete(),
  });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'unsuspend_provider',
    targetType: 'provider',
    targetId: targetUid,
  });

  return { uid: targetUid, suspended: false };
});

// ---------------------------------------------------------------------------
// removeService — admin or moderator
// ---------------------------------------------------------------------------

export const removeService = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const serviceId = requireString(request.data?.serviceId, 'serviceId');

  const serviceRef = db.collection('services').doc(serviceId);
  const serviceSnap = await serviceRef.get();
  if (!serviceSnap.exists) {
    throw new HttpsError('not-found', 'Service not found.');
  }

  await serviceRef.update({ published: false });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'remove_service',
    targetType: 'service',
    targetId: serviceId,
  });

  return { serviceId, published: false };
});

// ---------------------------------------------------------------------------
// deleteMessage — admin or moderator (soft delete)
// ---------------------------------------------------------------------------

export const deleteMessage = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const chatId = requireString(request.data?.chatId, 'chatId');
  const messageId = requireString(request.data?.messageId, 'messageId');

  const messageRef = db.collection('chats').doc(chatId).collection('messages').doc(messageId);
  const messageSnap = await messageRef.get();
  if (!messageSnap.exists) {
    throw new HttpsError('not-found', 'Message not found.');
  }

  await messageRef.update({
    deleted: true,
    text: admin.firestore.FieldValue.delete(),
    mediaUrl: admin.firestore.FieldValue.delete(),
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    deletedBy: callerUid,
  });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'delete_message',
    targetType: 'message',
    targetId: `${chatId}/messages/${messageId}`,
  });

  return { chatId, messageId, deleted: true };
});

// ---------------------------------------------------------------------------
// resolveReport — admin or moderator
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// revokeUserSessions — admin only
// Forces token refresh on all sessions for the target user.
// ---------------------------------------------------------------------------

export const revokeUserSessions = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');

  // Revoke all refresh tokens — forces re-authentication on all devices.
  await admin.auth().revokeRefreshTokens(targetUid);

  await writeAdminLog({
    actorUid: callerUid,
    action: 'revoke_sessions',
    targetType: 'user',
    targetId: targetUid,
  });

  return { uid: targetUid, revoked: true };
});

// ---------------------------------------------------------------------------
// logSession — called by the mobile app on every sign-in
// ---------------------------------------------------------------------------

export const logSession = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const platform = requireString(request.data?.platform, 'platform');
  if (!['android', 'ios', 'web'].includes(platform)) {
    throw new HttpsError('invalid-argument', "platform must be 'android', 'ios', or 'web'.");
  }
  const deviceModel =
    typeof request.data?.deviceModel === 'string' ? request.data.deviceModel.trim() : null;
  const appVersion =
    typeof request.data?.appVersion === 'string' ? request.data.appVersion.trim() : null;
  const sessionId =
    typeof request.data?.sessionId === 'string' ? request.data.sessionId.trim() : null;

  // Extract client IP (Cloud Run sets x-forwarded-for)
  const rawIp =
    (request.rawRequest.headers['x-forwarded-for'] as string | undefined)
      ?.split(',')[0]
      ?.trim() ?? request.rawRequest.socket?.remoteAddress ?? null;
  const ip = rawIp === '::1' || rawIp === '127.0.0.1' ? null : rawIp;

  // Geolocate IP via ipapi.co (cached in Firestore to stay within free tier)
  let country: string | null = null;
  let countryCode: string | null = null;
  let city: string | null = null;
  let region: string | null = null;
  let isp: string | null = null;
  let asn: string | null = null;
  let latitude: number | null = null;
  let longitude: number | null = null;
  if (ip) {
    const geo = await getGeoForIp(ip);
    country = geo.country;
    countryCode = geo.countryCode;
    city = geo.city;
    region = geo.region;
    isp = geo.isp;
    asn = geo.asn;
    latitude = geo.latitude;
    longitude = geo.longitude;
  }

  // Check IP against blocklist
  if (ip) {
    const blockSnap = await db.collection('ip_blocklist')
      .where('ip', '==', ip)
      .where('active', '==', true)
      .limit(1)
      .get();
    if (!blockSnap.empty) {
      logger.warn('Blocked IP login attempt', { uid, ip });
      await db.collection('security_alerts').add({
        uid,
        type: 'blocked_ip_login',
        severity: 'high',
        ip,
        country,
        countryCode,
        city,
        latitude,
        longitude,
        description: `Login attempt from blocked IP ${ip}`,
        status: 'open',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        resolvedAt: null,
        resolvedBy: null,
      });
      throw new HttpsError('permission-denied', 'Access denied.');
    }
  }

  const sessionRef = db.collection('user_sessions').doc(uid);
  const eventRef = sessionRef.collection('events').doc();

  const eventData = {
    uid,
    ip,
    country,
    countryCode,
    city,
    region,
    isp,
    asn,
    latitude,
    longitude,
    platform,
    deviceModel,
    appVersion,
    sessionId,
    loggedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(eventRef, eventData);
  batch.set(
    sessionRef,
    {
      uid,
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      lastIp: ip,
      lastCountry: country,
      lastCountryCode: countryCode,
      lastCity: city,
      lastPlatform: platform,
      lastLatitude: latitude,
      lastLongitude: longitude,
    },
    { merge: true }
  );
  await batch.commit();

  // Anomaly detection (async, non-blocking — failures logged but don't block login)
  detectAnomalies(uid, eventData).catch((e) =>
    logger.warn('Anomaly detection failed', { uid, error: String(e) })
  );

  return { logged: true };
});

// ---------------------------------------------------------------------------
// resolveReport — admin or moderator
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Moderation queue — service pre-publication workflow
// ---------------------------------------------------------------------------

export const submitServiceForReview = onCall(async (request) => {
  const uid = request.auth?.uid;
  assertAuthenticated(uid);

  const serviceId = requireString(request.data?.serviceId, 'serviceId');

  const serviceRef = db.collection('services').doc(serviceId);
  const serviceSnap = await serviceRef.get();
  if (!serviceSnap.exists) {
    throw new HttpsError('not-found', 'Service not found.');
  }

  const service = serviceSnap.data() as { providerId?: string };
  if (service.providerId !== uid) {
    throw new HttpsError('permission-denied', 'Only the service owner can submit for review.');
  }

  await serviceRef.update({ published: false, status: 'pending_review' });

  await db.collection('moderation_queue').add({
    serviceId,
    providerId: uid,
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
    reviewedBy: null,
    reviewedAt: null,
    rejectionReason: null,
  });

  return { serviceId, status: 'pending_review' };
});

export const approveService = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertMinSupportClaim(request.auth?.token as Record<string, unknown> | undefined);

  const queueItemId = requireString(request.data?.queueItemId, 'queueItemId');

  const queueRef = db.collection('moderation_queue').doc(queueItemId);
  const queueSnap = await queueRef.get();
  if (!queueSnap.exists) {
    throw new HttpsError('not-found', 'Queue item not found.');
  }

  const item = queueSnap.data() as { serviceId: string; status: string };
  if (item.status !== 'pending') {
    throw new HttpsError('failed-precondition', `Item is already ${item.status}.`);
  }

  const batch = db.batch();
  batch.update(queueRef, {
    status: 'approved',
    reviewedBy: callerUid,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.update(db.collection('services').doc(item.serviceId), {
    published: true,
    status: 'approved',
  });
  await batch.commit();

  await writeAdminLog({
    actorUid: callerUid,
    action: 'approve_service',
    targetType: 'service',
    targetId: item.serviceId,
  });

  return { queueItemId, serviceId: item.serviceId, status: 'approved' };
});

export const republishService = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const serviceId = requireString(request.data?.serviceId, 'serviceId');

  const serviceRef = db.collection('services').doc(serviceId);
  const serviceSnap = await serviceRef.get();
  if (!serviceSnap.exists) {
    throw new HttpsError('not-found', 'Service not found.');
  }

  const service = serviceSnap.data() as { status?: string; published?: boolean };

  if (service.status === 'rejected' || service.status === 'pending_review') {
    throw new HttpsError(
      'permission-denied',
      `Service has moderation status "${service.status}" — it must go through the moderation queue before republication.`
    );
  }

  await serviceRef.update({ published: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'republish_service',
    targetType: 'service',
    targetId: serviceId,
  });

  return { serviceId, published: true };
});

export const rejectService = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertMinSupportClaim(request.auth?.token as Record<string, unknown> | undefined);

  const queueItemId = requireString(request.data?.queueItemId, 'queueItemId');
  const reason = typeof request.data?.reason === 'string' ? request.data.reason.trim() : '';
  if (!reason) {
    throw new HttpsError('invalid-argument', 'A rejection reason is required.');
  }

  const queueRef = db.collection('moderation_queue').doc(queueItemId);
  const queueSnap = await queueRef.get();
  if (!queueSnap.exists) {
    throw new HttpsError('not-found', 'Queue item not found.');
  }

  const item = queueSnap.data() as { serviceId: string; status: string };
  if (item.status !== 'pending') {
    throw new HttpsError('failed-precondition', `Item is already ${item.status}.`);
  }

  const batch = db.batch();
  batch.update(queueRef, {
    status: 'rejected',
    reviewedBy: callerUid,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    rejectionReason: reason,
  });
  batch.update(db.collection('services').doc(item.serviceId), {
    published: false,
    status: 'rejected',
  });
  await batch.commit();

  await writeAdminLog({
    actorUid: callerUid,
    action: 'reject_service',
    targetType: 'service',
    targetId: item.serviceId,
    notes: reason,
  });

  return { queueItemId, serviceId: item.serviceId, status: 'rejected' };
});

// ---------------------------------------------------------------------------
// User bans — suspend / ban / shadow-ban
// ---------------------------------------------------------------------------

export const banUser = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');
  const reason = requireString(request.data?.reason, 'reason');

  await admin.auth().updateUser(targetUid, { disabled: true });

  await db.collection('user_bans').doc(targetUid).set({
    userId: targetUid,
    type: 'banned',
    reason,
    bannedBy: callerUid,
    bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: null,
    liftedAt: null,
    liftedBy: null,
  });

  await db.collection('users').doc(targetUid).update({ isBanned: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'ban_user',
    targetType: 'user',
    targetId: targetUid,
    notes: reason,
  });

  return { uid: targetUid, type: 'banned' };
});

export const unbanUser = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const targetUid = requireString(request.data?.uid, 'uid');

  await admin.auth().updateUser(targetUid, { disabled: false });

  await db.collection('user_bans').doc(targetUid).update({
    liftedAt: admin.firestore.FieldValue.serverTimestamp(),
    liftedBy: callerUid,
  });

  // Only clear isBanned — shadow-ban state is independent and must be lifted
  // explicitly via a separate action (shadowBanUser sets it, no auto-clear here).
  await db.collection('users').doc(targetUid).update({
    isBanned: false,
  });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'unban',
    targetType: 'user',
    targetId: targetUid,
  });

  return { uid: targetUid, unbanned: true };
});

export const shadowBanUser = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const targetUid = requireString(request.data?.uid, 'uid');
  const reason = requireString(request.data?.reason, 'reason');

  await db.collection('user_bans').doc(targetUid).set({
    userId: targetUid,
    type: 'shadow_banned',
    reason,
    bannedBy: callerUid,
    bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: null,
    liftedAt: null,
    liftedBy: null,
  });

  await db.collection('users').doc(targetUid).update({ isShadowBanned: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'shadow_ban_user',
    targetType: 'user',
    targetId: targetUid,
    notes: reason,
  });

  return { uid: targetUid, type: 'shadow_banned' };
});

export const suspendUser = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertMinSupportClaim(request.auth?.token as Record<string, unknown> | undefined);

  const targetUid = requireString(request.data?.uid, 'uid');
  const reason = requireString(request.data?.reason, 'reason');
  const expiresAtRaw = request.data?.expiresAt;

  let expiresAt: admin.firestore.Timestamp | null = null;
  if (expiresAtRaw) {
    const parsed = new Date(expiresAtRaw);
    if (isNaN(parsed.getTime())) {
      throw new HttpsError('invalid-argument', 'expiresAt is not a valid date.');
    }
    if (parsed.getTime() < Date.now()) {
      throw new HttpsError('invalid-argument', 'expiresAt must be in the future.');
    }
    expiresAt = admin.firestore.Timestamp.fromDate(parsed);
  }

  await db.collection('user_bans').doc(targetUid).set({
    userId: targetUid,
    type: 'suspended',
    reason,
    bannedBy: callerUid,
    bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
    liftedAt: null,
    liftedBy: null,
  });

  await db.collection('users').doc(targetUid).update({ isSuspended: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'suspend_user',
    targetType: 'user',
    targetId: targetUid,
    notes: reason,
  });

  return { uid: targetUid, type: 'suspended' };
});

// ---------------------------------------------------------------------------
// Review moderation — hide / unhide / delete
// ---------------------------------------------------------------------------

export const hideReview = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const reviewId = requireString(request.data?.reviewId, 'reviewId');
  const reviewRef = db.collection('reviews').doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) {
    throw new HttpsError('not-found', 'Review not found.');
  }

  await reviewRef.update({ hidden: true });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'hide_review',
    targetType: 'review',
    targetId: reviewId,
  });

  return { reviewId, hidden: true };
});

export const unhideReview = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const reviewId = requireString(request.data?.reviewId, 'reviewId');
  const reviewRef = db.collection('reviews').doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) {
    throw new HttpsError('not-found', 'Review not found.');
  }

  await reviewRef.update({ hidden: false });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'unhide_review',
    targetType: 'review',
    targetId: reviewId,
  });

  return { reviewId, hidden: false };
});

export const deleteReview = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const reviewId = requireString(request.data?.reviewId, 'reviewId');
  const reviewRef = db.collection('reviews').doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) {
    throw new HttpsError('not-found', 'Review not found.');
  }

  await reviewRef.delete();

  await writeAdminLog({
    actorUid: callerUid,
    action: 'delete_review',
    targetType: 'review',
    targetId: reviewId,
  });

  return { reviewId, deleted: true };
});

// ---------------------------------------------------------------------------
// resolveReport — admin or moderator
// ---------------------------------------------------------------------------

export const resolveReport = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertMinSupportClaim(request.auth?.token as Record<string, unknown> | undefined);

  const reportId = requireString(request.data?.reportId, 'reportId');
  const action = requireString(request.data?.action, 'action');
  if (action !== 'resolved' && action !== 'rejected') {
    throw new HttpsError('invalid-argument', "action must be 'resolved' or 'rejected'.");
  }
  const notes = typeof request.data?.notes === 'string' ? request.data.notes.trim() : null;

  const reportRef = db.collection('reports').doc(reportId);
  const reportSnap = await reportRef.get();
  if (!reportSnap.exists) {
    throw new HttpsError('not-found', 'Report not found.');
  }

  const report = reportSnap.data() as { status?: string };
  if (report.status !== 'open') {
    throw new HttpsError('failed-precondition', `Report is already ${report.status ?? 'closed'}.`);
  }

  await reportRef.update({
    status: action,
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    resolvedBy: callerUid,
    resolutionNotes: notes,
  });

  await writeAdminLog({
    actorUid: callerUid,
    action: `resolve_report_${action}`,
    targetType: 'report',
    targetId: reportId,
    notes: notes ?? undefined,
  });

  return { reportId, status: action };
});

// ---------------------------------------------------------------------------
// Security — anomaly detection (called internally from logSession)
// ---------------------------------------------------------------------------

async function detectAnomalies(
  uid: string,
  currentEvent: {
    ip: string | null;
    countryCode: string | null;
    city: string | null;
    latitude: number | null;
    longitude: number | null;
  }
): Promise<void> {
  if (!currentEvent.ip || !currentEvent.countryCode) return;

  const alerts: Array<{
    type: string;
    severity: string;
    description: string;
  }> = [];

  // Fetch last 10 session events for this user (excluding the one just written)
  const recentSnap = await db
    .collection('user_sessions')
    .doc(uid)
    .collection('events')
    .orderBy('loggedAt', 'desc')
    .limit(11)
    .get();

  const recentEvents = recentSnap.docs
    .map((d) => d.data())
    .filter((e: Record<string, unknown>) =>
      e.ip !== currentEvent.ip || e.countryCode !== currentEvent.countryCode
    );

  if (recentEvents.length === 0) return;

  const lastEvent = recentEvents[0];

  // 1. Impossible travel: different geo with implausible time gap
  if (
    lastEvent &&
    currentEvent.latitude != null &&
    currentEvent.longitude != null &&
    lastEvent.latitude != null &&
    lastEvent.longitude != null &&
    lastEvent.loggedAt
  ) {
    const distKm = haversineKm(
      currentEvent.latitude,
      currentEvent.longitude,
      lastEvent.latitude as number,
      lastEvent.longitude as number
    );
    const lastTime = (lastEvent.loggedAt as admin.firestore.Timestamp).toDate();
    const timeDiffHours = (Date.now() - lastTime.getTime()) / (1000 * 60 * 60);
    // Max plausible speed: ~900 km/h (commercial flight)
    if (timeDiffHours > 0 && distKm / timeDiffHours > 900) {
      alerts.push({
        type: 'impossible_travel',
        severity: 'high',
        description: `${Math.round(distKm)} km in ${timeDiffHours.toFixed(1)}h (${lastEvent.city ?? lastEvent.countryCode} → ${currentEvent.city ?? currentEvent.countryCode})`,
      });
    }
  }

  // 2. Unusual country: not seen in last 10 sessions
  const knownCountries = new Set(
    recentEvents
      .map((e: Record<string, unknown>) => e.countryCode as string | null)
      .filter((c): c is string => c != null)
  );
  if (!knownCountries.has(currentEvent.countryCode)) {
    alerts.push({
      type: 'unusual_country',
      severity: 'medium',
      description: `First login from ${currentEvent.countryCode} (known: ${[...knownCountries].join(', ')})`,
    });
  }

  // Write alerts
  for (const alert of alerts) {
    await db.collection('security_alerts').add({
      uid,
      type: alert.type,
      severity: alert.severity,
      ip: currentEvent.ip,
      country: null,
      countryCode: currentEvent.countryCode,
      city: currentEvent.city,
      latitude: currentEvent.latitude,
      longitude: currentEvent.longitude,
      description: alert.description,
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedAt: null,
      resolvedBy: null,
    });
  }

  if (alerts.length > 0) {
    logger.warn('Security anomalies detected', { uid, count: alerts.length });
  }
}

function haversineKm(
  lat1: number, lon1: number,
  lat2: number, lon2: number
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ---------------------------------------------------------------------------
// Security — resolve alert (admin only)
// ---------------------------------------------------------------------------

export const resolveSecurityAlert = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const alertId = requireString(request.data?.alertId, 'alertId');
  const notes = typeof request.data?.notes === 'string' ? request.data.notes.trim() : null;

  const alertRef = db.collection('security_alerts').doc(alertId);
  const alertSnap = await alertRef.get();
  if (!alertSnap.exists) {
    throw new HttpsError('not-found', 'Alert not found.');
  }

  const alert = alertSnap.data() as { status?: string };
  if (alert.status !== 'open') {
    throw new HttpsError('failed-precondition', `Alert is already ${alert.status ?? 'closed'}.`);
  }

  await alertRef.update({
    status: 'resolved',
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    resolvedBy: callerUid,
    resolutionNotes: notes,
  });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'resolve_security_alert',
    targetType: 'security_alert',
    targetId: alertId,
    notes: notes ?? undefined,
  });

  return { alertId, status: 'resolved' };
});

// ---------------------------------------------------------------------------
// Security — IP blocklist management (admin only)
// ---------------------------------------------------------------------------

export const addToIpBlocklist = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const ip = requireString(request.data?.ip, 'ip');
  const reason = typeof request.data?.reason === 'string' ? request.data.reason.trim() : null;

  const existing = await db.collection('ip_blocklist')
    .where('ip', '==', ip)
    .where('active', '==', true)
    .limit(1)
    .get();

  if (!existing.empty) {
    throw new HttpsError('already-exists', `IP ${ip} is already blocked.`);
  }

  const ref = await db.collection('ip_blocklist').add({
    ip,
    reason,
    active: true,
    addedBy: callerUid,
    addedAt: admin.firestore.FieldValue.serverTimestamp(),
    removedAt: null,
    removedBy: null,
  });

  await writeAdminLog({
    actorUid: callerUid,
    action: 'add_ip_blocklist',
    targetType: 'ip',
    targetId: ip,
    notes: reason ?? undefined,
  });

  return { id: ref.id, ip, blocked: true };
});

export const removeFromIpBlocklist = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const entryId = requireString(request.data?.entryId, 'entryId');

  const entryRef = db.collection('ip_blocklist').doc(entryId);
  const entrySnap = await entryRef.get();
  if (!entrySnap.exists) {
    throw new HttpsError('not-found', 'Blocklist entry not found.');
  }

  await entryRef.update({
    active: false,
    removedAt: admin.firestore.FieldValue.serverTimestamp(),
    removedBy: callerUid,
  });

  const ip = (entrySnap.data() as { ip?: string }).ip ?? entryId;

  await writeAdminLog({
    actorUid: callerUid,
    action: 'remove_ip_blocklist',
    targetType: 'ip',
    targetId: ip,
  });

  return { entryId, blocked: false };
});

// ---------------------------------------------------------------------------
// Security — scheduled: purge expired session data (runs daily at 3am Paris)
// ---------------------------------------------------------------------------

export const purgeExpiredSessionData = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'Europe/Paris' },
  async () => {
    const retentionDays = 90;
    const cutoff = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

    const expiredSnap = await db
      .collectionGroup('events')
      .where('loggedAt', '<', cutoffTs)
      .limit(500)
      .get();

    if (expiredSnap.empty) {
      logger.info('Session purge: no expired events.');
      return;
    }

    const batch = db.batch();
    for (const doc of expiredSnap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();

    logger.info(`Session purge: deleted ${expiredSnap.size} events older than ${retentionDays} days.`);
  }
);

// ---------------------------------------------------------------------------
// Scheduled: purge old IP geo cache entries (daily at 4am Paris)
// ---------------------------------------------------------------------------

export const purgeIpGeoCache = onSchedule(
  { schedule: 'every day 04:00', timeZone: 'Europe/Paris' },
  async () => {
    const maxAgeDays = 30;
    const cutoff = new Date(Date.now() - maxAgeDays * 24 * 60 * 60 * 1000);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

    const oldEntries = await db
      .collection('ip_geo_cache')
      .where('cachedAt', '<', cutoffTs)
      .limit(500)
      .get();

    if (oldEntries.empty) {
      logger.info('IP geo cache purge: nothing to delete.');
      return;
    }

    const batch = db.batch();
    for (const doc of oldEntries.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();

    logger.info(`IP geo cache purge: deleted ${oldEntries.size} entries older than ${maxAgeDays} days.`);
  }
);

// ---------------------------------------------------------------------------
// Platform stats — incremental counters maintained by triggers
//
// Idempotency: Firebase Gen2 triggers can be retried on failure. Without
// deduplication, FieldValue.increment would double-count on retries.
// Each trigger uses a `processed_events/{eventId}` document as a dedup key.
// The dedup doc + counter increment are written in a single transaction.
//
// Cleanup: processed_events documents should be purged after 7 days.
// Use a Firestore TTL policy on the `processedAt` field, or add a scheduled
// Cloud Function. Without cleanup the collection grows unboundedly.
// ---------------------------------------------------------------------------

const STATS_REF = db.collection('platform_stats').doc('global');

/** Atomically increment a stats field, guarded by a dedup event document. */
async function incrementStatIdempotent(
  eventId: string,
  eventType: string,
  statsUpdate: Record<string, admin.firestore.FieldValue>,
): Promise<void> {
  const dedupRef = db.doc(`processed_events/${eventId}`);
  await db.runTransaction(async (tx) => {
    const dedup = await tx.get(dedupRef);
    if (dedup.exists) return; // already processed — Firebase retry guard
    tx.set(dedupRef, {
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      type: eventType,
    });
    tx.set(STATS_REF, { ...statsUpdate, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  });
}

export const onUserCreated = onDocumentCreated('users/{userId}', async (event) => {
  await incrementStatIdempotent(event.id, 'user_created', {
    totalUsers: admin.firestore.FieldValue.increment(1),
  });
});

export const onProviderCreated = onDocumentCreated('providers/{providerId}', async (event) => {
  await incrementStatIdempotent(event.id, 'provider_created', {
    totalProviders: admin.firestore.FieldValue.increment(1),
  });
});

export const onServiceCreated = onDocumentCreated('services/{serviceId}', async (event) => {
  await incrementStatIdempotent(event.id, 'service_created', {
    totalServices: admin.firestore.FieldValue.increment(1),
  });

  // Ensure a providers/{providerId} document exists so the public provider
  // profile is never empty, even if the provider published a service without
  // completing provider onboarding. merge:true never overwrites an existing
  // profile (bio, serviceArea, suspended, etc. are preserved).
  const service = event.data?.data() as { providerId?: string } | undefined;
  const providerId = service?.providerId;
  if (providerId) {
    const providerRef = db.collection('providers').doc(providerId);
    const snap = await providerRef.get();
    if (!snap.exists) {
      await providerRef.set(
        {
          uid: providerId,
          active: true,
          suspended: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  }
});

export const onBookingCreated = onDocumentCreated('bookings/{bookingId}', async (event) => {
  await incrementStatIdempotent(event.id, 'booking_created', {
    totalBookings: admin.firestore.FieldValue.increment(1),
  });
});

export const onBookingUpdatedStats = onDocumentUpdated('bookings/{bookingId}', async (event) => {
  const before = event.data?.before.data() as { status?: string } | undefined;
  const after = event.data?.after.data() as { status?: string } | undefined;
  if (!before || !after || before.status === after.status) return;

  if (after.status === 'done' && before.status !== 'done') {
    await incrementStatIdempotent(event.id, 'booking_done', {
      totalBookingsDone: admin.firestore.FieldValue.increment(1),
    });
  }
});

export const onReportCreatedStats = onDocumentCreated('reports/{reportId}', async (event) => {
  await incrementStatIdempotent(event.id, 'report_created', {
    totalReports: admin.firestore.FieldValue.increment(1),
    totalReportsPending: admin.firestore.FieldValue.increment(1),
  });
});

export const onReportUpdatedStats = onDocumentUpdated('reports/{reportId}', async (event) => {
  const before = event.data?.before.data() as { status?: string } | undefined;
  const after = event.data?.after.data() as { status?: string } | undefined;
  if (!before || !after || before.status === after.status) return;

  if (before.status === 'open' && after.status !== 'open') {
    await incrementStatIdempotent(event.id, 'report_closed', {
      totalReportsPending: admin.firestore.FieldValue.increment(-1),
    });
  }
});

// ---------------------------------------------------------------------------
// Trigger: notify admins/moderators on new report
// ---------------------------------------------------------------------------

export const onReportCreated = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const reportId = event.params.reportId;
    const report = event.data?.data() as { reason?: string } | undefined;
    if (!report) return;

    const reason = (report.reason as string | undefined) ?? 'Contenu signalé';

    const rolesSnap = await db
      .collection('user_roles')
      .where('admin', '==', true)
      .limit(20)
      .get();

    const modSnap = await db
      .collection('user_roles')
      .where('moderator', '==', true)
      .limit(20)
      .get();

    const staffUids = new Set<string>();
    for (const doc of [...rolesSnap.docs, ...modSnap.docs]) {
      staffUids.add(doc.id);
    }

    const uids = [...staffUids];

    if (uids.length > 0) {
      await sendPushToUsers(uids, {
        title: 'Nouveau signalement',
        body: `Un utilisateur a signalé : ${reason}`,
      });
    }

    await db.collection('admin_logs').add({
      actorUid: 'system',
      action: 'report_notification_sent',
      targetType: 'report',
      targetId: reportId,
      notes: `Notified ${uids.length} staff members`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Report notification sent', { reportId, staffCount: uids.length });
  }
);

// ---------------------------------------------------------------------------
// Analytics — incremental counters for posts & events (stats/global)
// ---------------------------------------------------------------------------

const ANALYTICS_STATS_REF = db.collection('stats').doc('global');

export const onPostCreated = onDocumentCreated('posts/{postId}', async () => {
  await ANALYTICS_STATS_REF.set(
    { postsCount: admin.firestore.FieldValue.increment(1), updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
});

export const onPostDeleted = onDocumentDeleted('posts/{postId}', async () => {
  await ANALYTICS_STATS_REF.set(
    { postsCount: admin.firestore.FieldValue.increment(-1), updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
});

export const onEventCreated = onDocumentCreated('events/{eventId}', async () => {
  await ANALYTICS_STATS_REF.set(
    { eventsCount: admin.firestore.FieldValue.increment(1), updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
});

export const onEventDeleted = onDocumentDeleted('events/{eventId}', async () => {
  await ANALYTICS_STATS_REF.set(
    { eventsCount: admin.firestore.FieldValue.increment(-1), updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
});

export const initializeStats = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminClaim(request.auth?.token?.admin);

  const snap = await ANALYTICS_STATS_REF.get();
  if (snap.exists) {
    return { initialized: false, reason: 'already_exists' };
  }

  await ANALYTICS_STATS_REF.set({
    postsCount: 0,
    eventsCount: 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { initialized: true };
});
