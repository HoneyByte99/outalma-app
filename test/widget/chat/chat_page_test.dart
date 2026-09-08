import 'dart:async';

// Overrides chatMessagesProvider (empty list → empty state), chatDetailProvider,
// authNotifierProvider, and chatRepositoryProvider-dependent providers.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/chat/chat_providers.dart';
import 'package:outalma_app/src/application/notification/notification_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/message_type.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/chat_message.dart';
import 'package:outalma_app/src/domain/repositories/chat_repository.dart';
import 'package:outalma_app/src/features/chat/chat_page.dart';

import '../../helpers/keyboard.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

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

/// Same page, driven by streams the test controls, plus a repository mock
/// for the paths that write (send, typing, read receipts).
Widget _wrapStreams({
  required Stream<List<ChatMessage>> messages,
  required Stream<DateTime?> typing,
  required ChatRepository repo,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    chatMessagesProvider('chat_1').overrideWith((_) => messages),
    chatDetailProvider('chat_1').overrideWith((_) => Stream.value(null)),
    otherTypingProvider('chat_1').overrideWith((_) => typing),
    chatRepositoryProvider.overrideWithValue(repo),
    // _markRead and the header reach Firestore after the repository call
    // (notifications, other user's profile): give them an in-memory one.
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    notificationsProvider.overrideWith((_) => Stream.value(const [])),
    blockedUserIdsProvider.overrideWith((_) => Stream.value(const <String>{})),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ChatPage(chatId: 'chat_1'),
  ),
);

/// The page hosts a repeating animation, so no pumpAndSettle: pump the stream
/// delivery, the post-frame auto-scroll, then run past its 250 ms.
Future<void> _settleThread(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

/// The thread's scroll position (the ListView's own Scrollable, not the
/// composer's).
ScrollPosition _threadPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

double _listBottom(WidgetTester tester) =>
    tester.getRect(find.byType(ListView)).bottom;

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
  group('viewportCompensatedScrollOffset', () {
    test('a list scrolled to its end stays at the new end when the viewport '
        'shrinks', () {
      // Viewport lost 300 px, so maxScrollExtent grew from 1000 to 1300.
      expect(
        viewportCompensatedScrollOffset(
          pixels: 1000,
          viewportDelta: 300,
          maxScrollExtent: 1300,
          atBottom: true,
        ),
        1300,
      );
    });

    test('a reader at the end is pinned to the NEW end even when a message '
        'was appended in the same frame', () {
      // Banner closed (viewport grew by 60) AND a 120 px message arrived:
      // pixels + delta would land 120 px short of the new end.
      expect(
        viewportCompensatedScrollOffset(
          pixels: 1300,
          viewportDelta: -60,
          maxScrollExtent: 1360,
          atBottom: true,
        ),
        1360,
      );
    });

    test('growing the viewport shifts the list back by the same amount', () {
      expect(
        viewportCompensatedScrollOffset(
          pixels: 1300,
          viewportDelta: -300,
          maxScrollExtent: 1000,
          atBottom: true,
        ),
        1000,
      );
    });

    test('a mid-thread position moves by the delta, not to the end', () {
      expect(
        viewportCompensatedScrollOffset(
          pixels: 400,
          viewportDelta: 300,
          maxScrollExtent: 1300,
          atBottom: false,
        ),
        700,
      );
    });

    test('never overshoots the top or the end of the list', () {
      expect(
        viewportCompensatedScrollOffset(
          pixels: 100,
          viewportDelta: -300,
          maxScrollExtent: 1000,
          atBottom: false,
        ),
        0,
      );
      expect(
        viewportCompensatedScrollOffset(
          pixels: 1200,
          viewportDelta: 300,
          maxScrollExtent: 1300,
          atBottom: false,
        ),
        1300,
      );
    });

    test('a thread that fits without scrolling stays at 0', () {
      expect(
        viewportCompensatedScrollOffset(
          pixels: 0,
          viewportDelta: 300,
          maxScrollExtent: 0,
          atBottom: true,
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

  // Every change of the list's viewport, not only the keyboard, must keep the
  // newest message visible: the typing indicator and the reply banner both
  // take height from the list.
  group('ChatPage viewport changes', () {
    late _MockChatRepository repo;

    setUp(() {
      repo = _MockChatRepository();
      registerFallbackValue(
        ChatMessage(
          id: 'fallback',
          chatId: 'chat_1',
          senderId: 'user_1',
          type: MessageType.text,
          createdAt: DateTime(2024, 1, 1),
        ),
      );
      when(
        () => repo.markMessagesRead(
          chatId: any(named: 'chatId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repo.setTyping(
          chatId: any(named: 'chatId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async {});
    });

    testWidgets('the typing indicator appearing leaves the thread at its end, '
        'newest message just above the list bottom', (tester) async {
      useSurface(tester, kReferenceSurface);
      final typing = StreamController<DateTime?>();
      addTearDown(typing.close);
      await tester.pumpWidget(
        _wrapStreams(
          messages: Stream.value(_someMessages()),
          typing: typing.stream,
          repo: repo,
        ),
      );
      await _settleThread(tester);
      final position = _threadPosition(tester);
      final newest = find.text('message number 19');
      expect(tester.getBottomLeft(newest).dy, lessThan(_listBottom(tester)));
      // Note: after the initial auto-scroll the offset can sit BEYOND
      // maxScrollExtent (lazy list, over-estimated extent at animateTo time:
      // measured 65 px on this surface), pre-existing and not asserted here.

      // The other user starts typing: a bar appears above the composer and
      // the list loses that height. Without compensation the offset stays
      // put while the extent shrinks: the thread is no longer at its end and
      // the newest message slides towards the bar.
      typing.add(DateTime.now().toUtc());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(newest, findsOneWidget);
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
      final gap = _listBottom(tester) - tester.getBottomLeft(newest).dy;
      expect(gap, greaterThanOrEqualTo(0));
      expect(gap, lessThan(60), reason: 'newest message is not at the end');
    });

    testWidgets(
      'a viewport change during the user\'s own drag does not jump the thread',
      (tester) async {
        useSurface(tester, kReferenceSurface);
        final messages = _someMessages();
        await tester.pumpWidget(_wrap(messages: messages, keyboardInset: 300));
        await _settleThread(tester);
        final position = _threadPosition(tester);
        final pixelsAtRest = position.pixels;

        // Finger down on the thread, dragged a little towards older messages.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        final pixelsMidDrag = position.pixels;
        expect(pixelsMidDrag, isNot(pixelsAtRest));

        // Dismiss-on-drag: the keyboard slides away under the finger and the
        // list grows by 300 px. The compensation must not fire mid-gesture:
        // a jumpTo would end the drag activity, and the finger would go on
        // moving over a thread that no longer follows it. (The physics may
        // still adjust an out-of-range offset here, so the offset itself is
        // not what is asserted: the drag being alive is.)
        await tester.pumpWidget(_wrap(messages: messages, keyboardInset: 0));
        await tester.pump();
        await tester.pump();
        final pixelsAfterChange = position.pixels;
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        expect(
          position.pixels,
          closeTo(pixelsAfterChange - 40, 1),
          reason: 'the drag no longer moves the thread',
        );

        await gesture.up();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    testWidgets('sending a reply while the banner closes leaves the sent '
        'message fully visible', (tester) async {
      useSurface(tester, kReferenceSurface);
      final messages = StreamController<List<ChatMessage>>();
      addTearDown(messages.close);
      final thread = _someMessages();
      when(() => repo.sendMessage(any())).thenAnswer((invocation) async {
        final sent = invocation.positionalArguments.single as ChatMessage;
        final stored = ChatMessage(
          id: 'msg_sent',
          chatId: sent.chatId,
          senderId: sent.senderId,
          type: sent.type,
          createdAt: sent.createdAt,
          text: sent.text,
          replyToId: sent.replyToId,
          replyToText: sent.replyToText,
          replyToSenderId: sent.replyToSenderId,
        );
        messages.add([...thread, stored]);
        return stored;
      });
      await tester.pumpWidget(
        _wrapStreams(
          messages: messages.stream,
          typing: Stream.value(null),
          repo: repo,
        ),
      );
      messages.add(thread);
      await _settleThread(tester);

      // Long-press the newest message, choose "Répondre": the banner opens
      // above the composer and the list shrinks.
      await tester.longPress(find.text('message number 19'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Répondre'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('message number 19'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'ma reponse');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      // Same frame: the banner closes (list grows) and the sent message is
      // appended (auto-scroll to the end).
      await _settleThread(tester);

      final sent = find.text('ma reponse');
      expect(sent, findsOneWidget);
      // The auto-scroll to the new message won: the sent bubble is inside
      // the list box, not under the composer. (A naive compensation, pixels
      // plus delta, would jump the thread short of the end and cancel that
      // animation.)
      expect(
        tester.getBottomLeft(sent).dy,
        lessThanOrEqualTo(_listBottom(tester)),
      );
    });
  });
}
