// Regression, recovered from feature/simplicity-guest-mode (bbdfe7c), which
// never merged (140 commits behind, 159 files conflicting) but this fix is
// real and applies cleanly today: the final onboarding slide also renders the
// consent block below the PageView, which shrinks the slide viewport. On a
// short screen the slide's fixed-height content used to overflow ("BOTTOM
// OVERFLOWED BY 50 PIXELS"). The slide is now scroll-safe, so no vertical
// RenderFlex overflow should occur.
//
// Viewport is the real iPhone 15 Pro size (393x852 logical px), not a wider
// stand-in: at this exact width the same last slide ALSO used to overflow
// horizontally, in `_LegalLink`'s Row inside the `Wrap` a few lines below the
// slide (independent of the vertical fix above: it fired regardless of
// height). Both defects are exercised, and both must stay fixed, on this one
// viewport.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/onboarding/onboarding_page.dart';

Widget _wrap(ThemeData theme) => ProviderScope(
  child: MaterialApp(
    theme: theme,
    home: const OnboardingPage(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

void main() {
  testWidgets('last slide does not overflow on a real iPhone 15 Pro viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(AppTheme.light()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));

    // "Skip" jumps straight to the last slide (consent + Get Started), the
    // one that shrinks the PageView viewport and used to overflow.
    await tester.tap(find.text(l10n.introSkip));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in dark theme without overflow', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(AppTheme.dark()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await tester.tap(find.text(l10n.introSkip));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
