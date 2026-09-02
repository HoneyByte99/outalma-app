import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/domain/avatars/avatar_catalog.dart';
import 'package:outalma_app/src/features/profile/avatar_picker_sheet.dart';

/// Mounts the sheet the way the app does, and captures what it pops.
Future<AvatarPick?> _openSheet(
  WidgetTester tester, {
  String? currentAvatarId,
  bool hasPhoto = false,
}) async {
  AvatarPick? result;
  // A tall surface so all 40 tiles are laid out at once. The sheet's ListView
  // builds lazily, which is right on a real phone, but a 600px test viewport
  // would leave the animals unbuilt and the assertions would be about the
  // viewport rather than about the sheet. Scrolling it instead is not an
  // option: DraggableScrollableSheet consumes the start of an upward drag to
  // grow towards maxChildSize, and the two grids each add their own
  // (non-scrolling) Scrollable, so no single scrollable is the right target.
  await tester.binding.setSurfaceSize(const Size(420, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAvatarPickerSheet(
                  context,
                  currentAvatarId: currentAvatarId,
                  hasPhoto: hasPhoto,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

/// Every id the tiles are currently asking UserAvatar to draw.
List<String> _renderedIds(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .map((p) => (p.bytesLoader as SvgAssetLoader).assetName)
    .toList();

void main() {
  testWidgets('it offers the photo path and both grids', (tester) async {
    await _openSheet(tester);

    expect(find.text('Importer une photo'), findsOneWidget);
    // 40, because the surface set in _openSheet is tall enough for both
    // shrinkWrap grids to lay out fully. That is also the real behaviour on a
    // phone: shrinkWrap builds every tile at once, so the isolate burst on a
    // tone tap covers all 28 humans. It is measured on the device, not here.
    expect(find.byType(SvgPicture), findsNWidgets(40));

    expect(find.text('Animaux'), findsOneWidget);
    expect(
      _renderedIds(tester).where((p) => p.contains('animal_')),
      isNotEmpty,
    );
  });

  testWidgets('the REMOVE row is absent when there is nothing to remove', (
    tester,
  ) async {
    await _openSheet(tester);
    expect(find.text('Retirer, revenir aux initiales'), findsNothing);
  });

  testWidgets('the REMOVE row appears when an avatar is set', (tester) async {
    await _openSheet(tester, currentAvatarId: 'human_afro1_t2');
    expect(find.text('Retirer, revenir aux initiales'), findsOneWidget);
  });

  testWidgets('the REMOVE row appears when a photo is on file', (tester) async {
    await _openSheet(tester, hasPhoto: true);
    expect(find.text('Retirer, revenir aux initiales'), findsOneWidget);
  });

  testWidgets('it opens on the DEFAULT tone when nothing is chosen', (
    tester,
  ) async {
    await _openSheet(tester);

    // The asset path carries no tone: the tone lives in the ColorMapper.
    expect(_renderedIds(tester).first, endsWith('.svg'));
    final mapper =
        (tester
                    .widgetList<SvgPicture>(find.byType(SvgPicture))
                    .first
                    .bytesLoader
                as SvgAssetLoader)
            .colorMapper;
    expect(
      mapper!.substitute(
        null,
        'path',
        'fill',
        const Color(AvatarCatalog.skinSentinelArgb),
      ),
      Color(AvatarCatalog.skinTones[AvatarCatalog.defaultToneIndex]),
    );
    // Nothing is selected in the grid yet, so the only check is the swatch one.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('it opens on the tone the person is ALREADY using', (
    tester,
  ) async {
    // Without this, somebody on tone 5 who opens the sheet and taps another
    // character would be moved back to the default without being told.
    await _openSheet(tester, currentAvatarId: 'human_afro1_t5');

    final tile = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).first;
    final mapper = (tile.bytesLoader as SvgAssetLoader).colorMapper;
    expect(
      mapper!.substitute(
        null,
        'path',
        'fill',
        const Color(AvatarCatalog.skinSentinelArgb),
      ),
      Color(AvatarCatalog.skinTones[4]),
      reason: 'the id suffix is 1-based, so _t5 is index 4',
    );
  });

  testWidgets('the current avatar is marked selected, and only it', (
    tester,
  ) async {
    await _openSheet(tester, currentAvatarId: 'human_afro1_t2');

    // One check on the selected tile, one on the selected swatch.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('tapping a swatch recolours the HUMANS and not the animals', (
    tester,
  ) async {
    await _openSheet(tester);

    Color skinOf(int tileIndex) {
      final picture = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .elementAt(tileIndex);
      final mapper = (picture.bytesLoader as SvgAssetLoader).colorMapper;
      return mapper == null
          ? const Color(0x00000000)
          : mapper.substitute(
              null,
              'path',
              'fill',
              const Color(AvatarCatalog.skinSentinelArgb),
            );
    }

    expect(skinOf(0), Color(AvatarCatalog.skinTones[1]));

    // The lightest swatch is the sixth.
    await tester.tap(find.byKey(const ValueKey('avatar-tone-5')));
    // ONE frame only: the point is what the user sees immediately after the
    // tap, since every visible tile just missed the SVG cache.
    await tester.pump();

    expect(skinOf(0), Color(AvatarCatalog.skinTones[5]));

    // And the animals carry no mapper at all.
    final animalTiles = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .where(
          (p) =>
              (p.bytesLoader as SvgAssetLoader).assetName.contains('animal_'),
        );
    expect(animalTiles, isNotEmpty);
    for (final tile in animalTiles) {
      expect(
        (tile.bytesLoader as SvgAssetLoader).colorMapper,
        isNull,
        reason: 'animals have no skin to recolour',
      );
    }
  });

  testWidgets('choosing an avatar pops PickAvatar with the composed id', (
    tester,
  ) async {
    AvatarPick? captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await showAvatarPickerSheet(
                    context,
                    currentAvatarId: null,
                    hasPhoto: false,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SvgPicture).first);
    await tester.pumpAndSettle();

    expect(captured, isA<PickAvatar>());
    expect(
      (captured! as PickAvatar).avatarId,
      AvatarCatalog.composeId(
        AvatarCatalog.humanIds.first,
        AvatarCatalog.defaultToneIndex,
      ),
    );
  });

  testWidgets('every tile and swatch carries a screen-reader label', (
    tester,
  ) async {
    // A5. Without a label VoiceOver announces nothing at all, and the labels
    // are deliberately neutral (no age, no gender) so the grid never files
    // anybody into a category they did not choose. Asserted on the Semantics
    // WIDGET, the idiom category_filter_bar_test.dart already uses.
    await _openSheet(tester);

    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((w) => w.properties.label)
        .whereType<String>()
        .toList();

    expect(labels, contains('Avatar 1 sur 28'));
    expect(labels, contains('Avatar 28 sur 28'));
    expect(labels, contains('Teinte de peau 1 sur 6'));
    expect(labels, contains('Teinte de peau 6 sur 6'));

    // Selection is exposed too, not just drawn: a screen reader has to be able
    // to tell which tone is active.
    final swatches = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((w) => w.properties.label?.startsWith('Teinte') ?? false);
    expect(swatches.where((w) => w.properties.selected ?? false), hasLength(1));

    expect(labels, contains('Animal 1 sur 12'));
    expect(labels, contains('Animal 12 sur 12'));
  });

  testWidgets('the tap targets clear 44 points', (tester) async {
    // A2, measured rather than asserted by eye.
    await _openSheet(tester);

    // Measured per swatch, by key. The previous loop measured the FIRST widget
    // once per iteration, so it proved nothing about the other five.
    for (var i = 0; i < AvatarCatalog.skinTones.length; i++) {
      final size = tester.getSize(find.byKey(ValueKey('avatar-tone-$i')));
      expect(size.width, greaterThanOrEqualTo(44), reason: 'swatch $i');
      expect(size.height, greaterThanOrEqualTo(44), reason: 'swatch $i');
    }

    // The two action rows too, whose 48pt floor comes from _SheetAction's
    // BoxConstraints. Measuring the TEXT would have been unfalsifiable.
    for (final label in ['Importer une photo']) {
      final row = tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first,
      );
      expect(row.height, greaterThanOrEqualTo(44), reason: label);
    }
  });
}
