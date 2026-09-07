// Harness widget tests for ChatPage.
// Overrides chatMessagesProvider (empty list → empty state), chatDetailProvider,
// authNotifierProvider, and chatRepositoryProvider-dependent providers.

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
import 'package:outalma_app/src/domain/models/chat_message.dart';
import 'package:outalma_app/src/features/chat/chat_page.dart';

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

/// [keyboardInset] simulates the on-screen keyboard: the test binding never
/// opens a real one, so the bottom view inset is injected right above the
/// page, the same way the platform reports it to the app.
Widget _wrap({
  List<ChatMessage> messages = const [],
  double keyboardInset = 0,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    chatMessagesProvider('chat_1').overrideWith((_) => Stream.value(messages)),
    chatDetailProvider('chat_1').overrideWith((_) => Stream.value(null)),
    otherTypingProvider('chat_1').overrideWith((_) => Stream.value(null)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardInset)),
        child: const ChatPage(chatId: 'chat_1'),
      ),
    ),
  ),
);

List<ChatMessage> _someMessages() => List.generate(
  20,
  (i) => ChatMessage(
    id: 'msg_$i',
    chatId: 'chat_1',
    senderId: i.isEven ? 'user_1' : 'user_2',
    type: MessageType.text,
    createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
    text: 'message number $i',
  ),
);

void main() {
  group('keyboardCompensatedScrollOffset', () {
    test('a list scrolled to its end stays at the new end when the keyboard '
        'opens', () {
      // Viewport lost 300 px, so maxScrollExtent grew from 1000 to 1300.
      expect(
        keyboardCompensatedScrollOffset(
          pixels: 1000,
          insetDelta: 300,
          maxScrollExtent: 1300,
        ),
        1300,
      );
    });

    test('closing the keyboard shifts the list back by the same amount', () {
      expect(
        keyboardCompensatedScrollOffset(
          pixels: 1300,
          insetDelta: -300,
          maxScrollExtent: 1000,
        ),
        1000,
      );
    });

    test('a mid-thread position moves by the delta, not to the end', () {
      expect(
        keyboardCompensatedScrollOffset(
          pixels: 400,
          insetDelta: 300,
          maxScrollExtent: 1300,
        ),
        700,
      );
    });

    test('never overshoots the top or the end of the list', () {
      expect(
        keyboardCompensatedScrollOffset(
          pixels: 100,
          insetDelta: -300,
          maxScrollExtent: 1000,
        ),
        0,
      );
      expect(
        keyboardCompensatedScrollOffset(
          pixels: 1200,
          insetDelta: 300,
          maxScrollExtent: 1300,
        ),
        1300,
      );
    });

    test('a thread that fits without scrolling stays at 0', () {
      expect(
        keyboardCompensatedScrollOffset(
          pixels: 0,
          insetDelta: 300,
          maxScrollExtent: 0,
        ),
        0,
      );
    });
  });

  group('ChatPage', () {
    testWidgets(
      'opening the keyboard keeps the newest message visible above the composer',
      (tester) async {
        final messages = _someMessages();
        await tester.pumpWidget(_wrap(messages: messages));
        // No pumpAndSettle: the page hosts a repeating animation. The stream
        // delivers on one frame, the post-frame auto-scroll starts on the
        // next, so pump a few frames then run past the 250 ms animation.
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 400));

        // The thread auto-scrolls to its end on first load: the newest
        // message sits just above the composer.
        final newest = find.text('message number 19');
        expect(newest, findsOneWidget);
        final composerTopBefore = tester.getTopLeft(find.byType(TextField)).dy;
        expect(tester.getBottomLeft(newest).dy, lessThan(composerTopBefore));

        // The keyboard opens: the platform reports a 300 px bottom inset and
        // the Scaffold shrinks its body by that much. Same tree shape, so the
        // page keeps its state and its scroll position.
        await tester.pumpWidget(_wrap(messages: messages, keyboardInset: 300));
        await tester.pump();
        await tester.pump();

        // Build 36 regression: the list kept its top-anchored offset, the
        // newest messages slid under the keyboard. They must stay visible,
        // above the composer, which itself sits above the keyboard.
        final composerTop = tester.getTopLeft(find.byType(TextField)).dy;
        expect(composerTop, lessThan(composerTopBefore));
        expect(newest, findsOneWidget);
        expect(tester.getBottomLeft(newest).dy, lessThan(composerTop));
      },
    );

    testWidgets('smoke: renders without throwing', (tester) async {
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
      // When input is empty the mic button shows; when text is typed the send
      // button appears. Either way, at least one of the two icons is present.
      final hasMic = tester.any(find.byIcon(Icons.mic_rounded));
      final hasSend = tester.any(find.byIcon(Icons.send_rounded));
      expect(hasMic || hasSend, isTrue);
    });

    testWidgets(
      'dragging the message list closes the keyboard, like WhatsApp',
      (tester) async {
        await tester.pumpWidget(_wrap(messages: _someMessages()));
        await tester.pump();
        await tester.pump();

        // Focus the composer: the keyboard is now "open" from the test
        // harness' point of view (a text input connection is attached).
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // Drag the messages ListView itself, not the composer: this is the
        // sibling scrollable WhatsApp closes the keyboard from.
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pump();

        expect(tester.testTextInput.hasAnyClients, isFalse);
      },
    );
  });
}
