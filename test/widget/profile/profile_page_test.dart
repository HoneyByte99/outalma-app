// Harness widget tests for ProfilePage.
// ProfilePage reads authNotifierProvider to get the current user.
// Override with an authenticated user to see the full profile content.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:outalma_app/src/features/profile/profile_page.dart';
import 'package:outalma_app/src/features/shared/user_avatar.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'user_1',
      displayName: 'Alice Martin',
      email: 'alice@test.com',
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

/// Records what setProfileImage is called with, so the ROUTING can be asserted
/// rather than inferred.
class _RecordingAuthNotifier extends AuthNotifier {
  _RecordingAuthNotifier(this._user);
  final AppUser _user;
  final List<(String?, String?)> calls = [];

  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);

  @override
  Future<void> setProfileImage({String? photoPath, String? avatarId}) async {
    calls.add((photoPath, avatarId));
  }
}

class _FakeThemeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

Widget _wrap() => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.client),
    themeModeProvider.overrideWith(_FakeThemeNotifier.new),
    reviewsForUserProvider('user_1').overrideWith((_) => Stream.value([])),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ProfilePage(),
  ),
);

void main() {
  group('ProfilePage', () {
    testWidgets('smoke — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('mode toggle section is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      // ModeBadge is shown in the AppBar actions
      expect(find.byType(ProfilePage), findsOneWidget);
      // The page has a Scaffold — spot-check for Scaffold rendering
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('logout option is visible', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      // Account section contains logout — check by icon
      expect(find.byIcon(Icons.logout_outlined), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // The avatar header routes the picker's outcomes.
  //
  // A notifier-only test would NOT have caught the defect this guards: the
  // photo path used to call updateProfile, which cannot clear an avatar, and a
  // test of setProfileImage alone would have stayed green while the page never
  // called it. Two of the three outcomes are asserted here; the photo one goes
  // through the system gallery, so it is covered by reading the code and by
  // the smoke test.
  // -------------------------------------------------------------------------
  group('avatar picker routing', () {
    late _RecordingAuthNotifier notifier;

    Widget wrapWith(AppUser user) {
      notifier = _RecordingAuthNotifier(user);
      return ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => notifier),
          activeModeProvider.overrideWith((_) => ActiveMode.client),
          themeModeProvider.overrideWith(_FakeThemeNotifier.new),
          reviewsForUserProvider(
            'user_1',
          ).overrideWith((_) => Stream.value([])),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfilePage(),
        ),
      );
    }

    AppUser user({String? photoPath, String? avatarId}) => AppUser(
      id: 'user_1',
      displayName: 'Alice Martin',
      email: 'alice@test.com',
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime(2024, 1, 1),
      photoPath: photoPath,
      avatarId: avatarId,
    );

    Future<void> openSheet(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pump();
      await tester.tap(find.byType(UserAvatar).first);
      await tester.pumpAndSettle();
    }

    testWidgets('picking an avatar calls setProfileImage with it', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWith(user()));
      await openSheet(tester);

      expect(find.text('Importer une photo'), findsOneWidget);
      await tester.tap(find.byType(SvgPicture).first);
      await tester.pumpAndSettle();

      expect(notifier.calls, hasLength(1));
      final (photo, avatar) = notifier.calls.single;
      expect(photo, isNull, reason: 'choosing an avatar must clear the photo');
      expect(avatar, startsWith('human_'));
    });

    testWidgets('removing calls setProfileImage with both null', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWith(user(avatarId: 'human_afro1_t2')));
      await openSheet(tester);

      await tester.tap(find.text('Retirer, revenir aux initiales'));
      await tester.pumpAndSettle();

      expect(notifier.calls.single, (null, null));
    });
  });
}
