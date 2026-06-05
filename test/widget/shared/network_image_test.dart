// Widget tests for AppNetworkImage.
//
// AppNetworkImage wraps CachedNetworkImage.  In the test environment
// network traffic is unavailable, so the CachedNetworkImage will settle
// in its placeholder state (the loading callback fires immediately).
// We verify:
//   - Widget builds without throwing for a valid URL string.
//   - The default loading placeholder (_DefaultLoadingPlaceholder) is shown
//     before the image resolves (it's a plain colored Container).
//   - Optional borderRadius does not crash the tree.
//
// Note: network_image_mock is not in pubspec.yaml, so we rely on the
// placeholder path that CachedNetworkImage takes when the network is
// absent in the Flutter test environment.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/shared/network_image.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('AppNetworkImage', () {
    testWidgets('renders without throwing given a URL', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppNetworkImage(
            url: 'https://example.com/image.jpg',
            width: 100,
            height: 100,
          ),
        ),
      );
      // First frame: CachedNetworkImage is present in the tree.
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('placeholder Container is visible before image loads', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppNetworkImage(
            url: 'https://example.com/photo.png',
            width: 80,
            height: 80,
          ),
        ),
      );
      // pump() without settling ensures we're in the loading state.
      await tester.pump();
      // The default placeholder is a plain Container — verify at least one
      // Container with a non-null color is present in the sub-tree.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasColoredContainer = containers.any((c) => c.color != null);
      expect(hasColoredContainer, isTrue);
    });

    testWidgets('accepts a custom placeholder widget', (tester) async {
      const customPlaceholder = SizedBox(
        key: ValueKey('placeholder'),
        width: 50,
        height: 50,
      );
      await tester.pumpWidget(
        _wrap(
          const AppNetworkImage(
            url: 'https://example.com/img.jpg',
            width: 50,
            height: 50,
            placeholder: customPlaceholder,
          ),
        ),
      );
      await tester.pump();
      // Custom placeholder is rendered while loading.
      expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
    });

    testWidgets('borderRadius wraps image in ClipRRect', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppNetworkImage(
            url: 'https://example.com/rounded.jpg',
            width: 100,
            height: 100,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('no borderRadius means no ClipRRect in the tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppNetworkImage(
            url: 'https://example.com/flat.jpg',
            width: 100,
            height: 100,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('renders with only required url parameter', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppNetworkImage(url: 'https://example.com/min.jpg')),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
