// Widget + golden coverage for the provider hub card ("Mon activite").
//
// Two things are pinned here, both from Amath's 02/09 review of the card:
//
//  1. The availability accent rings the WHOLE card (a light Border.all), it is
//     no longer a 3px strip on the top edge only. A uniform border IS legal
//     with a borderRadius, so the strip was an unnecessary workaround and it
//     read as a decorative tab instead of a state. When no listing is
//     published the accent disappears entirely and the card falls back to the
//     neutral oc.border, exactly as the transparent strip used to.
//  2. The "not verified yet" identity row is an invitation, not a verdict: no
//     greyed shield (the shield is the reward of the flow), an ID-card glyph
//     in the action colour instead, and the icon slot is kept so the row stays
//     aligned with the storefront row above it.
//
// The goldens let a human SEE the ring in both themes and in the three states.
// Regenerate with: flutter test --update-goldens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/identity/identity_trust_providers.dart';
import 'package:outalma_app/src/application/identity/identity_verification_providers.dart';
import 'package:outalma_app/src/application/notification/notification_providers.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/identity_status.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/identity_verification_record.dart';
import 'package:outalma_app/src/domain/models/provider_profile.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';
import 'package:outalma_app/src/features/provider/provider_dashboard_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'prov_1',
      displayName: 'Awa Diop',
      email: 'prov@test.com',
      country: 'SN',
      activeMode: ActiveMode.provider,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

Service _service() => Service(
  id: 's1',
  providerId: 'prov_1',
  categoryId: CategoryId.menage,
  title: 'Menage complet',
  photos: const [],
  priceType: PriceType.hourly,
  price: 2000,
  published: true,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Widget _wrap({
  required bool active,
  required bool hasPublishedService,
  required ThemeData theme,
  IdentityStatus? identity,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.provider),
    currentProviderProfileProvider.overrideWith(
      (_) => Stream.value(
        ProviderProfile(
          uid: 'prov_1',
          active: active,
          suspended: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      ),
    ),
    providerServicesProvider.overrideWith(
      (_) =>
          Stream.value(hasPublishedService ? [_service()] : const <Service>[]),
    ),
    providerStatsProvider.overrideWithValue(
      const ProviderStats(
        bookingsThisMonth: 0,
        acceptanceRate: null,
        upcomingThisWeek: 0,
      ),
    ),
    providerRatingProvider(
      'prov_1',
    ).overrideWith((_) => Stream.value(const RatingDisplay.fresh())),
    identityTrustProvider('prov_1').overrideWith((_) => Stream.value(null)),
    myIdentityVerificationProvider.overrideWith(
      (_) => Stream.value(
        identity == null
            ? null
            : IdentityVerificationRecord(
                status: identity,
                attempt: 1,
                priority: false,
              ),
      ),
    ),
    unreadNotificationsCountProvider.overrideWithValue(0),
  ],
  child: MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fr'),
    home: const ProviderDashboardPage(),
  ),
);

/// The hub card is the nearest bordered Container above the availability row.
BoxDecoration _hubDecoration(WidgetTester tester) {
  final containers = tester.widgetList<Container>(
    find.ancestor(
      of: find.byIcon(Icons.storefront_rounded),
      matching: find.byType(Container),
    ),
  );
  final card = containers.firstWhere(
    (c) =>
        c.decoration is BoxDecoration &&
        (c.decoration! as BoxDecoration).border != null,
  );
  return card.decoration! as BoxDecoration;
}

void main() {
  group('Provider hub card, availability accent', () {
    testWidgets('available: the accent rings the whole card, not one edge', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(active: true, hasPublishedService: true, theme: AppTheme.light()),
      );
      await tester.pump();
      await tester.pump();

      final decoration = _hubDecoration(tester);
      final border = decoration.border! as Border;
      // Uniform: every side carries the accent, which is the whole point.
      expect(border.isUniform, isTrue);
      expect(
        border.top.color,
        OutalmaColors.light.success.withValues(alpha: 0.55),
      );
      expect(border.top.width, 1.5);

      // The old 3px top strip is gone.
      expect(
        tester.widgetList<Container>(find.byType(Container)).any((c) {
          final constraints = c.constraints;
          return constraints != null && constraints.maxHeight == 3;
        }),
        isFalse,
      );

      // A border insets its child, so the clip has to shrink by the same
      // amount or the rows fray the ring at the corners.
      final clip = tester.widget<ClipRRect>(
        find
            .descendant(
              of: find.byWidget(
                tester
                    .widgetList<Container>(
                      find.ancestor(
                        of: find.byIcon(Icons.storefront_rounded),
                        matching: find.byType(Container),
                      ),
                    )
                    .firstWhere(
                      (c) =>
                          c.decoration is BoxDecoration &&
                          (c.decoration! as BoxDecoration).border != null,
                    ),
              ),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(16 - 1.5));
    });

    testWidgets('paused: the ring turns to the warning accent', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          active: false,
          hasPublishedService: true,
          theme: AppTheme.light(),
        ),
      );
      await tester.pump();
      await tester.pump();

      final border = _hubDecoration(tester).border! as Border;
      expect(border.isUniform, isTrue);
      expect(
        border.top.color,
        OutalmaColors.light.warning.withValues(alpha: 0.55),
      );
      expect(border.top.width, 1.5);
    });

    testWidgets('no published listing: no accent at all, neutral border', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          active: true,
          hasPublishedService: false,
          theme: AppTheme.light(),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Same behaviour the transparent strip used to have: nothing to toggle,
      // nothing to encode.
      final border = _hubDecoration(tester).border! as Border;
      expect(border.top.color, OutalmaColors.light.border);
      expect(border.top.width, 1.0);
    });

    testWidgets('dark theme: the ring uses the dark accents', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(active: true, hasPublishedService: true, theme: AppTheme.dark()),
      );
      await tester.pump();
      await tester.pump();

      final border = _hubDecoration(tester).border! as Border;
      expect(
        border.top.color,
        OutalmaColors.dark.success.withValues(alpha: 0.55),
      );
    });
  });

  group('Provider hub card, identity row', () {
    testWidgets('not verified yet reads as an action, not a dead badge', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          active: true,
          hasPublishedService: true,
          theme: AppTheme.light(),
          identity: null,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Vérifier mon identité'), findsOneWidget);
      // The shield is the reward of the flow; greyed out it announced a
      // verdict. It must not appear on the provider's own hub.
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Icons.badge_outlined));
      expect(icon.color, OutalmaColors.light.primary);
      expect(icon.color, isNot(OutalmaColors.light.secondaryText));

      // The icon slot is kept so this row stays aligned with the storefront
      // row above (48px = 16 padding + 22 icon + 10 gap).
      final identityText = tester.getTopLeft(
        find.text('Vérifier mon identité'),
      );
      final availabilityText = tester.getTopLeft(find.text('Disponible'));
      expect(identityText.dx, availabilityText.dx);
    });

    testWidgets('real states keep their own icon and colour', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          active: true,
          hasPublishedService: true,
          theme: AppTheme.light(),
          identity: IdentityStatus.pending,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.badge_outlined), findsNothing);
    });
  });

  group('Provider hub card goldens', () {
    Future<void> golden(
      WidgetTester tester, {
      required bool active,
      required bool hasPublishedService,
      required ThemeData theme,
      required String name,
    }) async {
      // Tall enough to lay the card out, then cropped to the card itself by
      // the finder below.
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          active: active,
          hasPublishedService: hasPublishedService,
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ProviderDashboardPage),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('light, available', (tester) async {
      await golden(
        tester,
        active: true,
        hasPublishedService: true,
        theme: AppTheme.light(),
        name: 'hub_card_light_available',
      );
    });

    testWidgets('light, paused', (tester) async {
      await golden(
        tester,
        active: false,
        hasPublishedService: true,
        theme: AppTheme.light(),
        name: 'hub_card_light_paused',
      );
    });

    testWidgets('light, nothing published', (tester) async {
      await golden(
        tester,
        active: true,
        hasPublishedService: false,
        theme: AppTheme.light(),
        name: 'hub_card_light_no_listing',
      );
    });

    testWidgets('dark, available', (tester) async {
      await golden(
        tester,
        active: true,
        hasPublishedService: true,
        theme: AppTheme.dark(),
        name: 'hub_card_dark_available',
      );
    });

    testWidgets('dark, paused', (tester) async {
      await golden(
        tester,
        active: false,
        hasPublishedService: true,
        theme: AppTheme.dark(),
        name: 'hub_card_dark_paused',
      );
    });

    testWidgets('dark, nothing published', (tester) async {
      await golden(
        tester,
        active: true,
        hasPublishedService: false,
        theme: AppTheme.dark(),
        name: 'hub_card_dark_no_listing',
      );
    });
  });
}
