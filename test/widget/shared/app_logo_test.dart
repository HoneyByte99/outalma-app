// Widget tests for AppLogo.
//
// Verifies the dark-mode fix: the brand mark is dark navy ink and vanishes on
// a dark background, so AppLogo must swap to the recoloured light-ink asset
// when the ambient theme is dark, and keep the original asset in light mode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/shared/app_logo.dart';

String _assetOf(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as AssetImage).assetName;
}

Widget _wrap({required Brightness brightness}) => MaterialApp(
  theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
  home: const Scaffold(body: Center(child: AppLogo(height: 100))),
);

void main() {
  group('AppLogo', () {
    testWidgets('uses the standard asset in light mode', (tester) async {
      await tester.pumpWidget(_wrap(brightness: Brightness.light));
      expect(_assetOf(tester), 'assets/images/logo_icon_cropped.png');
    });

    testWidgets('swaps to the light-ink asset in dark mode', (tester) async {
      await tester.pumpWidget(_wrap(brightness: Brightness.dark));
      expect(_assetOf(tester), 'assets/images/logo_icon_cropped_dark.png');
    });

    testWidgets('honours the requested height', (tester) async {
      await tester.pumpWidget(_wrap(brightness: Brightness.light));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.height, 100);
    });
  });
}
