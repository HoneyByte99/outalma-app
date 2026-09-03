// Chantier 2 (wave-ui-093814): the gender pictogram already shown on the
// catalogue card, the service detail, the provider profile, the booking
// detail and the chat page was missing from this list. Only when the other
// participant IS the provider (`chat.providerId == otherUid`): a client's own
// gender has no place next to their name here either.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/booking/booking_providers.dart';
import 'package:outalma_app/src/application/chat/chat_providers.dart';
import 'package:outalma_app/src/application/notification/notification_providers.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/chat.dart';
import 'package:outalma_app/src/features/chat/chats_list_page.dart';
import 'package:outalma_app/src/features/shared/gender_icon.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'me',
      displayName: 'Me',
      email: 'me@test.com',
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

Widget _wrap({required Chat chat, required Gender? otherGender}) {
  final otherUid = chat.participantIds.firstWhere((id) => id != 'me');
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
      chatsForModeProvider.overrideWithValue(AsyncValue.data([chat])),
      customerBookingsProvider.overrideWith((_) => Stream.value([])),
      providerBookingHistoryProvider.overrideWith((_) => Stream.value([])),
      unreadNotificationsCountProvider.overrideWithValue(0),
      chatMessagesProvider(chat.id).overrideWith((_) => Stream.value([])),
      userByIdProvider(otherUid).overrideWith(
        (_) => Stream.value(
          AppUser(
            id: otherUid,
            displayName: 'Awa Cissé',
            email: 'awa@test.com',
            country: 'SN',
            activeMode: ActiveMode.provider,
            createdAt: DateTime(2024, 1, 1),
            gender: otherGender,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ChatsListPage(),
    ),
  );
}

void main() {
  final baseChat = Chat(
    id: 'chat_1',
    bookingId: 'booking_1',
    participantIds: const ['me', 'provider_1'],
    createdAt: DateTime(2026, 1, 1),
    customerId: 'me',
    providerId: 'provider_1',
  );

  testWidgets('the other participant is the provider: pictogram shown', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(chat: baseChat, otherGender: Gender.female));
    await tester.pump();
    await tester.pump();

    expect(find.byType(GenderIcon), findsOneWidget);
    expect(
      find.descendant(of: find.byType(GenderIcon), matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets(
    'the other participant is a client, not the provider: no pictogram at all',
    (tester) async {
      // Same two-participant shape, but providerId points at "me": the OTHER
      // party is the client, and a client's gender has no place here.
      final chat = baseChat.copyWith(
        customerId: 'provider_1',
        providerId: 'me',
      );
      await tester.pumpWidget(_wrap(chat: chat, otherGender: Gender.male));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GenderIcon), findsNothing);
    },
  );

  testWidgets(
    'the provider has no declared gender: icon mounted, nothing drawn',
    (tester) async {
      await tester.pumpWidget(_wrap(chat: baseChat, otherGender: null));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GenderIcon), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GenderIcon),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    },
  );
}
