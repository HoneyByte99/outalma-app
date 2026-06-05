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
import 'package:outalma_app/src/domain/models/app_user.dart';
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

Widget _wrap() => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    chatMessagesProvider('chat_1').overrideWith((_) => Stream.value([])),
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

void main() {
  group('ChatPage', () {
    testWidgets('smoke — renders without throwing', (tester) async {
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
  });
}
