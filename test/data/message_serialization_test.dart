// Verifies that ChatMessage objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// Critical cases:
//   - MessageType enum: text, image, voice (and unknown fallback)
//   - Optional fields: text and mediaUrl null / non-null
//   - readBy list roundtrip (empty and populated)
//   - createdAt Timestamp ↔ DateTime conversion

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/message_type.dart';
import 'package:outalma_app/src/domain/models/chat_message.dart';

const _kChatId = 'chat_1';

ChatMessage _makeMessage({
  String id = 'msg_1',
  String chatId = _kChatId,
  String senderId = 'user_sender',
  MessageType type = MessageType.text,
  DateTime? createdAt,
  String? text,
  String? mediaUrl,
  List<String> readBy = const [],
}) {
  return ChatMessage(
    id: id,
    chatId: chatId,
    senderId: senderId,
    type: type,
    createdAt: createdAt ?? DateTime(2024, 4, 1, 9, 0).toUtc(),
    text: text,
    mediaUrl: mediaUrl,
    readBy: readBy,
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('ChatMessage serialization — text type', () {
    test('text message roundtrips with text field populated', () async {
      final msg = _makeMessage(
        type: MessageType.text,
        text: 'Bonjour, je serai là à 10h.',
      );
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);
      final result = (await col.doc(msg.id).get()).data()!;

      expect(result.id, msg.id);
      expect(result.chatId, _kChatId);
      expect(result.senderId, 'user_sender');
      expect(result.type, MessageType.text);
      expect(result.text, 'Bonjour, je serai là à 10h.');
      expect(result.mediaUrl, isNull);
    });

    test('type stored as "text" string in Firestore', () async {
      final msg = _makeMessage(type: MessageType.text, text: 'hello');
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);

      final raw =
          (await fakeDb
                  .collection('chats')
                  .doc(_kChatId)
                  .collection('messages')
                  .doc(msg.id)
                  .get())
              .data()!;
      expect(raw['type'], 'text');
    });
  });

  group('ChatMessage serialization — image type', () {
    test('image message roundtrips with mediaUrl populated', () async {
      final msg = _makeMessage(
        id: 'msg_img',
        type: MessageType.image,
        mediaUrl: 'gs://bucket/images/photo.jpg',
      );
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);
      final result = (await col.doc(msg.id).get()).data()!;

      expect(result.type, MessageType.image);
      expect(result.mediaUrl, 'gs://bucket/images/photo.jpg');
      expect(result.text, isNull);
    });

    test('type stored as "image" string in Firestore', () async {
      final msg = _makeMessage(
        id: 'msg_img_raw',
        type: MessageType.image,
        mediaUrl: 'gs://bucket/photo.jpg',
      );
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);

      final raw =
          (await fakeDb
                  .collection('chats')
                  .doc(_kChatId)
                  .collection('messages')
                  .doc(msg.id)
                  .get())
              .data()!;
      expect(raw['type'], 'image');
    });
  });

  group('ChatMessage serialization — voice type', () {
    test('voice message roundtrips with mediaUrl populated', () async {
      final msg = _makeMessage(
        id: 'msg_voice',
        type: MessageType.voice,
        mediaUrl: 'gs://bucket/audio/voice.m4a',
      );
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);
      final result = (await col.doc(msg.id).get()).data()!;

      expect(result.type, MessageType.voice);
      expect(result.mediaUrl, 'gs://bucket/audio/voice.m4a');
    });

    test('type stored as "voice" string in Firestore', () async {
      final msg = _makeMessage(
        id: 'msg_voice_raw',
        type: MessageType.voice,
        mediaUrl: 'gs://bucket/voice.m4a',
      );
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);

      final raw =
          (await fakeDb
                  .collection('chats')
                  .doc(_kChatId)
                  .collection('messages')
                  .doc(msg.id)
                  .get())
              .data()!;
      expect(raw['type'], 'voice');
    });
  });

  group('ChatMessage serialization — MessageType enum fallback', () {
    test('unknown type string falls back to text', () async {
      await fakeDb
          .collection('chats')
          .doc(_kChatId)
          .collection('messages')
          .doc('bad_type')
          .set({
            'chatId': _kChatId,
            'senderId': 'u1',
            'type': 'sticker', // unknown
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
          });
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      final result = (await col.doc('bad_type').get()).data()!;
      expect(result.type, MessageType.text);
    });
  });

  group('ChatMessage serialization — createdAt timestamp', () {
    test('createdAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 6, 15, 7, 45, 0).toUtc();
      final msg = _makeMessage(createdAt: t, text: 'hello');
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);
      final result = (await col.doc(msg.id).get()).data()!;

      expect(result.createdAt.millisecondsSinceEpoch, t.millisecondsSinceEpoch);
    });

    test('createdAt is stored as Firestore Timestamp', () async {
      final msg = _makeMessage(text: 'ts check');
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);

      final raw =
          (await fakeDb
                  .collection('chats')
                  .doc(_kChatId)
                  .collection('messages')
                  .doc(msg.id)
                  .get())
              .data()!;
      expect(raw['createdAt'], isA<Timestamp>());
    });
  });

  group('ChatMessage serialization — readBy list', () {
    test('empty readBy list roundtrips as empty', () async {
      final msg = _makeMessage(id: 'msg_unread', readBy: []);
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);
      final result = (await col.doc(msg.id).get()).data()!;
      expect(result.readBy, isEmpty);
    });

    test('populated readBy list roundtrips correctly', () async {
      final msg = _makeMessage(
        id: 'msg_read',
        readBy: ['uid_alice', 'uid_bob'],
      );
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);
      final result = (await col.doc(msg.id).get()).data()!;

      expect(result.readBy, hasLength(2));
      expect(result.readBy, contains('uid_alice'));
      expect(result.readBy, contains('uid_bob'));
    });
  });

  group('ChatMessage serialization — null fields', () {
    test('text and mediaUrl both null roundtrip as null', () async {
      final msg = _makeMessage(
        id: 'msg_nulls',
        type: MessageType.text,
        text: null,
        mediaUrl: null,
      );
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      await col.doc(msg.id).set(msg);
      final result = (await col.doc(msg.id).get()).data()!;
      expect(result.text, isNull);
      expect(result.mediaUrl, isNull);
    });

    test('missing fields in Firestore use safe defaults', () async {
      await fakeDb
          .collection('chats')
          .doc(_kChatId)
          .collection('messages')
          .doc('minimal')
          .set({'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc())});
      final col = FirestoreCollections.chatMessages(
        db: fakeDb,
        chatId: _kChatId,
      );
      final result = (await col.doc('minimal').get()).data()!;

      expect(result.chatId, '');
      expect(result.senderId, '');
      expect(result.type, MessageType.text);
      expect(result.text, isNull);
      expect(result.mediaUrl, isNull);
      expect(result.readBy, isEmpty);
    });
  });
}
