// Contract tests on the SHIPPED asset files, read from disk.
//
// These live in `flutter test` rather than in tool/avatar_gen on purpose: they
// are what protects the bundle from a remote reference and the recolouring from
// a false positive, so they must run on every commit, not at the discretion of
// whoever regenerates. Same idiom as test/l10n/arb_parity_test.dart, which
// already reads the .arb files off disk.
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/avatars/avatar_catalog.dart';

void main() {
  final dir = Directory('assets/avatars');
  // Only *.svg: the licence deliberately lives in docs/, but globbing keeps the
  // assertion honest if anything else ever lands here.
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.svg'))
      .toList();
  String idOf(File f) => f.uri.pathSegments.last.replaceAll('.svg', '');
  String read(File f) => f.readAsStringSync().toLowerCase();

  test('every catalogue id has an asset, and every asset an id', () {
    final onDisk = files.map(idOf).toSet();
    final inCatalogue = AvatarCatalog.allIds.toSet();

    expect(
      inCatalogue.difference(onDisk),
      isEmpty,
      reason: 'catalogue ids with no file: regenerate the assets',
    );
    expect(
      onDisk.difference(inCatalogue),
      isEmpty,
      reason: 'orphan files with no catalogue id: add them or delete them',
    );
  });

  test('the counts are exactly 28 humans and 12 animals', () {
    final ids = files.map(idOf);
    expect(
      ids.where((i) => i.startsWith('human_')),
      hasLength(AvatarCatalog.humanCount),
    );
    expect(
      ids.where((i) => i.startsWith('animal_')),
      hasLength(AvatarCatalog.animalCount),
    );
  });

  test('the skin sentinel is in every human and in no animal', () {
    // Case-insensitive: the generator writes #FF00FF, the file may carry
    // either case, and a case-sensitive check would pass while the app's
    // ColorMapper still matched. Compare on the value, not the spelling.
    final sentinel = AvatarCatalog.skinSentinelArgb
        .toRadixString(16)
        .substring(2); // drop the alpha byte
    for (final f in files) {
      final isHuman = idOf(f).startsWith('human_');
      expect(
        read(f).contains('#$sentinel'),
        isHuman,
        reason: isHuman
            ? '${idOf(f)} has no skin sentinel, so it cannot be recoloured'
            : '${idOf(f)} is an animal and must carry no skin sentinel',
      );
    }
  });

  test('the three elders really carry the grey hair', () {
    // headContrastColor has ten palette values and only this one reads grey.
    // Unpinned, an elder comes out brown-haired nine times out of ten and the
    // category disappears without a failing test. This is that failing test.
    for (final id in AvatarCatalog.elderIds) {
      final file = files.firstWhere((f) => idOf(f) == id);
      expect(
        read(file).contains(AvatarCatalog.elderHairHex),
        isTrue,
        reason: '$id lost its grey hair, so it no longer reads as an elder',
      );
    }
  });

  test('no asset reaches the network or animates', () {
    // A remote reference would leak a request from every viewer's device. An
    // animation would render differently from the reference in silence, since
    // flutter_svg ignores SMIL.
    const forbidden = [
      '<image',
      'xlink:href',
      'url(http',
      '<animate',
      '<style',
      // A CSS-declared animation would slip past the two above.
      'animation:',
    ];
    for (final f in files) {
      final body = read(f);
      for (final needle in forbidden) {
        expect(
          body.contains(needle),
          isFalse,
          reason: '${idOf(f)} contains "$needle"',
        );
      }
    }
  });

  test('all 40 assets carry the SAME full-canvas background', () {
    // Rewritten after a code review: the previous version was green for the
    // wrong reason. It matched `<rect width="100%?"`, which only ever hit the
    // animals (a human viewBox is 704x704, an animal 100x100), and its
    // fallback hardcoded the expected colour, so it could not fail. A
    // regeneration that gave every file a red background would have passed
    // while the widget kept painting the old colour behind it, showing a seam
    // on all 40 tiles.
    //
    // Now: every file must MATCH, the width and height must agree, and the one
    // colour collected must be the constant the widget paints.
    final expected =
        '#'
        '${(AvatarCatalog.tileBackgroundArgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final backgrounds = <String, String>{};
    for (final f in files) {
      final match = RegExp(
        r'<rect width="(100|704)" height="\1" fill="(#[0-9a-f]{6})"',
      ).firstMatch(read(f));
      expect(
        match,
        isNotNull,
        reason: '${idOf(f)} has no full-canvas background rect',
      );
      backgrounds[idOf(f)] = match!.group(2)!;
    }

    expect(backgrounds, hasLength(AvatarCatalog.allIds.length));
    expect(
      backgrounds.values.toSet(),
      {expected},
      reason:
          'the 40 tiles must all carry $expected, the colour '
          'UserAvatar paints behind them; got ${backgrounds.values.toSet()}',
    );
  });

  test('every asset parses through flutter_svg without throwing', () async {
    // The cheapest guard of the lot. DiceBear output uses <use> and clip-path,
    // and an asset that rendered only partially would otherwise be caught by
    // nothing but the eye during a smoke test. This goes through
    // SvgStringLoader, the very front end SvgPicture uses, rather than a
    // lookalike parser.
    for (final f in files) {
      final loader = SvgStringLoader(f.readAsStringSync());
      await expectLater(
        loader.loadBytes(null),
        completes,
        reason: '${idOf(f)} does not parse',
      );
    }
  });

  test('the ColorMapper substitution finds the sentinel in a human', () async {
    // Proves the recolouring contract end to end at the parser level: the
    // sentinel is handed to a ColorMapper, so a human asset whose skin were
    // NOT driven by it would never be recoloured on screen. Counting the
    // substitutions is what makes this more than a smoke check.
    final human = files.firstWhere((f) => idOf(f) == 'human_afro1');
    final mapper = _CountingMapper(AvatarCatalog.skinSentinelArgb);
    await SvgStringLoader(
      human.readAsStringSync(),
      colorMapper: mapper,
    ).loadBytes(null);
    expect(
      mapper.substitutions,
      greaterThan(0),
      reason: 'the sentinel was never seen by the ColorMapper',
    );

    final animal = files.firstWhere((f) => idOf(f) == 'animal_blob1');
    final animalMapper = _CountingMapper(AvatarCatalog.skinSentinelArgb);
    await SvgStringLoader(
      animal.readAsStringSync(),
      colorMapper: animalMapper,
    ).loadBytes(null);
    expect(
      animalMapper.substitutions,
      0,
      reason: 'an animal has no skin to recolour',
    );
  });
}

/// Records every sentinel hit. ColorMapper is `@immutable`, so the tally lives
/// in a final collection rather than a mutable field: an `int` counter trips
/// `must_be_immutable` and the pre-commit analyze blocks on it.
class _CountingMapper extends ColorMapper {
  _CountingMapper(this.sentinel) : hits = <String>[];

  final int sentinel;
  final List<String> hits;

  int get substitutions => hits.length;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color.toARGB32() == sentinel) {
      hits.add('$elementName.$attributeName');
      return const Color(0xFF5A3825);
    }
    return color;
  }
}
