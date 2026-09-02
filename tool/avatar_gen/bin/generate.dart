/// Generates the Outalma avatar catalogue into `assets/avatars/`.
///
///   cd tool/avatar_gen && dart pub get
///   dart run bin/generate.dart
///
/// Run it again after editing `lib/manifest.dart`, and commit the SVGs it
/// writes. Nothing in `lib/` of the app imports this package: the DiceBear
/// packages are development tooling, never a runtime dependency.
///
/// Three guards, each of which has to hold before a single file is written.
///
///  1. INTENT. For every entry, the options DiceBear actually resolved are
///     compared to the intent recorded in the manifest. This is the guard that
///     matters: since DiceBear 10 a component option is suffixed `Variant`, and
///     writing `head:` instead of `headVariant:` is accepted and ignored in
///     silence, leaving the component to the seeded draw. A guard that checked
///     key NAMES would pass that happily, because `head` is a legal component
///     name. Comparing resolved options against intent cannot.
///
///  2. SENTINEL COVERAGE, differentially. Each human is rendered TWICE with two
///     different sentinel skin colours, and the two outputs must be identical
///     once the token is substituted. "The sentinel appears at least once" does
///     not prove it covers ALL the skin, and would miss a derived shade or a
///     shadow. This also catches a sentinel that collides with a colour the
///     drawing already uses. It is reliable because `<defs>` ids are hashed
///     from style plus seed, not random (`idRandomization` is false).
///
///  3. CONTENT. No remote reference can slip into the bundle, nothing animates
///     (flutter_svg ignores SMIL, so an animated file would render differently
///     from the reference without a word), and the counts are exactly 28 / 12.
library;

import 'dart:io';

import 'package:avatar_gen/manifest.dart';
import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/critters.dart' as critters_style;
import 'package:dicebear_styles/open_peeps.dart' as open_peeps_style;

/// The sentinel written into the shipped files. The app substitutes it at
/// render time with the tone the user picked.
const String kSkinSentinel = '#FF00FF';

/// Second sentinel, used only by the differential proof, never written out.
const String kSkinProbe = '#00FF00';

const int kExpectedHumans = 28;
const int kExpectedAnimals = 12;

/// The three entries whose hair colour carries the whole "elder" reading.
const Set<String> _elderIds = {
  'human_graybun',
  'human_graymed',
  'human_grayshort',
};

void main(List<String> args) {
  final humans = catalogue.where((e) => e.isHuman).length;
  final animals = catalogue.length - humans;

  final failures = <String>[];

  /// Colours pinned on a component that does not reference them. Harmless, but
  /// worth printing: a pin nobody reads is either a wrong expectation or dead
  /// weight in the manifest.
  final unusedColours = <String>[];

  if (humans != kExpectedHumans || animals != kExpectedAnimals) {
    failures.add(
      'catalogue holds $humans humans and $animals animals, '
      'expected $kExpectedHumans and $kExpectedAnimals',
    );
  }

  final ids = catalogue.map((e) => e.id).toList();
  final duplicates = ids.where((id) => ids.where((o) => o == id).length > 1);
  if (duplicates.isNotEmpty) {
    failures.add('duplicate ids: ${duplicates.toSet().join(', ')}');
  }

  final idPattern = RegExp(r'^(human|animal)_[a-z0-9]{1,20}$');
  for (final id in ids) {
    if (!idPattern.hasMatch(id)) {
      failures.add('id "$id" does not match the catalogue grammar');
    }
  }

  final styles = <AvatarStyle, Style>{
    AvatarStyle.openPeeps: Style.parse(open_peeps_style.openPeeps),
    AvatarStyle.critters: Style.parse(critters_style.critters),
  };

  final rendered = <String, String>{};

  for (final entry in catalogue) {
    final style = styles[entry.style]!;

    // Guard 3a: every key must be one the style actually accepts. This does not
    // replace guard 1, it only turns a typo into a clear message instead of a
    // silent no-op.
    final legalKeys = OptionsDescriptor(style).toJson().keys.toSet();
    for (final key in _optionsFor(entry, kSkinSentinel).keys) {
      if (!legalKeys.contains(key)) {
        failures.add('${entry.id}: "$key" is not an option of this style');
      }
    }

    final avatar = Avatar(style, _optionsFor(entry, kSkinSentinel));

    // Guard 1: resolved options must equal the intent.
    //
    // Read on the real package before being written, because the shape is not
    // what one would guess: a `*Variant` resolves to a bare string, a `*Color`
    // resolves to a LIST, a `*Probability` does not appear at all (it is
    // consumed to decide whether the component is drawn), and a `*Color`
    // resolves to null when the chosen component does not reference that
    // colour, which is the case of `afro` and `headContrastColor`.
    final resolved = avatar.resolvedOptions;
    entry.options.forEach((key, intended) {
      // Probabilities leave no trace in the resolved map. They are not
      // unchecked for all that: their effect is exactly whether the matching
      // `*Variant` shows up below, which IS asserted.
      if (key.endsWith('Probability')) return;

      final got = resolved[key];

      if (key.endsWith('Variant')) {
        final want = intended is List ? intended.single : intended;
        if (got == null || !_matches(want, got)) {
          failures.add(
            '${entry.id}: $key resolved to "$got", manifest asked for "$want". '
            'Since DiceBear 10 a component option is suffixed Variant; an '
            'unsuffixed key is accepted and ignored in silence.',
          );
        }
        return;
      }

      // A colour the chosen component never references resolves to null. That
      // is legitimate (see `afro`), so it is listed at the end rather than
      // failing the run, EXCEPT for the elders below where the hair colour is
      // the whole point.
      if (got == null) {
        unusedColours.add('${entry.id}: $key');
        return;
      }
      if (!_matches(intended, got)) {
        failures.add(
          '${entry.id}: $key resolved to "$got", manifest asked for "$intended"',
        );
      }
    });

    // Guard 1b: the three elders read as elders ONLY through their hair colour.
    // Of the ten headContrast palette values `#e8e1e1` is the only one that
    // reads grey, so left to the seeded draw an elder comes out brown-haired
    // nine times out of ten and the category disappears without a failing
    // test. This asserts the colour actually REACHED the drawing.
    if (_elderIds.contains(entry.id)) {
      final got = resolved['headContrastColor'];
      if (got == null || !_matches([kElderHair], got)) {
        failures.add(
          '${entry.id}: an elder resolved headContrastColor to "$got", '
          'expected $kElderHair',
        );
      }
    }

    // Strip the embedded RDF metadata block. It is 8 per cent of the raw
    // catalogue (26.7 KB of 331.6 KB) and flutter_svg logs an "unhandled
    // element <metadata/>" line for it on EVERY parse, so it would be dead
    // weight in the bundle plus a log line per avatar render. The provenance it
    // carried is recorded in docs/avatars-licence.md instead, and CC0 requires
    // no attribution in the artifact. Deterministic, so regenerating still
    // reproduces these files byte for byte.
    final svg = _stripMetadata(avatar.svg);

    // Guard 2: differential sentinel proof, humans only.
    if (entry.isHuman) {
      final probe = _stripMetadata(
        Avatar(style, _optionsFor(entry, kSkinProbe)).svg,
      );
      final normalised = svg.replaceAll(
        RegExp(kSkinSentinel, caseSensitive: false),
        'SKIN',
      );
      final normalisedProbe = probe.replaceAll(
        RegExp(kSkinProbe, caseSensitive: false),
        'SKIN',
      );
      if (normalised != normalisedProbe) {
        failures.add(
          '${entry.id}: the two sentinel renders differ once the token is '
          'substituted, so some skin is NOT carried by skinColor (or the '
          'sentinel collides with an intrinsic colour)',
        );
      }
      if (!svg.toLowerCase().contains(kSkinSentinel.toLowerCase())) {
        failures.add('${entry.id}: sentinel absent from a human');
      }
    } else if (svg.toLowerCase().contains(kSkinSentinel.toLowerCase())) {
      failures.add('${entry.id}: sentinel present in an animal');
    }

    // Guard 3b: nothing remote, nothing animated.
    for (final forbidden in ['<image', 'xlink:href', 'url(http', '<animate']) {
      if (svg.toLowerCase().contains(forbidden.toLowerCase())) {
        failures.add('${entry.id}: contains "$forbidden"');
      }
    }

    rendered[entry.id] = svg;
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Generation refused, ${failures.length} problem(s):');
    for (final f in failures) {
      stderr.writeln('  - $f');
    }
    exitCode = 1;
    return;
  }

  // Resolve the output directory from the script location, not the cwd, so the
  // command works from anywhere.
  final root = Directory(Platform.script.resolve('../../..').toFilePath());
  final out = Directory('${root.path}assets/avatars');
  if (!out.existsSync()) {
    out.createSync(recursive: true);
  }

  var bytes = 0;
  rendered.forEach((id, svg) {
    final file = File('${out.path}/$id.svg');
    file.writeAsStringSync(svg);
    bytes += svg.length;
  });

  stdout.writeln(
    'Wrote ${rendered.length} avatars '
    '($kExpectedHumans humans, $kExpectedAnimals animals) '
    'to ${out.path}, ${(bytes / 1024).toStringAsFixed(1)} KB raw.',
  );
  if (unusedColours.isNotEmpty) {
    stdout.writeln(
      '${unusedColours.length} colour pin(s) the chosen component does not '
      'reference (legitimate, e.g. afro ignores headContrastColor):',
    );
    for (final u in unusedColours) {
      stdout.writeln('  $u');
    }
  }
  if (args.contains('--verbose')) {
    rendered.forEach((id, svg) => stdout.writeln('  $id  ${svg.length} B'));
  }
}

/// Builds the full option map for an entry: the shared floor, then the
/// manifest's pins on top. Every probability is pinned so nothing is left to
/// the seeded draw.
Map<String, Object> _optionsFor(AvatarEntry entry, String sentinel) {
  final base = <String, Object>{
    'seed': entry.id,
    'idRandomization': false,
    'backgroundColor': [kTileBackground],
  };

  if (entry.isHuman) {
    base.addAll({
      'headProbability': 100,
      'expressionProbability': 100,
      // Absent unless the entry asks for them.
      'accessoriesProbability': 0,
      'facialHairProbability': 0,
      'maskProbability': 0,
      'inkColor': ['#000000'],
      'skinColor': [sentinel],
    });
  } else {
    base.addAll({
      'bodyProbability': 100,
      'topProbability': 100,
      'patternProbability': 100,
      'cheeksProbability': 100,
      'eyesProbability': 100,
      'mouthProbability': 100,
      'animationVariant': ['none'],
      'animationProbability': 100,
      'inkColor': [kCrittersInk],
    });
  }

  base.addAll(entry.options);
  return base;
}

/// Removes the `<metadata>...</metadata>` block DiceBear embeds.
String _stripMetadata(String svg) =>
    svg.replaceAll(RegExp(r'<metadata.*?</metadata>', dotAll: true), '');

/// Resolved options come back normalised (a single value rather than the list
/// that was passed, a `Color` rather than a hex string), so compare loosely on
/// the string form.
bool _matches(Object? want, Object? got) {
  if (want == got) return true;
  final w = want.toString().toLowerCase().replaceAll('#', '');
  final g = got.toString().toLowerCase().replaceAll('#', '');
  return w == g;
}
