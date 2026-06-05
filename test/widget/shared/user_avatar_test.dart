// Widget tests for UserAvatar — covers initials logic and radius sizing.
// Only tests the photoPath: null path (no network mocking needed).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/shared/user_avatar.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('UserAvatar', () {
    testWidgets('empty displayName shows Icons.person_rounded', (tester) async {
      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: '', photoPath: null)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('single-word displayName shows first letter initial', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'Alice', photoPath: null)),
      );
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('two-word displayName shows first + last initials', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'Alice Dupont', photoPath: null)),
      );
      await tester.pump();
      expect(find.text('AD'), findsOneWidget);
    });

    testWidgets('photoPath null shows initials widget, no CachedNetworkImage', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'Bob Martin', photoPath: null)),
      );
      await tester.pump();
      // Initials should be present
      expect(find.text('BM'), findsOneWidget);
      // No network image should be in the tree
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('radius parameter changes container size', (tester) async {
      const radius = 30.0;
      await tester.pumpWidget(
        _wrap(
          const UserAvatar(
            displayName: 'Test User',
            photoPath: null,
            radius: radius,
          ),
        ),
      );
      await tester.pump();

      // Find the Container with the expected size (radius * 2 = 60)
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (c) =>
                c.constraints?.maxWidth == radius * 2 ||
                (c.decoration is BoxDecoration &&
                    (c.decoration as BoxDecoration).shape == BoxShape.circle),
          )
          .toList();

      // At least one container matches the circle avatar
      expect(containers.isNotEmpty, isTrue);

      // Verify the size via RenderBox
      final avatarFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(avatarFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(avatarFinder.first);
      expect(renderBox.size.width, equals(radius * 2));
      expect(renderBox.size.height, equals(radius * 2));
    });

    testWidgets('whitespace-only displayName shows person icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: '   ', photoPath: null)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });
  });
}
