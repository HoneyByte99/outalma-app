// Widget tests for UserAvatar: initials, radius sizing, and the illustrated
// avatar cascade.
//
// The photoPath branch is still not exercised against a real network (no
// mocking needed for what is asserted here); what IS asserted is the
// PRECEDENCE, which needs no network: a photo present means no SVG is built.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/avatars/avatar_catalog.dart';
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

  // -------------------------------------------------------------------------
  // The illustrated avatar. The six tests above stay green untouched, which is
  // itself the proof that avatarId is genuinely optional.
  // -------------------------------------------------------------------------
  group('illustrated avatar', () {
    testWidgets('renders the SVG when there is no photo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UserAvatar(displayName: 'Awa Diop', avatarId: 'human_afro1_t2'),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('AD'), findsNothing);
    });

    testWidgets('the PHOTO wins over the avatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UserAvatar(
            displayName: 'Awa Diop',
            photoPath: 'https://example.test/a.jpg',
            avatarId: 'human_afro1_t2',
          ),
        ),
      );

      // The cascade is photo, then avatar, then initials.
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('an UNKNOWN id falls back to initials', (tester) async {
      // The whole compatibility story: an older build reading a profile that
      // carries an avatar shipped later must show initials, not a hole.
      await tester.pumpWidget(
        _wrap(
          const UserAvatar(
            displayName: 'Awa Diop',
            avatarId: 'human_shipped_in_a_newer_build',
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('AD'), findsOneWidget);
    });

    testWidgets('an animal gets NO colour mapper', (tester) async {
      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'Awa', avatarId: 'animal_blob1')),
      );

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (picture.bytesLoader as SvgAssetLoader).colorMapper,
        isNull,
        reason: 'an animal has no skin to recolour',
      );
    });

    testWidgets('a human gets the mapper of its tone', (tester) async {
      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'Awa', avatarId: 'human_afro1_t4')),
      );

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final mapper = (picture.bytesLoader as SvgAssetLoader).colorMapper;
      expect(mapper, isNotNull);
      // Index 3, because the id suffix is 1-based.
      expect(
        mapper!.substitute(
          null,
          'path',
          'fill',
          const Color(AvatarCatalog.skinSentinelArgb),
        ),
        Color(AvatarCatalog.skinTones[3]),
      );
    });

    testWidgets('two tones give UNEQUAL mappers, one tone gives equal ones', (
      tester,
    ) async {
      // This is the test that protects scroll performance, not correctness.
      // `colorMapper` takes part in SvgCacheKey's hashCode and ==, so a mapper
      // without value equality would miss the cache on every rebuild and
      // re-parse the SVG: invisible on screen, visible while scrolling a chat
      // list.
      ColorMapper? currentMapper() {
        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        return (picture.bytesLoader as SvgAssetLoader).colorMapper;
      }

      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'A', avatarId: 'human_afro1_t1')),
      );
      final t1 = currentMapper();

      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'B', avatarId: 'human_bantu1_t1')),
      );
      final sameTone = currentMapper();

      await tester.pumpWidget(
        _wrap(const UserAvatar(displayName: 'C', avatarId: 'human_afro1_t6')),
      );
      final t6 = currentMapper();

      expect(t1, sameTone, reason: 'same tone must share one cache key');
      expect(t1, isNot(t6), reason: 'different tones must not collide');
    });

    testWidgets('it stays inside its box at a small radius', (tester) async {
      // radius 10 is the catalogue card, radius 14 the chat bubble: the
      // smallest places this widget is asked to draw a whole bust.
      await tester.pumpWidget(
        _wrap(
          const UserAvatar(
            displayName: 'Awa',
            avatarId: 'human_afro1_t2',
            radius: 10,
          ),
        ),
      );

      final size = tester.getSize(find.byType(SvgPicture));
      expect(size.width, 20);
      expect(size.height, 20);
    });
  });
}
