// Verifies that Chat objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// Critical cases:
//   - participantIds list roundtrip (populated and empty)
//   - lastMessageAt null / non-null (acceptedAt timestamp analog)
//   - customerId / providerId default to empty string (legacy docs)
//   - createdAt Timestamp ↔ DateTime conversion

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/models/chat.dart';

Chat _makeChat({
  String id = 'chat_1',
  String bookingId = 'booking_1',
  List<String> participantIds = const ['user_a', 'user_b'],
  DateTime? createdAt,
  DateTime? lastMessageAt,
  String customerId = '',
  String providerId = '',
}) {
  return Chat(
    id: id,
    bookingId: bookingId,
    participantIds: participantIds,
    createdAt: createdAt ?? DateTime(2024, 2, 20, 14, 0).toUtc(),
    lastMessageAt: lastMessageAt,
    customerId: customerId,
    providerId: providerId,
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('Chat serialization — all fields populated', () {
    test('roundtrip preserves all fields', () async {
      final t = DateTime(2024, 2, 20, 14, 0).toUtc();
      final lastMsg = DateTime(2024, 2, 20, 15, 30).toUtc();
      final chat = _makeChat(
        createdAt: t,
        lastMessageAt: lastMsg,
        customerId: 'customer_abc',
        providerId: 'provider_xyz',
      );
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);
      final result = (await col.doc(chat.id).get()).data()!;

      expect(result.id, chat.id);
      expect(result.bookingId, 'booking_1');
      expect(result.participantIds, ['user_a', 'user_b']);
      expect(result.customerId, 'customer_abc');
      expect(result.providerId, 'provider_xyz');
    });
  });

  group('Chat serialization — participantIds list', () {
    test('participantIds list with two entries roundtrips correctly', () async {
      final chat = _makeChat(participantIds: ['uid_client', 'uid_provider']);
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);
      final result = (await col.doc(chat.id).get()).data()!;

      expect(result.participantIds, hasLength(2));
      expect(result.participantIds, contains('uid_client'));
      expect(result.participantIds, contains('uid_provider'));
    });

    test('empty participantIds list roundtrips as empty list', () async {
      final chat = _makeChat(id: 'chat_empty', participantIds: []);
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);
      final result = (await col.doc(chat.id).get()).data()!;
      expect(result.participantIds, isEmpty);
    });
  });

  group('Chat serialization — lastMessageAt timestamp', () {
    test('lastMessageAt is null when not set', () async {
      final chat = _makeChat(lastMessageAt: null);
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);
      final result = (await col.doc(chat.id).get()).data()!;
      expect(result.lastMessageAt, isNull);
    });

    test('lastMessageAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 4, 5, 11, 22, 33).toUtc();
      final chat = _makeChat(lastMessageAt: t);
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);
      final result = (await col.doc(chat.id).get()).data()!;

      expect(
        result.lastMessageAt?.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
      );
    });

    test('lastMessageAt is stored as Firestore Timestamp when set', () async {
      final t = DateTime(2024, 4, 5).toUtc();
      final chat = _makeChat(id: 'chat_ts', lastMessageAt: t);
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);

      final raw = (await fakeDb.collection('chats').doc(chat.id).get()).data()!;
      expect(raw['lastMessageAt'], isA<Timestamp>());
    });
  });

  group('Chat serialization — createdAt timestamp', () {
    test('createdAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 2, 20, 14, 0).toUtc();
      final chat = _makeChat(createdAt: t);
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);
      final result = (await col.doc(chat.id).get()).data()!;

      expect(result.createdAt.millisecondsSinceEpoch, t.millisecondsSinceEpoch);
    });

    test('createdAt is stored as Firestore Timestamp', () async {
      final chat = _makeChat();
      final col = FirestoreCollections.chats(fakeDb);
      await col.doc(chat.id).set(chat);

      final raw = (await fakeDb.collection('chats').doc(chat.id).get()).data()!;
      expect(raw['createdAt'], isA<Timestamp>());
    });
  });

  group('Chat serialization — legacy / missing fields', () {
    test('missing customerId and providerId default to empty string', () async {
      // Simulates a legacy document written before acceptBooking set these fields
      await fakeDb.collection('chats').doc('legacy_chat').set({
        'bookingId': 'b1',
        'participantIds': ['u1', 'u2'],
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.chats(fakeDb);
      final result = (await col.doc('legacy_chat').get()).data()!;

      expect(result.customerId, '');
      expect(result.providerId, '');
    });

    test('missing fields do not crash and use safe defaults', () async {
      await fakeDb.collection('chats').doc('minimal').set({
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.chats(fakeDb);
      final result = (await col.doc('minimal').get()).data()!;

      expect(result.bookingId, '');
      expect(result.participantIds, isEmpty);
      expect(result.lastMessageAt, isNull);
      expect(result.customerId, '');
      expect(result.providerId, '');
    });
  });
}
