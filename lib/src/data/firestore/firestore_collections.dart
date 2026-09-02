import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/enums/active_mode.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/gender.dart';
import '../../domain/enums/message_type.dart';
import '../../domain/enums/price_type.dart';
import '../../domain/enums/reviewer_role.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/blocked_slot.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/phone_share.dart';
import '../../domain/models/provider_profile.dart';
import '../../domain/models/public_profile.dart';
import '../../domain/models/report.dart';
import '../../domain/models/review.dart';
import '../../domain/models/service.dart';
import '../../domain/models/service_zone.dart';
import 'firestore_serialization.dart';

/// Central place for Firestore collection paths and typed collection refs.
///
/// Uses `withConverter` to keep serialization out of UI code.
class FirestoreCollections {
  const FirestoreCollections._();

  static CollectionReference<AppUser> users(FirebaseFirestore db) {
    return db
        .collection('users')
        .withConverter<AppUser>(
          fromFirestore: (snap, _) => _userFromFirestore(snap),
          toFirestore: (user, _) => _userToFirestore(user),
        );
  }

  /// The world-readable, PII-free mirror of `users`. Public surfaces resolve
  /// display names and avatars here so a signed-out visitor can read them:
  /// `users` is gated on `signedIn()` because it holds email and phone.
  static CollectionReference<PublicProfile> publicProfiles(
    FirebaseFirestore db,
  ) {
    return db
        .collection('public_profiles')
        .withConverter<PublicProfile>(
          fromFirestore: (snap, _) => _publicProfileFromFirestore(snap),
          // Read-only from the client. The projection is written exclusively by
          // the mirrorPublicProfile Cloud Function and every client write is
          // denied by the rules, so a working serialiser here would advertise a
          // path that does not exist and would fail at the network layer.
          toFirestore: (_, __) => throw UnsupportedError(
            'public_profiles is server-owned: client writes are denied',
          ),
        );
  }

  static CollectionReference<Service> services(FirebaseFirestore db) {
    return db
        .collection('services')
        .withConverter<Service>(
          fromFirestore: (snap, _) => _serviceFromFirestore(snap),
          toFirestore: (service, _) => _serviceToFirestore(service),
        );
  }

  static CollectionReference<Booking> bookings(FirebaseFirestore db) {
    return db
        .collection('bookings')
        .withConverter<Booking>(
          fromFirestore: (snap, _) => _bookingFromFirestore(snap),
          toFirestore: (booking, _) => _bookingToFirestore(booking),
        );
  }

  static CollectionReference<Chat> chats(FirebaseFirestore db) {
    return db
        .collection('chats')
        .withConverter<Chat>(
          fromFirestore: (snap, _) => _chatFromFirestore(snap),
          toFirestore: (chat, _) => _chatToFirestore(chat),
        );
  }

  static CollectionReference<ChatMessage> chatMessages({
    required FirebaseFirestore db,
    required String chatId,
  }) {
    return db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .withConverter<ChatMessage>(
          fromFirestore: (snap, _) => _messageFromFirestore(snap),
          toFirestore: (message, _) => _messageToFirestore(message),
        );
  }

  static CollectionReference<ProviderProfile> providers(FirebaseFirestore db) {
    return db
        .collection('providers')
        .withConverter<ProviderProfile>(
          fromFirestore: (snap, _) => _providerFromFirestore(snap),
          toFirestore: (profile, _) => _providerToFirestore(profile),
        );
  }

  static CollectionReference<BlockedSlot> blockedSlots(
    FirebaseFirestore db,
    String uid,
  ) {
    return db
        .collection('providers')
        .doc(uid)
        .collection('blocked_slots')
        .withConverter<BlockedSlot>(
          fromFirestore: (snap, _) => _blockedSlotFromFirestore(snap),
          toFirestore: (slot, _) => _blockedSlotToFirestore(slot),
        );
  }

  static CollectionReference<Review> reviews(FirebaseFirestore db) {
    return db
        .collection('reviews')
        .withConverter<Review>(
          fromFirestore: (snap, _) => _reviewFromFirestore(snap),
          toFirestore: (review, _) => _reviewToFirestore(review),
        );
  }

  static CollectionReference<Report> reports(FirebaseFirestore db) {
    return db
        .collection('reports')
        .withConverter<Report>(
          fromFirestore: (snap, _) => _reportFromFirestore(snap),
          toFirestore: (report, _) => _reportToFirestore(report),
        );
  }

  static CollectionReference<AppNotification> notifications({
    required FirebaseFirestore db,
    required String uid,
  }) {
    return db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .withConverter<AppNotification>(
          fromFirestore: (snap, _) => _notificationFromFirestore(snap),
          toFirestore: (n, _) => _notificationToFirestore(n),
        );
  }

  static CollectionReference<PhoneShare> phoneShares({
    required FirebaseFirestore db,
    required String bookingId,
  }) {
    return db
        .collection('bookings')
        .doc(bookingId)
        .collection('phoneShares')
        .withConverter<PhoneShare>(
          fromFirestore: (snap, _) => _phoneShareFromFirestore(snap),
          toFirestore: (ps, _) => _phoneShareToFirestore(ps),
        );
  }

  // ---- AppUser ----

  static AppUser _userFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return AppUser(
      id: snap.id,
      displayName: (data['displayName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      photoPath: data['photoPath'] as String?,
      phoneE164: data['phoneE164'] as String?,
      country: (data['country'] as String?) ?? 'FR',
      activeMode: ActiveMode.fromString(
        (data['activeMode'] as String?) ?? ActiveMode.client.name,
      ),
      pushToken: data['pushToken'] as String?,
      createdAt: dateTimeFromFirestore(data['createdAt']),
      termsAcceptedAt: data['termsAcceptedAt'] != null
          ? dateTimeFromFirestore(data['termsAcceptedAt'])
          : null,
      // Absent on every account created before the field shipped, and left
      // null for them rather than defaulted: see Gender.tryParse.
      gender: Gender.tryParse(data['gender']),
      // Read defensively, unlike the `as String?` neighbours above. A
      // non-string here would throw inside the converter, and on the `users`
      // path that throw is swallowed by _resolveState's catch, which returns
      // AuthUnauthenticated: the owner would be signed out of their own
      // account by a bad value in a decorative field. The rule and the
      // projection both refuse a non-string, so this only ever fires on a
      // value written before those guards existed.
      avatarId: data['avatarId'] is String ? data['avatarId'] as String : null,
    );
  }

  static Map<String, Object?> _userToFirestore(AppUser user) {
    return {
      'displayName': user.displayName,
      'email': user.email,
      'photoPath': user.photoPath,
      // Never write phoneE164 as null: the create rule requires the field to
      // be absent for email-only accounts, and the update rule blocks any
      // client-side change to this field (security review C1/C2).
      if (user.phoneE164 != null) 'phoneE164': user.phoneE164,
      'country': user.country,
      'activeMode': user.activeMode.name,
      // Never write pushToken as null. NotificationService writes the token via
      // a direct .update() after auth resolves, so the in-memory AppUser carried
      // by AuthAuthenticated is often stale (null). A merge write that always
      // included pushToken would clobber the real token on switchMode /
      // updateProfile and silently kill push delivery.
      if (user.pushToken != null) 'pushToken': user.pushToken,
      if (user.termsAcceptedAt != null)
        'termsAcceptedAt': dateTimeToFirestore(user.termsAcceptedAt!),
      // Never written as null. `switchMode` and `updateProfile` both go through
      // a merge write carrying the whole AppUser, and an explicit null there
      // would erase the declared gender of every account whose in-memory copy
      // predates a reload, exactly like the pushToken case above.
      if (user.gender != null) 'gender': user.gender!.name,
      // Conditional for exactly the reason the two comments above give: this
      // map goes out as a whole-document merge from switchMode and
      // updateProfile, and an explicit null would erase the avatar of every
      // account whose in-memory copy predates a reload. Erasing is therefore
      // NOT done from here: UserRepository.setProfileImage writes the two
      // image fields on their own, with FieldValue.delete() for a null.
      if (user.avatarId != null) 'avatarId': user.avatarId,
      'createdAt': dateTimeToFirestore(user.createdAt),
    };
  }

  // ---- PublicProfile ----

  /// Deliberately tolerant of every absent field. The projection is produced by
  /// a Cloud Function from whatever `users/{uid}` holds, and a document written
  /// before a field existed must degrade to a blank name rather than throw on a
  /// public surface a visitor is looking at.
  static PublicProfile _publicProfileFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return PublicProfile(
      id: snap.id,
      displayName: (data['displayName'] as String?) ?? '',
      photoPath: data['photoPath'] as String?,
      // Left null when absent, NOT defaulted to 'FR' like AppUser does: this
      // document feeds a public profile, and a default here would display a
      // country the user never declared.
      country: data['country'] as String?,
      phoneVerified: (data['phoneVerified'] as bool?) ?? false,
      // Same tolerance as above, on the collection where it matters most: this
      // document feeds the catalogue card a guest sees, and 50 of the 50
      // production documents predate the field.
      gender: Gender.tryParse(data['gender']),
      // Read defensively, like the `users` converter above but for a
      // different consequence: this document feeds surfaces a VISITOR is
      // looking at, so a throw here would break a page for somebody with no
      // account and no way to fix it. The projection only ever publishes a
      // well-formed token, so this fires solely on a value written before that
      // guard existed.
      avatarId: data['avatarId'] is String ? data['avatarId'] as String : null,
    );
  }

  // ---- Service ----

  static Service _serviceFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Service(
      id: snap.id,
      providerId: (data['providerId'] as String?) ?? '',
      categoryId: CategoryId.fromString(
        (data['categoryId'] as String?) ?? CategoryId.menage.name,
      ),
      title: (data['title'] as String?) ?? '',
      description: data['description'] as String?,
      photos: (data['photos'] as List?)?.cast<String>() ?? [],
      priceType: PriceType.fromString(
        (data['priceType'] as String?) ?? PriceType.fixed.name,
      ),
      price: (data['price'] as num?)?.toInt() ?? 0,
      priceMax: (data['priceMax'] as num?)?.toInt(),
      extraTasks:
          (data['extraTasks'] as List?)?.whereType<String>().toList() ??
          const [],
      published: (data['published'] as bool?) ?? false,
      serviceZones: _serviceZonesFromFirestore(data),
      status: data['status'] as String?,
      createdAt: dateTimeFromFirestore(data['createdAt']),
      updatedAt: dateTimeFromFirestore(data['updatedAt']),
    );
  }

  static Map<String, Object?> _serviceToFirestore(Service service) {
    return {
      'providerId': service.providerId,
      'categoryId': service.categoryId.name,
      'title': service.title,
      'description': service.description,
      'photos': service.photos,
      'priceType': service.priceType.name,
      'price': service.price,
      // priceMax is written only for the monthly range mode; the security rule
      // rejects a priceMax present outside the monthly mode, so it must be
      // absent (not null) for hourly and daily.
      if (service.priceMax != null) 'priceMax': service.priceMax,
      'extraTasks': service.extraTasks,
      'published': service.published,
      'serviceZones': service.serviceZones.map(serviceZoneToMap).toList(),
      'createdAt': dateTimeToFirestore(service.createdAt),
      'updatedAt': dateTimeToFirestore(service.updatedAt),
    };
  }

  /// Backward-compatible zone reader: prefers `serviceZones` array, falls back
  /// to legacy `serviceArea` string (synthesised as a single zone with no coords).
  static List<ServiceZone> _serviceZonesFromFirestore(
    Map<String, dynamic> data,
  ) {
    final raw = data['serviceZones'];
    if (raw is List && raw.isNotEmpty) {
      // whereType avoids a hard crash if a malformed element isn't a Map.
      return raw
          .whereType<Map<String, dynamic>>()
          .map(serviceZoneFromMap)
          .toList();
    }
    // Legacy fallback
    final legacy = data['serviceArea'] as String?;
    if (legacy != null && legacy.isNotEmpty) {
      return [
        ServiceZone(label: legacy, latitude: 0, longitude: 0, radiusKm: 0),
      ];
    }
    return const [];
  }

  // ---- Booking ----

  static Booking _bookingFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Booking(
      id: snap.id,
      customerId: (data['customerId'] as String?) ?? '',
      providerId: (data['providerId'] as String?) ?? '',
      serviceId: (data['serviceId'] as String?) ?? '',
      status: BookingStatus.fromString(
        (data['status'] as String?) ?? BookingStatus.requested.value,
      ),
      requestMessage: (data['requestMessage'] as String?) ?? '',
      scheduledAt: data['scheduledAt'] != null
          ? dateTimeFromFirestore(data['scheduledAt'])
          : null,
      schedule: data['schedule'] != null
          ? Map<String, Object?>.from(data['schedule'] as Map)
          : null,
      addressSnapshot: data['addressSnapshot'] != null
          ? Map<String, Object?>.from(data['addressSnapshot'] as Map)
          : null,
      chatId: data['chatId'] as String?,
      createdAt: dateTimeFromFirestore(data['createdAt']),
      acceptedAt: data['acceptedAt'] != null
          ? dateTimeFromFirestore(data['acceptedAt'])
          : null,
      rejectedAt: data['rejectedAt'] != null
          ? dateTimeFromFirestore(data['rejectedAt'])
          : null,
      cancelledAt: data['cancelledAt'] != null
          ? dateTimeFromFirestore(data['cancelledAt'])
          : null,
      startedAt: data['startedAt'] != null
          ? dateTimeFromFirestore(data['startedAt'])
          : null,
      doneAt: data['doneAt'] != null
          ? dateTimeFromFirestore(data['doneAt'])
          : null,
      audioMessageUrl: data['audioMessageUrl'] as String?,
      cancelReason: data['cancelReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
    );
  }

  static Map<String, Object?> _bookingToFirestore(Booking booking) {
    return {
      'customerId': booking.customerId,
      'providerId': booking.providerId,
      'serviceId': booking.serviceId,
      'status': booking.status.value,
      'requestMessage': booking.requestMessage,
      'scheduledAt': booking.scheduledAt != null
          ? dateTimeToFirestore(booking.scheduledAt!)
          : null,
      'schedule': booking.schedule,
      'addressSnapshot': booking.addressSnapshot,
      'chatId': booking.chatId,
      'createdAt': dateTimeToFirestore(booking.createdAt),
      'acceptedAt': booking.acceptedAt != null
          ? dateTimeToFirestore(booking.acceptedAt!)
          : null,
      'rejectedAt': booking.rejectedAt != null
          ? dateTimeToFirestore(booking.rejectedAt!)
          : null,
      'cancelledAt': booking.cancelledAt != null
          ? dateTimeToFirestore(booking.cancelledAt!)
          : null,
      'startedAt': booking.startedAt != null
          ? dateTimeToFirestore(booking.startedAt!)
          : null,
      'doneAt': booking.doneAt != null
          ? dateTimeToFirestore(booking.doneAt!)
          : null,
      if (booking.audioMessageUrl != null)
        'audioMessageUrl': booking.audioMessageUrl,
      // Cancellation metadata, set server-side by cancelBooking. Included here
      // so the typed converter round-trips a Booking fully (clients do not write
      // bookings today; this keeps the serializer aligned with the model).
      if (booking.cancelReason != null) 'cancelReason': booking.cancelReason,
      if (booking.cancelledBy != null) 'cancelledBy': booking.cancelledBy,
    };
  }

  // ---- Chat ----

  static Chat _chatFromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Chat(
      id: snap.id,
      bookingId: (data['bookingId'] as String?) ?? '',
      participantIds: (data['participantIds'] as List?)?.cast<String>() ?? [],
      createdAt: dateTimeFromFirestore(data['createdAt']),
      lastMessageAt: data['lastMessageAt'] != null
          ? dateTimeFromFirestore(data['lastMessageAt'])
          : null,
      customerId: (data['customerId'] as String?) ?? '',
      providerId: (data['providerId'] as String?) ?? '',
    );
  }

  static Map<String, Object?> _chatToFirestore(Chat chat) {
    return {
      'bookingId': chat.bookingId,
      'participantIds': chat.participantIds,
      'createdAt': dateTimeToFirestore(chat.createdAt),
      'lastMessageAt': chat.lastMessageAt != null
          ? dateTimeToFirestore(chat.lastMessageAt!)
          : null,
      'customerId': chat.customerId,
      'providerId': chat.providerId,
    };
  }

  // ---- ChatMessage ----

  static ChatMessage _messageFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: snap.id,
      chatId: (data['chatId'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      type: MessageType.fromString(
        (data['type'] as String?) ?? MessageType.text.name,
      ),
      createdAt: dateTimeFromFirestore(data['createdAt']),
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      readBy: (data['readBy'] as List?)?.cast<String>() ?? [],
      deleted: (data['deleted'] as bool?) ?? false,
      edited: (data['edited'] as bool?) ?? false,
      replyToId: data['replyToId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSenderId: data['replyToSenderId'] as String?,
      reactions:
          (data['reactions'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
    );
  }

  static Map<String, Object?> _messageToFirestore(ChatMessage message) {
    return {
      'chatId': message.chatId,
      'senderId': message.senderId,
      'type': message.type.name,
      'createdAt': dateTimeToFirestore(message.createdAt),
      'text': message.text,
      'mediaUrl': message.mediaUrl,
      'readBy': message.readBy,
      'deleted': message.deleted,
      'edited': message.edited,
      if (message.replyToId != null) 'replyToId': message.replyToId,
      if (message.replyToText != null) 'replyToText': message.replyToText,
      if (message.replyToSenderId != null)
        'replyToSenderId': message.replyToSenderId,
    };
  }

  // ---- ProviderProfile ----

  static ProviderProfile _providerFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return ProviderProfile(
      uid: snap.id,
      bio: data['bio'] as String?,
      workingHourStart: (data['workingHourStart'] as num?)?.toInt(),
      workingHourEnd: (data['workingHourEnd'] as num?)?.toInt(),
      // Availability defaults to true (available) when the field is missing,
      // a provider is hidden only if they explicitly paused.
      active: (data['active'] as bool?) ?? true,
      suspended: (data['suspended'] as bool?) ?? false,
      createdAt: dateTimeFromFirestore(data['createdAt']),
    );
  }

  static Map<String, Object?> _providerToFirestore(ProviderProfile profile) {
    return {
      'uid': profile.uid,
      'bio': profile.bio,
      'workingHourStart': profile.workingHourStart,
      'workingHourEnd': profile.workingHourEnd,
      'active': profile.active,
      'suspended': profile.suspended,
      'createdAt': dateTimeToFirestore(profile.createdAt),
    };
  }

  // ---- BlockedSlot ----

  static BlockedSlot _blockedSlotFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return BlockedSlot(
      id: snap.id,
      date: dateTimeFromFirestore(data['date']),
      endDate: data['endDate'] != null
          ? dateTimeFromFirestore(data['endDate'])
          : null,
      reason: data['reason'] as String?,
    );
  }

  static Map<String, Object?> _blockedSlotToFirestore(BlockedSlot slot) {
    return {
      'date': dateTimeToFirestore(slot.date),
      'endDate': slot.endDate != null
          ? dateTimeToFirestore(slot.endDate!)
          : null,
      'reason': slot.reason,
    };
  }

  // ---- Review ----

  static Review _reviewFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Review(
      id: snap.id,
      bookingId: (data['bookingId'] as String?) ?? '',
      reviewerId: (data['reviewerId'] as String?) ?? '',
      revieweeId: (data['revieweeId'] as String?) ?? '',
      reviewerRole: ReviewerRole.fromString(
        (data['reviewerRole'] as String?) ?? ReviewerRole.client.name,
      ),
      rating: (data['rating'] as num?)?.toInt() ?? 1,
      comment: data['comment'] as String?,
      categoryId: data['categoryId'] != null
          ? CategoryId.fromString(data['categoryId'] as String)
          : null,
      // Absent on the historical corpus, so absence means visible.
      hidden: (data['hidden'] as bool?) ?? false,
      createdAt: dateTimeFromFirestore(data['createdAt']),
    );
  }

  /// `hidden` IS written here, and always as the literal `false`, never as
  /// `review.hidden`.
  ///
  /// It used to be omitted, on the argument that a moderation verdict must not
  /// be client-writable while the `create` rule carried no field allowlist. The
  /// rule now carries one: `hidden` is accepted on create only when it equals
  /// false (see firebase/firestore.rules), so the field can be written without
  /// handing the verdict to the client.
  ///
  /// Omitting it stopped being an option once reviews became publicly readable.
  /// That rule is `resource.data.hidden == false`, which a document lacking the
  /// field cannot satisfy and a query cannot match: a review created without
  /// the field would be invisible to every visitor, for ever.
  ///
  /// The literal, not the model field: `create` is the only path through here,
  /// and a future caller passing a Review built with `hidden: true` must not be
  /// able to smuggle it in. The rule would refuse the write anyway; this makes
  /// the client refuse to build it in the first place.
  static Map<String, Object?> _reviewToFirestore(Review review) {
    return {
      'bookingId': review.bookingId,
      'reviewerId': review.reviewerId,
      'revieweeId': review.revieweeId,
      'reviewerRole': review.reviewerRole.name,
      'rating': review.rating,
      'comment': review.comment,
      if (review.categoryId != null) 'categoryId': review.categoryId!.name,
      'hidden': false,
      'createdAt': dateTimeToFirestore(review.createdAt),
    };
  }

  // ---- Report ----

  static Report _reportFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Report(
      id: snap.id,
      reporterId: (data['reporterId'] as String?) ?? '',
      targetType: (data['targetType'] as String?) ?? 'user',
      targetId: (data['targetId'] as String?) ?? '',
      reason: (data['reason'] as String?) ?? '',
      details: data['details'] as String?,
      status: (data['status'] as String?) ?? 'open',
      createdAt: dateTimeFromFirestore(data['createdAt']),
    );
  }

  static Map<String, Object?> _reportToFirestore(Report report) {
    return {
      'reporterId': report.reporterId,
      'targetType': report.targetType,
      'targetId': report.targetId,
      'reason': report.reason,
      if (report.details != null && report.details!.isNotEmpty)
        'details': report.details,
      'status': report.status,
      'createdAt': dateTimeToFirestore(report.createdAt),
    };
  }

  // ---- PhoneShare ----

  static PhoneShare _phoneShareFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return PhoneShare(
      uid: snap.id,
      phone: (data['phone'] as String?) ?? '',
      createdAt: dateTimeFromFirestore(data['createdAt']),
    );
  }

  static Map<String, Object?> _phoneShareToFirestore(PhoneShare ps) {
    return {'phone': ps.phone, 'createdAt': dateTimeToFirestore(ps.createdAt)};
  }

  // ---- AppNotification ----

  static AppNotification _notificationFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: snap.id,
      type: (data['type'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      read: (data['read'] as bool?) ?? false,
      createdAt: dateTimeFromFirestore(data['createdAt']),
      bookingId: data['bookingId'] as String?,
      chatId: data['chatId'] as String?,
      audience: data['audience'] as String?,
    );
  }

  static Map<String, Object?> _notificationToFirestore(AppNotification n) {
    return {
      'type': n.type,
      'title': n.title,
      'body': n.body,
      'read': n.read,
      'createdAt': dateTimeToFirestore(n.createdAt),
      'bookingId': n.bookingId,
      'chatId': n.chatId,
      if (n.audience != null) 'audience': n.audience,
    };
  }
}
