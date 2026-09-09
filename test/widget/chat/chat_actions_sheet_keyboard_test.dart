// The long-press action sheet of a chat message, with the keyboard open.
//
// This is the realistic case: `onLongPress` does not unfocus the composer and
// the thread only dismisses the keyboard on a drag, so a user who is writing
// and long-presses a message opens this sheet with the keyboard up. ChatPage
// is a root route (/chat/:chatId, outside the StatefulShellRoute), so the
// sheet reads the real inset.
//
// Geometry on the reference device (375x667, keyboard 291): the SDK caps a
// NON scroll-controlled sheet at 9/16 of the screen (375 px), then
// KeyboardAwareSheet caps it again at 375 - 291 = 84 px. The actions measure
// ~243 px, so a fixed Column overflowed by ~160 px and painted its last rows
// under the keyboard.
//
// The sheet is scroll-controlled now, which drops the 9/16 cap: the usable
// height is 667 - 291 = 376 px and the actions fit, with no gesture needed.
// The SingleChildScrollView stays as the safety net for the cases that still
// do not fit, so both properties are asserted here: portrait, the actions are
// reachable with no gesture at all; landscape (667x375, keyboard ~200), they
// are reachable by a drag.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:outalma_app/src/features/chat/chat_page.dart';

import '../../helpers/keyboard.dart';

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

/// The keyboard inset is injected through `MaterialApp.builder`, i.e. ABOVE
/// the Navigator: the modal sheet route sees it too, which a MediaQuery
/// wrapped around `home:` only would not do.
Widget _app(
  List<ChatMessage> messages,
  ValueNotifier<double> inset,
) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    chatMessagesProvider('chat_1').overrideWith((_) => Stream.value(messages)),
    chatDetailProvider('chat_1').overrideWith((_) => Stream.value(null)),
    otherTypingProvider('chat_1').overrideWith((_) => Stream.value(null)),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    notificationsProvider.overrideWith((_) => Stream.value(const [])),
    blockedUserIdsProvider.overrideWith((_) => Stream.value(const <String>{})),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: keyboardInsetBuilder(inset),
    home: const ChatPage(chatId: 'chat_1'),
  ),
);

/// The page hosts a repeating animation, so no pumpAndSettle anywhere here.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

/// Messages from the other user: long-pressing one offers reply / copy /
/// report, the tallest realistic action list for an incoming message.
List<ChatMessage> _incomingThread() => List.generate(
  20,
  (i) => ChatMessage(
    id: 'msg_$i',
    chatId: 'chat_1',
    senderId: 'user_2',
    type: MessageType.text,
    createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
    text: 'message number $i',
  ),
);

/// The same phone sideways: an iOS landscape keyboard is shorter than the
/// portrait one, and the screen is shorter still.
const double _landscapeKeyboard = 200;

/// The last action of the sheet, the one a fixed Column pushed under the
/// keyboard.
Finder _lastAction() => find.ancestor(
  of: find.byIcon(Icons.flag_outlined),
  matching: find.byType(ListTile),
);

/// The sheet's own scroll view. `.first` on the inner Scrollable is not needed
/// here: an action row holds no editable text.
ScrollPosition _sheetPosition(WidgetTester tester, Finder sheetScroll) => tester
    .state<ScrollableState>(
      find.descendant(of: sheetScroll, matching: find.byType(Scrollable)),
    )
    .position;

void main() {
  testWidgets('the long-press action sheet fits above the keyboard, with no '
      'gesture needed', (tester) async {
    useSurface(tester, kReferenceSurface);
    // The composer was focused, so the keyboard is already up when the user
    // long-presses a message.
    final inset = ValueNotifier<double>(kReferenceKeyboard);
    await tester.pumpWidget(_app(_incomingThread(), inset));
    await _settle(tester);

    await tester.longPress(find.text('message number 19'));
    await _settle(tester);

    // A RenderFlex overflow is reported as a Flutter error: take it here so
    // the failure names this sheet rather than surfacing at teardown.
    expect(
      tester.takeException(),
      isNull,
      reason: 'the action sheet overflows its usable height',
    );

    final lastAction = _lastAction();
    expect(lastAction, findsOneWidget);
    final sheetScroll = find.ancestor(
      of: lastAction,
      matching: find.byType(SingleChildScrollView),
    );
    expect(sheetScroll, findsOneWidget);

    // The geometry this test is about. The old 9/16 cap left 84 px here; a
    // scroll-controlled sheet is bounded by the keyboard alone, so the whole
    // 667 - 291 = 376 px is available and the ~243 px of actions fit in it.
    final height = tester.getRect(sheetScroll).height;
    expect(
      height,
      greaterThan(667 * 9 / 16 - kReferenceKeyboard),
      reason: 'the SDK 9/16 cap is back, isScrollControlled was lost',
    );
    expect(
      height,
      lessThanOrEqualTo(667 - kReferenceKeyboard + 0.5),
      reason: 'the sheet is taller than the space above the keyboard',
    );

    // Everything fits: the user reaches the last action without scrolling at
    // all, which is the point of dropping the cap.
    expect(_sheetPosition(tester, sheetScroll).maxScrollExtent, 0);
    expectInsideBox(tester, lastAction, sheetScroll);
    expectAboveKeyboard(tester, sheetScroll, inset: kReferenceKeyboard);
    expectAboveKeyboard(tester, lastAction, inset: kReferenceKeyboard);
  });

  testWidgets('landscape, where the actions still do not fit: the scroll view '
      'is the safety net', (tester) async {
    // The same phone held sideways: 667x375, and a landscape keyboard is
    // about 200 px. That leaves the sheet 175 px for its ~235 px of actions,
    // so here it is the scrollable, not the height, that makes the last
    // action reachable.
    useSurface(tester, const Size(667, 375));
    // The keyboard is raised AFTER the sheet opens, and that order is a
    // harness constraint rather than a scenario: with 175 px left, the app
    // bar and the composer eat the whole thread and there is no bubble to
    // long-press. What is asserted below is the sheet's geometry under
    // 175 px, which is the same whichever way it got there.
    final inset = ValueNotifier<double>(0);
    await tester.pumpWidget(_app(_incomingThread(), inset));
    await _settle(tester);

    // Sideways the thread shows fewer bubbles: long-press whichever one is on
    // screen, the actions are the same for every incoming message.
    await tester.longPress(
      find.textContaining('message number').hitTestable().last,
    );
    await _settle(tester);

    inset.value = _landscapeKeyboard;
    await _settle(tester);

    final lastAction = _lastAction();
    expect(lastAction, findsOneWidget);
    final sheetScroll = find.ancestor(
      of: lastAction,
      matching: find.byType(SingleChildScrollView),
    );
    expect(sheetScroll, findsOneWidget);

    // Space really is short here, so the drag below is not vacuous.
    final position = _sheetPosition(tester, sheetScroll);
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: 'the actions fit, so this geometry proves nothing',
    );

    // A real gesture brings the last action into the box, above the keyboard.
    // Dragged well past the extent (the scrollable eats kTouchSlop before it
    // moves); the clamping physics stop at the end of the list.
    await tester.drag(sheetScroll, Offset(0, -position.maxScrollExtent - 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));

    expectInsideBox(tester, lastAction, sheetScroll);
    expectAboveKeyboard(tester, sheetScroll, inset: _landscapeKeyboard);
    expectAboveKeyboard(tester, lastAction, inset: _landscapeKeyboard);
  });
}
