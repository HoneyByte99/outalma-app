// Integration test: full booking golden path
//
// Tests the complete lifecycle of a booking from creation to review using
// real repository implementations on FakeFirebaseFirestore.
//
// Cloud Functions (createBooking, acceptBooking, markInProgress, confirmDone)
// are mocked because they run server-side. Everything else — repositories,
// Firestore reads/writes, stream subscriptions — uses real code.
//
// Two-user simulation:
//   clientId  = 'client_1'
//   providerId = 'provider_1'
//
// The test manages Firestore state directly to simulate what Cloud Functions
// would do (create the booking doc, set chatId on accept, etc.) since we
// cannot run Cloud Functions in a unit test environment.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/data/repositories/firestore_booking_repository.dart';
import 'package:outalma_app/src/data/repositories/firestore_chat_repository.dart';
import 'package:outalma_app/src/data/repositories/firestore_review_repository.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/message_type.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/booking.dart';
import 'package:outalma_app/src/domain/models/chat.dart';
import 'package:outalma_app/src/domain/models/chat_message.dart';
import 'package:outalma_app/src/domain/models/service.dart';

// ---------------------------------------------------------------------------
// Fake Cloud Functions infrastructure (same pattern as lifecycle_use_cases_test)
// ---------------------------------------------------------------------------

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  _FakeCallableResult(this._data);
  final T _data;
  @override
  T get data => _data;
}

class _FakeCallable extends Fake implements HttpsCallable {
  _FakeCallable({this.response});

  /// Optional response data returned by the callable.
  final Map<String, dynamic>? response;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    if (response != null) {
      return _FakeCallableResult<T>(response as T);
    }
    return _FakeCallableResult<T>(null as T);
  }
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this._callableByName);

  final Map<String, _FakeCallable> _callableByName;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return _callableByName[name] ?? _FakeCallable();
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Writes a booking document directly to FakeFirebaseFirestore, simulating
/// what the createBooking Cloud Function would do on the server.
Future<String> _simulateCreateBooking({
  required FakeFirebaseFirestore fakeDb,
  required String clientId,
  required String providerId,
  required String serviceId,
  required String requestMessage,
}) async {
  final now = DateTime.now().toUtc();
  final docRef = fakeDb.collection('bookings').doc();
  await docRef.set({
    'customerId': clientId,
    'providerId': providerId,
    'serviceId': serviceId,
    'status': 'requested',
    'requestMessage': requestMessage,
    'createdAt': now.toIso8601String(),
    'chatId': null,
    'acceptedAt': null,
    'rejectedAt': null,
    'cancelledAt': null,
    'startedAt': null,
    'doneAt': null,
  });
  return docRef.id;
}

/// Simulates acceptBooking Cloud Function:
/// - Creates a chat document with participantIds
/// - Sets chatId + acceptedAt on the booking
Future<String> _simulateAcceptBooking({
  required FakeFirebaseFirestore fakeDb,
  required String bookingId,
  required String clientId,
  required String providerId,
}) async {
  final now = DateTime.now().toUtc();

  // Create chat document
  final chatRef = fakeDb.collection('chats').doc();
  await chatRef.set({
    'bookingId': bookingId,
    'participantIds': [clientId, providerId],
    'customerId': clientId,
    'providerId': providerId,
    'createdAt': now.toIso8601String(),
    'lastMessageAt': null,
  });

  // Update booking: accepted + chatId
  await fakeDb.collection('bookings').doc(bookingId).update({
    'status': 'accepted',
    'chatId': chatRef.id,
    'acceptedAt': now.toIso8601String(),
  });

  return chatRef.id;
}

/// Simulates markInProgress Cloud Function.
Future<void> _simulateMarkInProgress({
  required FakeFirebaseFirestore fakeDb,
  required String bookingId,
}) async {
  final now = DateTime.now().toUtc();
  await fakeDb.collection('bookings').doc(bookingId).update({
    'status': 'in_progress',
    'startedAt': now.toIso8601String(),
  });
}

/// Simulates confirmDone Cloud Function.
Future<void> _simulateConfirmDone({
  required FakeFirebaseFirestore fakeDb,
  required String bookingId,
}) async {
  final now = DateTime.now().toUtc();
  await fakeDb.collection('bookings').doc(bookingId).update({
    'status': 'done',
    'doneAt': now.toIso8601String(),
  });
}

// ---------------------------------------------------------------------------
// Golden path test
// ---------------------------------------------------------------------------

void main() {
  const clientId = 'client_1';
  const providerId = 'provider_1';
  const serviceId = 'service_menage_1';

  late FakeFirebaseFirestore fakeDb;
  late FirestoreBookingRepository bookingRepo;
  late FirestoreChatRepository chatRepo;
  late FirestoreReviewRepository reviewRepo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    bookingRepo = FirestoreBookingRepository(fakeDb);
    chatRepo = FirestoreChatRepository(fakeDb);
    reviewRepo = FirestoreReviewRepository(fakeDb);
  });

  group('Booking golden path — full lifecycle', () {
    // Step 2: service with category "menage" is visible (seed a service)
    test('Step 2 — service with category menage is browsable', () async {
      final now = DateTime.now().toUtc();
      await fakeDb.collection('services').doc(serviceId).set({
        'providerId': providerId,
        'categoryId': 'menage',
        'title': 'Ménage à domicile',
        'description': 'Nettoyage complet',
        'photos': <String>[],
        'priceType': 'fixed',
        'price': 50,
        'published': true,
        'serviceZones': <Map>[],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      final snap = await fakeDb.collection('services').doc(serviceId).get();
      expect(snap.exists, isTrue);

      final data = snap.data()!;
      expect(data['categoryId'], 'menage');
      expect(data['published'], isTrue);

      // Verify using the domain model converter
      final service = Service(
        id: snap.id,
        providerId: data['providerId'] as String,
        categoryId: CategoryId.fromString(data['categoryId'] as String),
        title: data['title'] as String,
        photos: const [],
        priceType: PriceType.fixed,
        price: data['price'] as int,
        published: data['published'] as bool,
        createdAt: now,
        updatedAt: now,
      );
      expect(service.categoryId, CategoryId.menage);
      expect(service.published, isTrue);
    });

    // Steps 1 & 3: client creates a booking request → status: requested
    test('Step 1-3 — client creates booking request, status is requested',
        () async {
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Besoin d\'un ménage complet',
      );

      // Verify via the booking repository stream
      final booking = await bookingRepo.watchById(bookingId).first;
      expect(booking, isNotNull);
      expect(booking!.status, BookingStatus.requested);
      expect(booking.customerId, clientId);
      expect(booking.providerId, providerId);
      expect(booking.serviceId, serviceId);
      expect(booking.requestMessage, 'Besoin d\'un ménage complet');
      expect(booking.chatId, isNull);
    });

    // Step 4: provider sees the booking in their inbox (watchForProvider)
    test('Step 4 — provider sees booking in their watchForProvider stream',
        () async {
      await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Test message',
      );

      // Provider's inbox should contain this booking
      final providerBookings =
          await bookingRepo.watchForProvider(providerId).first;
      expect(providerBookings.length, 1);
      expect(providerBookings.first.status, BookingStatus.requested);
      expect(providerBookings.first.customerId, clientId);
    });

    // Step 5: provider accepts → status: accepted, chat created with chatId
    test('Step 5 — provider accepts: status accepted, chatId set', () async {
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Accepte ma demande',
      );

      final chatId = await _simulateAcceptBooking(
        fakeDb: fakeDb,
        bookingId: bookingId,
        clientId: clientId,
        providerId: providerId,
      );

      // Booking should now be accepted and have a chatId
      final booking = await bookingRepo.watchById(bookingId).first;
      expect(booking!.status, BookingStatus.accepted);
      expect(booking.chatId, chatId);
      expect(booking.acceptedAt, isNotNull);
    });

    // Step 6: chat is accessible after acceptance
    test('Step 6 — chat is accessible via watchChat after acceptance',
        () async {
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Chat accessible test',
      );

      final chatId = await _simulateAcceptBooking(
        fakeDb: fakeDb,
        bookingId: bookingId,
        clientId: clientId,
        providerId: providerId,
      );

      // Chat should be watchable
      final chat = await chatRepo.watchChat(chatId).first;
      expect(chat, isNotNull);
      expect(chat!.bookingId, bookingId);
      expect(chat.participantIds, containsAll([clientId, providerId]));
      expect(chat.customerId, clientId);
      expect(chat.providerId, providerId);
    });

    // Step 7: client and provider exchange messages
    test('Step 7 — client and provider send messages in the chat', () async {
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Bonjour',
      );
      final chatId = await _simulateAcceptBooking(
        fakeDb: fakeDb,
        bookingId: bookingId,
        clientId: clientId,
        providerId: providerId,
      );

      final now = DateTime.now().toUtc();

      // Client sends a message
      final clientMsg = ChatMessage(
        id: '',
        chatId: chatId,
        senderId: clientId,
        type: MessageType.text,
        createdAt: now,
        text: 'Bonjour, je confirme le rendez-vous',
      );
      final sentClientMsg = await chatRepo.sendMessage(clientMsg);
      expect(sentClientMsg.id, isNotEmpty);
      expect(sentClientMsg.senderId, clientId);
      expect(sentClientMsg.text, 'Bonjour, je confirme le rendez-vous');

      // Provider sends a reply
      final providerMsg = ChatMessage(
        id: '',
        chatId: chatId,
        senderId: providerId,
        type: MessageType.text,
        createdAt: now.add(const Duration(seconds: 1)),
        text: 'Parfait, je serai là à 10h',
      );
      final sentProviderMsg = await chatRepo.sendMessage(providerMsg);
      expect(sentProviderMsg.id, isNotEmpty);
      expect(sentProviderMsg.senderId, providerId);

      // Watch messages stream — should return both messages
      final messages = await chatRepo
          .watchMessages(chatId: chatId, limit: 50)
          .first;
      expect(messages.length, 2);
      expect(messages.any((m) => m.senderId == clientId), isTrue);
      expect(messages.any((m) => m.senderId == providerId), isTrue);
    });

    // Step 8: provider marks in_progress, client confirms done
    test('Step 8 — booking transitions: accepted → in_progress → done',
        () async {
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Service à effectuer',
      );
      await _simulateAcceptBooking(
        fakeDb: fakeDb,
        bookingId: bookingId,
        clientId: clientId,
        providerId: providerId,
      );

      // Provider marks in progress
      await _simulateMarkInProgress(fakeDb: fakeDb, bookingId: bookingId);
      var booking = await bookingRepo.watchById(bookingId).first;
      expect(booking!.status, BookingStatus.inProgress);
      expect(booking.startedAt, isNotNull);

      // Client confirms done
      await _simulateConfirmDone(fakeDb: fakeDb, bookingId: bookingId);
      booking = await bookingRepo.watchById(bookingId).first;
      expect(booking!.status, BookingStatus.done);
      expect(booking.doneAt, isNotNull);
    });

    // Step 9: client submits a review (5 stars)
    test('Step 9 — client submits a 5-star review for the provider', () async {
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Test review',
      );
      await _simulateAcceptBooking(
        fakeDb: fakeDb,
        bookingId: bookingId,
        clientId: clientId,
        providerId: providerId,
      );
      await _simulateMarkInProgress(fakeDb: fakeDb, bookingId: bookingId);
      await _simulateConfirmDone(fakeDb: fakeDb, bookingId: bookingId);

      final useCase = CreateReviewUseCase(reviewRepo);
      await useCase(
        bookingId: bookingId,
        reviewerId: clientId,
        revieweeId: providerId,
        reviewerRole: ReviewerRole.client,
        rating: 5,
        comment: 'Excellent service, très propre !',
      );

      // Verify review exists for this booking
      final reviews = await reviewRepo.watchForBooking(bookingId).first;
      expect(reviews.length, 1);
      expect(reviews.first.reviewerId, clientId);
      expect(reviews.first.revieweeId, providerId);
      expect(reviews.first.rating, 5);
      expect(reviews.first.reviewerRole, ReviewerRole.client);
      expect(reviews.first.comment, 'Excellent service, très propre !');
    });

    // Step 10: review is visible in the provider's watchForUser stream
    test('Step 10 — review is visible in watchForUser stream for provider',
        () async {
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'Test visibility',
      );
      await _simulateAcceptBooking(
        fakeDb: fakeDb,
        bookingId: bookingId,
        clientId: clientId,
        providerId: providerId,
      );
      await _simulateMarkInProgress(fakeDb: fakeDb, bookingId: bookingId);
      await _simulateConfirmDone(fakeDb: fakeDb, bookingId: bookingId);

      final useCase = CreateReviewUseCase(reviewRepo);
      await useCase(
        bookingId: bookingId,
        reviewerId: clientId,
        revieweeId: providerId,
        reviewerRole: ReviewerRole.client,
        rating: 4,
        comment: 'Bon travail',
      );

      // Provider watches their own reviews (they are the reviewee)
      final providerReviews =
          await reviewRepo.watchForUser(providerId).first;
      expect(providerReviews.length, 1);
      expect(providerReviews.first.revieweeId, providerId);
      expect(providerReviews.first.rating, 4);
    });

    // Full end-to-end: single sequential test covering all 10 steps
    test('Full golden path — all 10 steps in sequence', () async {
      // --- Step 1: simulate client authenticated state (use clientId) ---
      // (authentication itself is handled at the app level; here we just use the uid)

      // --- Step 2: seed a service with category "menage" ---
      final now = DateTime.now().toUtc();
      await fakeDb.collection('services').doc(serviceId).set({
        'providerId': providerId,
        'categoryId': 'menage',
        'title': 'Ménage à domicile',
        'photos': <String>[],
        'priceType': 'fixed',
        'price': 50,
        'published': true,
        'serviceZones': <Map>[],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      final serviceSnap =
          await fakeDb.collection('services').doc(serviceId).get();
      expect(serviceSnap.data()!['categoryId'], 'menage');

      // --- Step 3: client creates a booking → status: requested ---
      final bookingId = await _simulateCreateBooking(
        fakeDb: fakeDb,
        clientId: clientId,
        providerId: providerId,
        serviceId: serviceId,
        requestMessage: 'J\'ai besoin d\'un ménage pour mon appartement',
      );

      var booking = await bookingRepo.watchById(bookingId).first;
      expect(booking!.status, BookingStatus.requested,
          reason: 'Step 3: booking starts as requested');

      // --- Step 4: provider sees the booking in their inbox ---
      final providerInbox =
          await bookingRepo.watchForProvider(providerId).first;
      expect(providerInbox.any((b) => b.id == bookingId), isTrue,
          reason: 'Step 4: booking visible to provider');

      // --- Step 5: provider accepts → status: accepted, chat created ---
      final chatId = await _simulateAcceptBooking(
        fakeDb: fakeDb,
        bookingId: bookingId,
        clientId: clientId,
        providerId: providerId,
      );

      booking = await bookingRepo.watchById(bookingId).first;
      expect(booking!.status, BookingStatus.accepted,
          reason: 'Step 5: booking accepted');
      expect(booking.chatId, chatId,
          reason: 'Step 5: chatId set on booking');

      // --- Step 6: chat is accessible via stream ---
      final chat = await chatRepo.watchChat(chatId).first;
      expect(chat, isNotNull, reason: 'Step 6: chat document exists');
      expect(chat!.participantIds, containsAll([clientId, providerId]),
          reason: 'Step 6: both participants in chat');

      // --- Step 7: client and provider exchange messages ---
      final clientMessage = ChatMessage(
        id: '',
        chatId: chatId,
        senderId: clientId,
        type: MessageType.text,
        createdAt: now.add(const Duration(minutes: 1)),
        text: 'Parfait, à demain 9h !',
      );
      await chatRepo.sendMessage(clientMessage);

      final providerMessage = ChatMessage(
        id: '',
        chatId: chatId,
        senderId: providerId,
        type: MessageType.text,
        createdAt: now.add(const Duration(minutes: 2)),
        text: 'Entendu, je serai ponctuel.',
      );
      await chatRepo.sendMessage(providerMessage);

      final messages =
          await chatRepo.watchMessages(chatId: chatId, limit: 50).first;
      expect(messages.length, 2, reason: 'Step 7: two messages exchanged');
      expect(messages.first.senderId, clientId);
      expect(messages.last.senderId, providerId);

      // --- Step 8: provider marks in_progress then client confirms done ---
      await _simulateMarkInProgress(fakeDb: fakeDb, bookingId: bookingId);
      booking = await bookingRepo.watchById(bookingId).first;
      expect(booking!.status, BookingStatus.inProgress,
          reason: 'Step 8a: in_progress after markInProgress');

      await _simulateConfirmDone(fakeDb: fakeDb, bookingId: bookingId);
      booking = await bookingRepo.watchById(bookingId).first;
      expect(booking!.status, BookingStatus.done,
          reason: 'Step 8b: done after confirmDone');

      // --- Step 9: client submits a 5-star review ---
      final useCase = CreateReviewUseCase(reviewRepo);
      await useCase(
        bookingId: bookingId,
        reviewerId: clientId,
        revieweeId: providerId,
        reviewerRole: ReviewerRole.client,
        rating: 5,
        comment: 'Service impeccable, je recommande !',
      );

      final bookingReviews =
          await reviewRepo.watchForBooking(bookingId).first;
      expect(bookingReviews.length, 1, reason: 'Step 9: review created');
      expect(bookingReviews.first.rating, 5);
      expect(bookingReviews.first.reviewerRole, ReviewerRole.client);

      // --- Step 10: review visible in provider's watchForUser stream ---
      final providerReviews =
          await reviewRepo.watchForUser(providerId).first;
      expect(providerReviews.length, 1,
          reason: 'Step 10: review visible to provider');
      expect(providerReviews.first.revieweeId, providerId);
      expect(providerReviews.first.rating, 5);
    });
  });
}
