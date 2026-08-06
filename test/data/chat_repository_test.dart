// Tests for FirestoreChatRepository using FakeFirebaseFirestore.
//
// Covered:
//   - watchChat(chatId): streams a single chat doc (null when absent)
//   - watchForUser(uid): returns chats containing uid in participantIds
//   - watchMessages(chatId): streams messages ordered by createdAt
//   - sendMessage(): writes to messages subcollection and returns with id
//   - softDeleteMessage(): calls injected delete fn with correct args
//   - editMessage(): updates text and sets edited=true
//   - setReaction(): sets or removes a per-user emoji reaction
//   - markMessagesRead(): batch-updates readBy for unread messages from others
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
  List<String> readBy = const [],
}) {
  return ChatMessage(
    id: id,
    chatId: chatId,
    senderId: senderId,
    type: MessageType.text,
    createdAt: createdAt ?? DateTime(2024, 6, 1, 10).toUtc(),
    text: text,
    readBy: readBy,
  );
}

Future<void> _writeChat(FakeFirebaseFirestore db, Chat chat) {
  return FirestoreCollections.chats(db).doc(chat.id).set(chat);
}

Future<void> _writeMessage(FakeFirebaseFirestore db, ChatMessage msg) {
  return FirestoreCollections.chatMessages(
    db: db,
    chatId: msg.chatId,
  ).doc(msg.id).set(msg);
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
        _makeChat(
          id: 'older',
          participantIds: ['user_A', 'user_B'],
          lastMessageAt: t1,
        ),
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
      await _writeMessage(fakeDb, _makeMessage(id: 'm1', chatId: 'chat_1'));
      await _writeMessage(fakeDb, _makeMessage(id: 'm2', chatId: 'chat_2'));

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
        _makeMessage(
          id: 'm1',
          chatId: 'chat_1',
          senderId: 'user_B',
          text: 'Bonjour',
        ),
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
  // watchChat
  // -------------------------------------------------------------------------

  group('watchChat', () {
    test('returns null when chat does not exist', () async {
      final result = await repo.watchChat('no_such_chat').first;
      expect(result, isNull);
    });

    test('returns Chat when the document exists', () async {
      final chat = _makeChat(id: 'chat_x');
      await _writeChat(fakeDb, chat);

      final result = await repo.watchChat('chat_x').first;
      expect(result, isNotNull);
      expect(result!.id, 'chat_x');
      expect(result.bookingId, chat.bookingId);
    });
  });

  // -------------------------------------------------------------------------
  // softDeleteMessage
  // -------------------------------------------------------------------------

  group('softDeleteMessage', () {
    test(
      'calls the injected delete fn with correct chatId and messageId',
      () async {
        final calls = <(String, String)>[];
        final testRepo = FirestoreChatRepository(
          fakeDb,
          deleteMessageFn: (chatId, messageId) async {
            calls.add((chatId, messageId));
          },
        );

        await testRepo.softDeleteMessage(chatId: 'chat_1', messageId: 'msg_42');

        expect(calls.length, 1);
        expect(calls.first.$1, 'chat_1');
        expect(calls.first.$2, 'msg_42');
      },
    );

    test('propagates errors thrown by the delete fn', () async {
      final testRepo = FirestoreChatRepository(
        fakeDb,
        deleteMessageFn: (_, __) async => throw Exception('network failure'),
      );

      await expectLater(
        testRepo.softDeleteMessage(chatId: 'chat_1', messageId: 'msg_1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // editMessage
  // -------------------------------------------------------------------------

  group('editMessage', () {
    test('updates text and sets edited=true', () async {
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'msg_1', chatId: 'chat_1', text: 'original'),
      );

      await repo.editMessage(
        chatId: 'chat_1',
        messageId: 'msg_1',
        newText: 'updated text',
      );

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).doc('msg_1').get();
      final msg = snap.data()!;
      expect(msg.text, 'updated text');
      expect(msg.edited, true);
    });

    test('completes without error', () async {
      await _writeMessage(fakeDb, _makeMessage(id: 'msg_2', chatId: 'chat_1'));

      await expectLater(
        repo.editMessage(
          chatId: 'chat_1',
          messageId: 'msg_2',
          newText: 'new text',
        ),
        completes,
      );
    });
  });

  // -------------------------------------------------------------------------
  // setReaction
  // -------------------------------------------------------------------------

  group('setReaction', () {
    test('sets an emoji reaction for a uid', () async {
      await _writeMessage(fakeDb, _makeMessage(id: 'msg_1', chatId: 'chat_1'));

      await repo.setReaction(
        chatId: 'chat_1',
        messageId: 'msg_1',
        uid: 'user_A',
        emoji: '👍',
      );

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).doc('msg_1').get();
      expect(snap.data()!.reactions['user_A'], '👍');
    });

    test('removes the reaction when emoji is null', () async {
      await _writeMessage(fakeDb, _makeMessage(id: 'msg_1', chatId: 'chat_1'));
      await repo.setReaction(
        chatId: 'chat_1',
        messageId: 'msg_1',
        uid: 'user_A',
        emoji: '❤️',
      );

      await repo.setReaction(
        chatId: 'chat_1',
        messageId: 'msg_1',
        uid: 'user_A',
        emoji: null,
      );

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).doc('msg_1').get();
      expect(snap.data()!.reactions.containsKey('user_A'), false);
    });

    test('multiple uids can each have their own reaction', () async {
      await _writeMessage(fakeDb, _makeMessage(id: 'msg_1', chatId: 'chat_1'));

      await repo.setReaction(
        chatId: 'chat_1',
        messageId: 'msg_1',
        uid: 'user_A',
        emoji: '👍',
      );
      await repo.setReaction(
        chatId: 'chat_1',
        messageId: 'msg_1',
        uid: 'user_B',
        emoji: '😂',
      );

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).doc('msg_1').get();
      expect(snap.data()!.reactions['user_A'], '👍');
      expect(snap.data()!.reactions['user_B'], '😂');
    });
  });

  // -------------------------------------------------------------------------
  // markMessagesRead
  // -------------------------------------------------------------------------

  group('markMessagesRead', () {
    test('adds uid to readBy for messages sent by others', () async {
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'msg_1', chatId: 'chat_1', senderId: 'user_B'),
      );

      await repo.markMessagesRead(chatId: 'chat_1', uid: 'user_A');

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).doc('msg_1').get();
      expect(snap.data()!.readBy, contains('user_A'));
    });

    test('does not update messages sent by uid', () async {
      await _writeMessage(
        fakeDb,
        _makeMessage(id: 'msg_own', chatId: 'chat_1', senderId: 'user_A'),
      );

      await repo.markMessagesRead(chatId: 'chat_1', uid: 'user_A');

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).doc('msg_own').get();
      expect(snap.data()!.readBy, isNot(contains('user_A')));
    });

    test('does not add uid twice if already in readBy', () async {
      await _writeMessage(
        fakeDb,
        _makeMessage(
          id: 'msg_1',
          chatId: 'chat_1',
          senderId: 'user_B',
          readBy: ['user_A'],
        ),
      );

      await repo.markMessagesRead(chatId: 'chat_1', uid: 'user_A');

      final snap = await FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: 'chat_1',
      ).doc('msg_1').get();
      expect(snap.data()!.readBy.where((id) => id == 'user_A').length, 1);
    });

    test('no-op (no commit) when all messages are already read', () async {
      await _writeMessage(
        fakeDb,
        _makeMessage(
          id: 'msg_1',
          chatId: 'chat_1',
          senderId: 'user_B',
          readBy: ['user_A'],
        ),
      );

      await expectLater(
        repo.markMessagesRead(chatId: 'chat_1', uid: 'user_A'),
        completes,
      );
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

    test(
      'returns DateTime when another user has a typing doc with Timestamp',
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
      },
    );

    test(
      'returns null when other typing doc exists but updatedAt is absent',
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
      },
    );
  });
}
