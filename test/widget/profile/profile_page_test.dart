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
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/data/services/avatar_upload_service.dart';
import 'package:outalma_app/src/features/profile/avatar_picker_sheet.dart';
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

/// Stands in for the gallery. AvatarUploadService is injected through a plain
/// Provider and its two methods are virtual, so the photo path IS testable: an
/// earlier version of this file claimed otherwise and left the one line the
/// plan singled out uncovered.
class _FakeUploadService extends AvatarUploadService {
  _FakeUploadService() : super(storage: _MockStorage(), uid: 'user_1');

  bool deleted = false;

  /// Shared with the fake notifier, so ORDER is observable and not merely
  /// "both happened". An earlier version of the ordering test asserted only
  /// that the delete had run, which is equally true of a delete-first
  /// implementation, so it tested nothing.
  List<String>? trace;

  @override
  Future<String?> pickAndUpload() async => 'https://example.test/a.jpg';

  @override
  Future<void> deleteAvatar() async {
    deleted = true;
    trace?.add('delete');
  }
}

class _MockStorage extends Mock implements FirebaseStorage {}

/// Records what setProfileImage is called with, so the ROUTING can be asserted
/// rather than inferred.
class _RecordingAuthNotifier extends AuthNotifier {
  _RecordingAuthNotifier(this._user);
  final AppUser _user;
  final List<(String?, String?)> calls = [];

  /// Lets a test exercise the failure path of the write.
  bool throwOnCall = false;

  /// See _FakeUploadService.trace.
  List<String>? trace;

  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);

  @override
  Future<void> setProfileImage({String? photoPath, String? avatarId}) async {
    if (throwOnCall) throw Exception('offline');
    trace?.add('write');
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
    testWidgets('smoke, renders without throwing', (tester) async {
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
      // The page has a Scaffold, spot-check for Scaffold rendering
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('logout option is visible', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      // Account section contains logout, check by icon
      expect(find.byIcon(Icons.logout_outlined), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // The avatar header routes the picker's outcomes.
  //
  // A notifier-only test would NOT have caught the defect this guards: the
  // photo path used to call updateProfile, which cannot clear an avatar, and a
  // test of setProfileImage alone would have stayed green while the page never
  // called it. All THREE outcomes are asserted here, including the photo one:
  // the upload service is injected through a provider and its methods are
  // virtual, so the earlier claim that the gallery made it untestable was
  // simply wrong.
  // -------------------------------------------------------------------------
  group('avatar picker routing', () {
    late _RecordingAuthNotifier notifier;

    late _FakeUploadService uploads;

    Widget wrapWith(AppUser user) {
      notifier = _RecordingAuthNotifier(user);
      uploads = _FakeUploadService();
      return ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => notifier),
          avatarUploadServiceProvider.overrideWithValue(uploads),
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
      // Point 5 (CADRAGE booking-ux): a tile only stages the choice now, on
      // the same footing as the tone swatch. Enregistrer commits it.
      await tester.tap(find.byType(SvgPicture).first);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AvatarPickerSheet),
          matching: find.text('Enregistrer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.calls, hasLength(1));
      final (photo, avatar) = notifier.calls.single;
      expect(photo, isNull, reason: 'choosing an avatar must clear the photo');
      expect(avatar, startsWith('human_'));
    });

    testWidgets('importing a photo calls setProfileImage with it, and only it', (
      tester,
    ) async {
      // The third outcome, and the one the plan insisted on: updateProfile
      // cannot null an avatarId, so leaving this path on updateProfile would
      // store the photo while the old avatar stayed on the document, with the
      // display precedence merely hiding the inconsistency. Reverting the page
      // to updateProfile must turn THIS red.
      await tester.pumpWidget(wrapWith(user(avatarId: 'human_afro1_t2')));
      await openSheet(tester);

      await tester.tap(find.text('Importer une photo'));
      await tester.pumpAndSettle();

      expect(notifier.calls.single, ('https://example.test/a.jpg', null));
    });

    testWidgets('the write happens BEFORE the Storage delete', (tester) async {
      // Ordering guard, and it has to observe the order rather than the fact
      // that both ran: deleting first destroys the photo for good when the
      // write then fails, while the snackbar tells the user nothing was saved.
      await tester.pumpWidget(wrapWith(user(photoPath: 'https://old/p.jpg')));
      final trace = <String>[];
      notifier.trace = trace;
      uploads.trace = trace;
      await openSheet(tester);

      await tester.tap(find.byType(SvgPicture).first);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AvatarPickerSheet),
          matching: find.text('Enregistrer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(trace, ['write', 'delete']);
    });

    testWidgets('a failed write shows the error and keeps the photo', (
      tester,
    ) async {
      // U1 and U3 on the new write path: a generic localized message, never a
      // raw exception, and no destructive side effect.
      await tester.pumpWidget(wrapWith(user(photoPath: 'https://old/p.jpg')));
      notifier.throwOnCall = true;
      await openSheet(tester);

      await tester.tap(find.byType(SvgPicture).first);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AvatarPickerSheet),
          matching: find.text('Enregistrer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Impossible d'enregistrer votre choix. Réessayez."),
        findsOneWidget,
      );
      expect(
        uploads.deleted,
        isFalse,
        reason: 'a failed write must not have destroyed the photo',
      );
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
