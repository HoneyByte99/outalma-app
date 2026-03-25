import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/enums/booking_status.dart';
import '../../domain/enums/message_type.dart';
import '../../domain/enums/service_status.dart';
import '../../domain/enums/user_role.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/service.dart';
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

  // --- Private mapping (Firestore stores timestamps as Timestamp) ---

  static AppUser _userFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return AppUser(
      id: snap.id,
      displayName: (data['displayName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.fromString(
        (data['role'] as String?) ?? UserRole.customer.name,
      ),
      createdAt: dateTimeFromFirestore(data['createdAt']),
    );
  }

  static Map<String, Object?> _userToFirestore(AppUser user) {
    return {
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoUrl,
      'role': user.role.name,
      'createdAt': dateTimeToFirestore(user.createdAt),
    };
  }

  static Service _serviceFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Service(
      id: snap.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      description: data['description'] as String?,
      durationMinutes: data['durationMinutes'] as int?,
      priceCents: data['priceCents'] as int?,
      status: ServiceStatus.fromString(
        (data['status'] as String?) ?? ServiceStatus.draft.name,
      ),
      createdAt: dateTimeFromFirestore(data['createdAt']),
      updatedAt: dateTimeFromFirestore(data['updatedAt']),
    );
  }

  static Map<String, Object?> _serviceToFirestore(Service service) {
    return {
      'ownerId': service.ownerId,
      'title': service.title,
      'description': service.description,
      'durationMinutes': service.durationMinutes,
      'priceCents': service.priceCents,
      'status': service.status.name,
      'createdAt': dateTimeToFirestore(service.createdAt),
      'updatedAt': dateTimeToFirestore(service.updatedAt),
    };
  }

  static Booking _bookingFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Booking(
      id: snap.id,
      userId: (data['userId'] as String?) ?? '',
      serviceId: (data['serviceId'] as String?) ?? '',
      startAt: dateTimeFromFirestore(data['startAt']),
      endAt: dateTimeFromFirestore(data['endAt']),
      status: BookingStatus.fromString(
        (data['status'] as String?) ?? BookingStatus.pending.name,
      ),
      createdAt: dateTimeFromFirestore(data['createdAt']),
      updatedAt: dateTimeFromFirestore(data['updatedAt']),
      notes: data['notes'] as String?,
    );
  }

  static Map<String, Object?> _bookingToFirestore(Booking booking) {
    return {
      'userId': booking.userId,
      'serviceId': booking.serviceId,
      'startAt': dateTimeToFirestore(booking.startAt),
      'endAt': dateTimeToFirestore(booking.endAt),
      'status': booking.status.name,
      'createdAt': dateTimeToFirestore(booking.createdAt),
      'updatedAt': dateTimeToFirestore(booking.updatedAt),
      'notes': booking.notes,
    };
  }

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
      sentAt: dateTimeFromFirestore(data['sentAt']),
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
    );
  }

  static Map<String, Object?> _messageToFirestore(ChatMessage message) {
    return {
      'chatId': message.chatId,
      'senderId': message.senderId,
      'type': message.type.name,
      'sentAt': dateTimeToFirestore(message.sentAt),
      'text': message.text,
      'mediaUrl': message.mediaUrl,
    };
  }
}
