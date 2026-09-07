// Keyboard simulation for widget tests.
//
// The test binding never opens a real keyboard. What the platform reports to
// the app when one opens is a bottom view inset, so the helpers here inject
// that inset through a MediaQuery placed ABOVE the Navigator (via
// MaterialApp.builder): modal routes, sheets and dialogs see it too, unlike a
// MediaQuery wrapped around `home:` only.
//
// What these tests prove: GEOMETRY (a sheet lifted above the keyboard, a
// footer kept visible, no overflow). They do not prove the caret's
// scroll-into-view, which EditableText drives from the raw view metrics, not
// from MediaQuery. That part is checked on the simulator during the smoke.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference device of the keyboard audit: 375x667 logical, keyboard 291 px.
const Size kReferenceSurface = Size(375, 667);
const double kReferenceKeyboard = 291;

/// Sizes the test surface to [size] at device pixel ratio 1 and restores it
/// after the test.
void useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A [MaterialApp.builder] that reports [inset] as the bottom view inset.
/// Change `inset.value` mid-test to open or close the simulated keyboard
/// without re-pumping the tree.
TransitionBuilder keyboardInsetBuilder(ValueNotifier<double> inset) {
  return (context, child) => ValueListenableBuilder<double>(
    valueListenable: inset,
    builder: (context, value, _) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(viewInsets: EdgeInsets.only(bottom: value)),
      child: child!,
    ),
  );
}

/// Asserts that the single widget matched by [finder] lies entirely on
/// screen and above a keyboard of [inset] pixels.
void expectAboveKeyboard(
  WidgetTester tester,
  Finder finder, {
  required double inset,
}) {
  final surfaceHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final rect = tester.getRect(finder);
  expect(
    rect.bottom,
    lessThanOrEqualTo(surfaceHeight - inset),
    reason: 'widget bottom ${rect.bottom} is under a $inset px keyboard',
  );
  expect(rect.top, greaterThanOrEqualTo(0));
}

/// Reproduces the nesting of `AppShell`'s `StatefulShellRoute` branches: an
/// outer Scaffold with a bottom bar whose body hosts the nearest Navigator.
/// A sheet opened from [page] lands in that inner Navigator, inside a body
/// that has its bottom inset removed and is shrunk by the keyboard. This is
/// the harness for any sheet reachable from a shell branch (home, provider
/// dashboard, profile).
Widget shellLike(Widget page) {
  return Scaffold(
    body: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => page),
    ),
    bottomNavigationBar: const SizedBox(height: 80),
  );
}
