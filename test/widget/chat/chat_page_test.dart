// Harness widget tests for ChatPage.
// Overrides chatMessagesProvider (empty list or seeded messages), chatDetailProvider,
// authNotifierProvider, and chatRepositoryProvider so no Firebase is required.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/chat/chat_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/message_type.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/chat.dart';
import 'package:outalma_app/src/domain/models/chat_message.dart';
import 'package:outalma_app/src/domain/repositories/chat_repository.dart';
import 'package:outalma_app/src/features/chat/chat_page.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'user_1',
      displayName: 'Test User',
      email: 'test@test.com',
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

class _FakeChatRepository implements ChatRepository {
  List<String> deletedMessageIds = [];
  bool shouldThrowOnDelete = false;

  @override
  Stream<Chat?> watchChat(String chatId) => Stream.value(null);

  @override
  Stream<List<Chat>> watchForUser(String uid) => Stream.value([]);

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String chatId,
    int limit = 50,
  }) => Stream.value([]);

  @override
  Future<ChatMessage> sendMessage(ChatMessage message) async => message;

  @override
  Future<void> softDeleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    if (shouldThrowOnDelete) throw Exception('network error');
    deletedMessageIds.add(messageId);
  }

  @override
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {}

  @override
  Future<void> setReaction({
    required String chatId,
    required String messageId,
    required String uid,
    String? emoji,
  }) async {}

  @override
  Future<void> markMessagesRead({
    required String chatId,
    required String uid,
  }) async {}

  @override
  Future<void> setTyping({required String chatId, required String uid}) async {}

  @override
  Stream<DateTime?> watchOtherTyping({
    required String chatId,
    required String myUid,
  }) => Stream.value(null);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ChatMessage _makeMessage({
  String id = 'msg_1',
  String senderId = 'user_1',
  String text = 'Hello',
  bool deleted = false,
  bool isPending = false,
}) => ChatMessage(
  id: id,
  chatId: 'chat_1',
  senderId: senderId,
  type: MessageType.text,
  createdAt: DateTime(2024, 6, 1, 12),
  text: text,
  deleted: deleted,
  isPending: isPending,
);

Widget _wrap({List<ChatMessage> messages = const [], ChatRepository? repo}) {
  final fakeRepo = repo ?? _FakeChatRepository();
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
      chatRepositoryProvider.overrideWithValue(fakeRepo),
      chatMessagesProvider(
        'chat_1',
      ).overrideWith((_) => Stream.value(messages)),
      chatDetailProvider('chat_1').overrideWith((_) => Stream.value(null)),
      otherTypingProvider('chat_1').overrideWith((_) => Stream.value(null)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ChatPage(chatId: 'chat_1'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatPage', () {
    testWidgets('smoke - renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(ChatPage), findsOneWidget);
    });

    testWidgets('message input TextField is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('mic/send action button is present in input bar', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      final hasMic = tester.any(find.byIcon(Icons.mic_rounded));
      final hasSend = tester.any(find.byIcon(Icons.send_rounded));
      expect(hasMic || hasSend, isTrue);
    });
  });

  group('ChatPage - deleted message display', () {
    testWidgets('renders deleted placeholder when message.deleted is true', (
      tester,
    ) async {
      final msg = _makeMessage(deleted: true, text: 'original text');
      await tester.pumpWidget(_wrap(messages: [msg]));
      await tester.pump();
      await tester.pump();

      // The original text must NOT appear.
      expect(find.text('original text'), findsNothing);

      // The deleted placeholder ("Message deleted") must appear.
      expect(find.text('Message deleted'), findsOneWidget);
    });

    testWidgets('renders message text when deleted is false', (tester) async {
      final msg = _makeMessage(text: 'visible text');
      await tester.pumpWidget(_wrap(messages: [msg]));
      await tester.pump();
      await tester.pump();

      expect(find.text('visible text'), findsOneWidget);
      expect(find.text('Message deleted'), findsNothing);
    });
  });

  group('ChatPage - send status', () {
    testWidgets('shows clock icon for pending own message', (tester) async {
      final msg = _makeMessage(isPending: true);
      await tester.pumpWidget(_wrap(messages: [msg]));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('shows checkmark icon for delivered own message', (
      tester,
    ) async {
      final msg = _makeMessage(isPending: false);
      await tester.pumpWidget(_wrap(messages: [msg]));
      await tester.pump();
      await tester.pump();

      // Message is not read (readBy empty), so done_rounded shows.
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    });
  });

  group('ChatPage - delete action authorization', () {
    testWidgets('long press own message shows Delete option in bottom sheet', (
      tester,
    ) async {
      final msg = _makeMessage(senderId: 'user_1', text: 'my message');
      await tester.pumpWidget(_wrap(messages: [msg]));
      await tester.pump();
      await tester.pump();

      await tester.longPress(find.text('my message'));
      // Use pump(duration) instead of pumpAndSettle: the TypingIndicatorBar
      // has an infinite AnimationController that prevents pumpAndSettle from
      // ever resolving. 500ms is enough for the bottom sheet slide-in.
      await tester.pump(const Duration(milliseconds: 500));

      // Delete option must be visible (isMe = true).
      expect(find.text('Delete'), findsOneWidget);
      // Report option must NOT be visible for own messages.
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('long press other user message shows Report but not Delete', (
      tester,
    ) async {
      final msg = _makeMessage(senderId: 'other_user', text: 'their message');
      await tester.pumpWidget(_wrap(messages: [msg]));
      await tester.pump();
      await tester.pump();

      await tester.longPress(find.text('their message'));
      await tester.pump(const Duration(milliseconds: 500));

      // Report option must be visible for other user's messages.
      expect(find.text('Report this message'), findsOneWidget);
      // Delete option must NOT be visible.
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('tapping Delete calls softDeleteMessage on the repository', (
      tester,
    ) async {
      final repo = _FakeChatRepository();
      final msg = _makeMessage(
        id: 'msg_42',
        senderId: 'user_1',
        text: 'delete me',
      );
      await tester.pumpWidget(_wrap(messages: [msg], repo: repo));
      await tester.pump();
      await tester.pump();

      await tester.longPress(find.text('delete me'));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump();

      expect(repo.deletedMessageIds, contains('msg_42'));
    });
  });
}
