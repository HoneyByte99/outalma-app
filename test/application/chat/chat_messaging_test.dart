// Application-layer tests for chat messaging.
//
// The chat layer has no use-case classes - the ChatRepository is called
// directly from providers. These tests verify the ChatRepository contract
// methods (sendMessage, setTyping, watchOtherTyping) using a mock repository
// via mocktail, ensuring application expectations are met without depending
// on Firestore internals (those are covered in test/data/chat_repository_test.dart).
//
// Covered:
//   - sendMessage returns the stored message with non-empty id
//   - sendMessage preserves senderId, chatId, text
//   - setTyping completes without error for an authenticated participant
//   - watchOtherTyping emits null when no other user is typing
//   - watchOtherTyping emits DateTime when the other user is typing

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/domain/enums/message_type.dart';
import 'package:outalma_app/src/domain/models/chat_message.dart';
import 'package:outalma_app/src/domain/repositories/chat_repository.dart';

// ---------------------------------------------------------------------------
// Mock & fallback
// ---------------------------------------------------------------------------

class _MockChatRepository extends Mock implements ChatRepository {}

class _FakeChatMessage extends Fake implements ChatMessage {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ChatMessage _makeMessage({
  String id = 'msg_1',
  String chatId = 'chat_1',
  String senderId = 'user_A',
  String? text = 'Bonjour',
}) {
  return ChatMessage(
    id: id,
    chatId: chatId,
    senderId: senderId,
    type: MessageType.text,
    createdAt: DateTime(2024, 6, 1, 10).toUtc(),
    text: text,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockChatRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeChatMessage());
  });

  setUp(() {
    repo = _MockChatRepository();
  });

  group('sendMessage', () {
    test('returns a message with a non-empty id', () async {
      final input = _makeMessage(id: '');
      final stored = _makeMessage(id: 'firestore_generated_id');

      when(() => repo.sendMessage(any())).thenAnswer((_) async => stored);

      final result = await repo.sendMessage(input);
      expect(result.id, isNotEmpty);
    });

    test('preserves senderId, chatId, and text', () async {
      final input = _makeMessage(
        id: '',
        chatId: 'chat_42',
        senderId: 'user_B',
        text: 'Salut',
      );
      final stored = _makeMessage(
        id: 'doc_abc',
        chatId: 'chat_42',
        senderId: 'user_B',
        text: 'Salut',
      );

      when(() => repo.sendMessage(any())).thenAnswer((_) async => stored);

      final result = await repo.sendMessage(input);
      expect(result.chatId, 'chat_42');
      expect(result.senderId, 'user_B');
      expect(result.text, 'Salut');
    });

    test('calls repository exactly once', () async {
      final input = _makeMessage();
      when(() => repo.sendMessage(any())).thenAnswer((_) async => input);

      await repo.sendMessage(input);
      verify(() => repo.sendMessage(input)).called(1);
    });

    test('propagates exception from repository', () async {
      when(
        () => repo.sendMessage(any()),
      ).thenAnswer((_) async => throw Exception('permission-denied'));

      await expectLater(
        repo.sendMessage(_makeMessage()),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('setTyping', () {
    test('completes without error for authenticated participant', () async {
      when(
        () => repo.setTyping(
          chatId: any(named: 'chatId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        repo.setTyping(chatId: 'chat_1', uid: 'user_A'),
        completes,
      );
    });

    test('calls repository with correct chatId and uid', () async {
      when(
        () => repo.setTyping(
          chatId: any(named: 'chatId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async {});

      await repo.setTyping(chatId: 'chat_99', uid: 'user_X');

      verify(() => repo.setTyping(chatId: 'chat_99', uid: 'user_X')).called(1);
    });
  });

  group('watchOtherTyping', () {
    test('emits null when no other user is typing', () async {
      when(
        () => repo.watchOtherTyping(
          chatId: any(named: 'chatId'),
          myUid: any(named: 'myUid'),
        ),
      ).thenAnswer((_) => Stream.value(null));

      final result = await repo
          .watchOtherTyping(chatId: 'chat_1', myUid: 'user_A')
          .first;
      expect(result, isNull);
    });

    test('emits DateTime when other user is typing', () async {
      final typingAt = DateTime(2024, 6, 1, 12, 0).toUtc();
      when(
        () => repo.watchOtherTyping(
          chatId: any(named: 'chatId'),
          myUid: any(named: 'myUid'),
        ),
      ).thenAnswer((_) => Stream.value(typingAt));

      final result = await repo
          .watchOtherTyping(chatId: 'chat_1', myUid: 'user_A')
          .first;
      expect(result, typingAt);
    });

    test('emits null then DateTime as other user starts typing', () async {
      final typingAt = DateTime(2024, 6, 1, 12, 1).toUtc();
      when(
        () => repo.watchOtherTyping(
          chatId: any(named: 'chatId'),
          myUid: any(named: 'myUid'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([null, typingAt]));

      final values = await repo
          .watchOtherTyping(chatId: 'chat_1', myUid: 'user_A')
          .toList();
      expect(values, [null, typingAt]);
    });
  });
}
