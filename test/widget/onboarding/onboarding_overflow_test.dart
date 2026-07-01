// Regression: the final onboarding slide also renders the consent block below
// the PageView, which shrinks the slide viewport. On a short screen the slide's
// fixed-height content used to overflow ("BOTTOM OVERFLOWED BY 50 PIXELS").
// The slide is now scroll-safe, so no RenderFlex overflow should occur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/onboarding/onboarding_page.dart';

void main() {
  testWidgets('last slide does not overflow on a short viewport', (
    tester,
  ) async {
    // iPhone 15 Pro logical size (393x852) - the device where the
    // 50px bottom overflow was reported.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OnboardingPage(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // "Skip" jumps straight to the last slide (consent + Get Started).
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // No layout overflow exception should have been recorded.
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in dark theme without overflow', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const OnboardingPage(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
