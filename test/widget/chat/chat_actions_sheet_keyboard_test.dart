// The long-press action sheet of a chat message, with the keyboard open.
//
// This is the realistic case: `onLongPress` does not unfocus the composer and
// the thread only dismisses the keyboard on a drag, so a user who is writing
// and long-presses a message opens this sheet with the keyboard up. ChatPage
// is a root route (/chat/:chatId, outside the StatefulShellRoute), so the
// sheet reads the real inset.
//
// Geometry on the reference device (375x667, keyboard 291): the SDK caps a
// non scroll-controlled sheet at 9/16 of the screen (375 px), then
// KeyboardAwareSheet caps it again at 375 - 291 = 84 px. The actions measure
// ~233 px, so a fixed Column overflowed by ~150 px and painted its last rows
// under the keyboard. They must scroll instead.

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

void main() {
  testWidgets('the long-press action sheet scrolls instead of overflowing '
      'when the keyboard is open', (tester) async {
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
      reason: 'the action sheet overflows its 84 px of usable height',
    );

    // The last action of the sheet, the one a fixed Column pushed under the
    // keyboard.
    final lastAction = find.ancestor(
      of: find.byIcon(Icons.flag_outlined),
      matching: find.byType(ListTile),
    );
    expect(lastAction, findsOneWidget);
    final sheetScroll = find.ancestor(
      of: lastAction,
      matching: find.byType(SingleChildScrollView),
    );
    expect(sheetScroll, findsOneWidget);

    // The geometry this test is about: 375 px (SDK cap, 9/16 of 667) minus
    // the 291 px keyboard.
    expect(
      tester.getRect(sheetScroll).height,
      closeTo(667 * 9 / 16 - kReferenceKeyboard, 1),
    );
    // Space really is short here: without a scrollable there would be nothing
    // to reach the last rows with.
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: sheetScroll, matching: find.byType(Scrollable)),
        )
        .position;
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
    expectAboveKeyboard(tester, sheetScroll, inset: kReferenceKeyboard);
    expectAboveKeyboard(tester, lastAction, inset: kReferenceKeyboard);
  });
}
