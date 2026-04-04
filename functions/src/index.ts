import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import { assertAdminClaim, assertAdminOrModeratorClaim, assertAuthenticated, requireBoolean, requireString } from './common';

admin.initializeApp();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// Push notification helper
// ---------------------------------------------------------------------------

async function sendPushToUsers(
  uids: string[],
  notification: { title: string; body: string }
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
    android: { priority: 'high' },
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

  // schedule/addressSnapshot are intentionally permissive for MVP; validate in app + tighten later.
  const schedule = request.data?.schedule ?? null;
  const addressSnapshot = request.data?.addressSnapshot ?? null;
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
  await bookingRef.set({
    customerId: uid,
    providerId,
    serviceId,
    status: 'requested' as BookingStatus,
    requestMessage,
    scheduledAt,
    schedule,
    addressSnapshot,
    reminded24h: false,
    reminded1h: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
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

    await sendPushToUsers(recipients, {
      title: notifTitle,
      body: notifBody,
    });

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
      await sendPushToUsers(n.uids, { title: n.title, body: n.body });
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
  const bookingRef = db.collection('bookings').doc(bookingId);

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

    if (booking.status !== 'requested') {
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
      cancelledAt: admin.firestore.FieldValue.serverTimestamp()
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
        await doc.ref.update({ reminded24h: true });
        sent++;
      }

      // 1h reminder (between 0.5h and 1.5h before)
      if (!data.reminded1h && diffHours >= 0.5 && diffHours <= 1.5) {
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
        await doc.ref.update({ reminded1h: true });
        sent++;
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
// suspendProvider — admin or moderator
// ---------------------------------------------------------------------------

export const suspendProvider = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

  const targetUid = requireString(request.data?.uid, 'uid');
  const reason = typeof request.data?.reason === 'string' ? request.data.reason.trim() : null;

  const providerRef = db.collection('providers').doc(targetUid);
  const providerSnap = await providerRef.get();
  if (!providerSnap.exists) {
    throw new HttpsError('not-found', 'Provider not found.');
  }

  const servicesSnap = await db
    .collection('services')
    .where('providerId', '==', targetUid)
    .where('published', '==', true)
    .get();

  const batch = db.batch();
  batch.update(providerRef, {
    suspended: true,
    suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
    suspendedReason: reason,
  });
  for (const doc of servicesSnap.docs) {
    batch.update(doc.ref, { published: false });
  }
  await batch.commit();

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

  // Geolocate IP via ipapi.co (1 000 req/day on free tier)
  let country: string | null = null;
  let countryCode: string | null = null;
  if (ip) {
    try {
      const geoResp = await fetch(`https://ipapi.co/${ip}/json/`);
      if (geoResp.ok) {
        const geo = (await geoResp.json()) as {
          country_code?: string;
          country_name?: string;
          error?: boolean;
        };
        if (!geo.error) {
          countryCode = geo.country_code ?? null;
          country = geo.country_name ?? null;
        }
      }
    } catch (e) {
      logger.warn('IP geolocation failed', { ip, error: String(e) });
    }
  }

  const sessionRef = db.collection('user_sessions').doc(uid);
  const eventRef = sessionRef.collection('events').doc();

  const batch = db.batch();
  batch.set(eventRef, {
    uid,
    ip,
    country,
    countryCode,
    platform,
    deviceModel,
    appVersion,
    sessionId,
    loggedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(
    sessionRef,
    {
      uid,
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      lastIp: ip,
      lastCountry: country,
      lastCountryCode: countryCode,
      lastPlatform: platform,
    },
    { merge: true }
  );
  await batch.commit();

  return { logged: true };
});

// ---------------------------------------------------------------------------
// resolveReport — admin or moderator
// ---------------------------------------------------------------------------

export const resolveReport = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  assertAuthenticated(callerUid);
  assertAdminOrModeratorClaim(request.auth?.token as Record<string, unknown> | undefined);

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
