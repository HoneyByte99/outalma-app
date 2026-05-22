// Tests for FirestoreChatRepository using FakeFirebaseFirestore.
//
// Covered:
//   - watchForUser(uid): returns chats containing uid in participantIds
//   - watchMessages(chatId): streams messages ordered by createdAt
//   - sendMessage(): writes to messages subcollection and returns with id
//   - setTyping(): writes to typing subcollection
//   - watchOtherTyping(): returns null when no other typers, DateTime when someone is typing

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/data/repositories/firestore_chat_repository.dart';
import 'package:outalma_app/src/domain/enums/message_type.dart';
import 'package:outalma_app/src/domain/models/chat.dart';
import 'package:outalma_app/src/domain/models/chat_message.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Chat _makeChat({
  String id = 'chat_1',
  List<String> participantIds = const ['user_A', 'user_B'],
  String bookingId = 'booking_1',
  DateTime? lastMessageAt,
  String customerId = 'user_A',
  String providerId = 'user_B',
}) {
  final now = DateTime(2024, 6, 1).toUtc();
  return Chat(
    id: id,
    bookingId: bookingId,
    participantIds: participantIds,
    createdAt: now,
    lastMessageAt: lastMessageAt,
    customerId: customerId,
    providerId: providerId,
  );
}

ChatMessage _makeMessage({
  String id = 'msg_1',
  String chatId = 'chat_1',
  String senderId = 'user_A',
  DateTime? createdAt,
  String? text = 'Hello',
}) {
  return ChatMessage(
    id: id,
    chatId: chatId,
    senderId: senderId,
    type: MessageType.text,
    createdAt: createdAt ?? DateTime(2024, 6, 1, 10).toUtc(),
    text: text,
  );
}

Future<void> _writeChat(FakeFirebaseFirestore db, Chat chat) {
  return FirestoreCollections.chats(db).doc(chat.id).set(chat);
}

Future<void> _writeMessage(FakeFirebaseFirestore db, ChatMessage msg) {
  return FirestoreCollections.chatMessages(db: db, chatId: msg.chatId)
      .doc(msg.id)
      .set(msg);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreChatRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestoreChatRepository(fakeDb);
  });

  // -------------------------------------------------------------------------
  // watchForUser
  // -------------------------------------------------------------------------

  group('watchForUser', () {
    test('returns empty list when no chats exist', () async {
      final list = await repo.watchForUser('user_X').first;
      expect(list, isEmpty);
    });

    test('returns chats containing the uid in participantIds', () async {
      await _writeChat(
        fakeDb,
        _makeChat(id: 'c1', participantIds: ['user_A', 'user_B']),
      );
      await _writeChat(
        fakeDb,
        _makeChat(
          id: 'c2',
          participantIds: ['user_A', 'user_C'],
          bookingId: 'booking_2',
          customerId: 'user_A',
          providerId: 'user_C',
        ),
      );
      await _writeChat(
        fakeDb,
        _makeChat(
          id: 'c3',
          participantIds: ['user_B', 'user_C'],
          bookingId: 'booking_3',
          customerId: 'user_B',
          providerId: 'user_C',
        ),
      );

      final list = await repo.watchForUser('user_A').first;
      expect(list.length, 2);
      expect(list.map((c) => c.id), containsAll(['c1', 'c2']));
    });

    test('does not include chats where uid is not a participant', () async {
      await _writeChat(
        fakeDb,
        _makeChat(id: 'c1', participantIds: ['user_B', 'user_C']),
      );

      final list = await repo.watchForUser('user_A').first;
      expect(list, isEmpty);
    });

    test('sorts chats by lastMessageAt descending', () async {
      final t1 = DateTime(2024, 1, 1).toUtc();
      final t2 = DateTime(2024, 3, 1).toUtc();
      await _writeChat(
        fakeDb,
        _makeChat(id: 'older', participantIds: ['user_A', 'user_B'], lastMessageAt: t1),
      );
      await _writeChat(
        fakeDb,
        _makeChat(
          id: 'newer',
          participantIds: ['user_A', 'user_B'],
          lastMessageAt: t2,
          bookingId: 'booking_2',
        ),
      );

      final list = await repo.watchForUser('user_A').first;
      expect(list.first.id, 'newer');
      expect(list.last.id, 'older');
    });
  });

  // -------------------------------------------------------------------------
  // watchMessages
  // -------------------------------------------------------------------------

  group('watchMessages', () {
    test('returns empty list when no messages exist', () async {
      final list = await repo.watchMessages(chatId: 'chat_1').first;
      expect(list, isEmpty);
    });

    test('returns messages for the correct chat', () async {
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'm1', chatId: 'chat_1'),
      );
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'm2', chatId: 'chat_2'),
      );

      final list = await repo.watchMessages(chatId: 'chat_1').first;
      expect(list.length, 1);
      expect(list.first.id, 'm1');
    });

    test('returns messages ordered by createdAt ascending', () async {
      final early = DateTime(2024, 1, 1, 9).toUtc();
      final late_ = DateTime(2024, 1, 1, 11).toUtc();
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'late_msg', chatId: 'chat_1', createdAt: late_),
      );
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'early_msg', chatId: 'chat_1', createdAt: early),
      );

      final list = await repo.watchMessages(chatId: 'chat_1').first;
      expect(list.first.id, 'early_msg');
      expect(list.last.id, 'late_msg');
    });

    test('returns correct message fields', () async {
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'm1', chatId: 'chat_1', senderId: 'user_B', text: 'Bonjour'),
      );

      final list = await repo.watchMessages(chatId: 'chat_1').first;
      final msg = list.first;
      expect(msg.senderId, 'user_B');
      expect(msg.text, 'Bonjour');
      expect(msg.type, MessageType.text);
    });
  });

  // -------------------------------------------------------------------------
  // sendMessage
  // -------------------------------------------------------------------------

  group('sendMessage', () {
    test('writes message to messages subcollection', () async {
      final message = _makeMessage(id: 'new_msg', chatId: 'chat_1');
      await repo.sendMessage(message);

      final snap = await fakeDb
          .collection('chats')
          .doc('chat_1')
          .collection('messages')
          .get();
      expect(snap.docs.length, 1);
    });

    test('returns message with id set', () async {
      final message = _makeMessage(id: 'new_msg', chatId: 'chat_1');
      final result = await repo.sendMessage(message);
      expect(result.id, isNotEmpty);
    });

    test('persists correct senderId and text', () async {
      final message = _makeMessage(
        id: 'msg_x',
        chatId: 'chat_1',
        senderId: 'user_B',
        text: 'Salut!',
      );
      await repo.sendMessage(message);

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).get();
      final saved = snap.docs.first.data();
      expect(saved.senderId, 'user_B');
      expect(saved.text, 'Salut!');
    });
  });

  // -------------------------------------------------------------------------
  // setTyping
  // -------------------------------------------------------------------------

  group('setTyping', () {
    test('writes to typing subcollection under the user uid', () async {
      await repo.setTyping(chatId: 'chat_1', uid: 'user_A');

      final snap = await fakeDb
          .collection('chats')
          .doc('chat_1')
          .collection('typing')
          .doc('user_A')
          .get();
      expect(snap.exists, true);
    });

    test('document contains updatedAt field', () async {
      await repo.setTyping(chatId: 'chat_1', uid: 'user_B');

      final snap = await fakeDb
          .collection('chats')
          .doc('chat_1')
          .collection('typing')
          .doc('user_B')
          .get();
      expect(snap.data()?.containsKey('updatedAt'), true);
    });

    test('completes without error', () async {
      await expectLater(
        repo.setTyping(chatId: 'chat_1', uid: 'user_C'),
        completes,
      );
    });
  });

  // -------------------------------------------------------------------------
  // watchOtherTyping
  // -------------------------------------------------------------------------

  group('watchOtherTyping', () {
    test('returns null when no one else is typing', () async {
      final result = await repo
          .watchOtherTyping(chatId: 'chat_1', myUid: 'user_A')
          .first;
      expect(result, isNull);
    });

    test('returns null when only myUid has a typing doc', () async {
      await fakeDb
          .collection('chats')
          .doc('chat_1')
          .collection('typing')
          .doc('user_A')
          .set({'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc())});

      final result = await repo
          .watchOtherTyping(chatId: 'chat_1', myUid: 'user_A')
          .first;
      expect(result, isNull);
    });

    test('returns DateTime when another user has a typing doc with Timestamp',
        () async {
      final ts = DateTime(2024, 6, 1, 12, 0).toUtc();
      await fakeDb
          .collection('chats')
          .doc('chat_1')
          .collection('typing')
          .doc('user_B')
          .set({'updatedAt': Timestamp.fromDate(ts)});

      final result = await repo
          .watchOtherTyping(chatId: 'chat_1', myUid: 'user_A')
          .first;
      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, ts.millisecondsSinceEpoch);
    });

    test('returns null when other typing doc exists but updatedAt is absent',
        () async {
      await fakeDb
          .collection('chats')
          .doc('chat_1')
          .collection('typing')
          .doc('user_B')
          .set({'updatedAt': null});

      final result = await repo
          .watchOtherTyping(chatId: 'chat_1', myUid: 'user_A')
          .first;
      expect(result, isNull);
    });
  });
}
