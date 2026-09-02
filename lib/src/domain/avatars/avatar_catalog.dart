/// The illustrated avatar catalogue, and the only place that turns an
/// `avatarId` into something drawable.
///
/// An `avatarId` is an opaque catalogue TOKEN, never a path. The asset path is
/// interpolated, but only from a `characterId` already proven to be a member of
/// [humanIds] or [animalIds] on the line before: a value written by a patched
/// client is rejected by that membership check and never reaches the
/// interpolation. Said precisely, because "never concatenated" would be a
/// stronger claim than the code makes, and a reader who noticed the gap could
/// have "corrected" it in either direction.
///
/// Resolution fails CLOSED, the way `BookingStatus.unknown` and
/// `IdentityTrustStatus.fromString` already do in this codebase: anything that
/// is not exactly a known entry resolves to null and the caller falls back to
/// initials. A client on an older build that reads a profile carrying an avatar
/// shipped in a newer build therefore shows initials, not a crash and not an
/// empty square, and no version flag is needed anywhere.
library;

/// A resolved avatar: which asset to draw, and in which skin tone.
class AvatarRef {
  const AvatarRef({
    required this.assetPath,
    required this.characterId,
    required this.toneIndex,
    required this.skinToneArgb,
  });

  /// Full asset key, ready for `SvgPicture.asset`.
  final String assetPath;

  /// The character without its tone suffix. Exposed so no caller has to
  /// re-implement the suffix grammar: the picker needs it to mark the current
  /// tile, and a second copy of `_t[1-6]$` living in `features/` would go
  /// silently stale the day a seventh tone is added.
  final String characterId;

  /// Index into [AvatarCatalog.skinTones], or null for an animal.
  final int? toneIndex;

  /// The colour to substitute for the sentinel, or null for an animal, which
  /// has no skin to recolour.
  final int? skinToneArgb;
}

abstract final class AvatarCatalog {
  /// The magenta the generator wrote into every human asset in place of a skin
  /// colour. Substituted at render time. Nothing else in an Open Peeps drawing
  /// uses it, which the generator proves differentially rather than assuming.
  static const int skinSentinelArgb = 0xFFFF00FF;

  /// The background baked into all 40 assets by the generator. A FACT of the
  /// files, not a theme token: the widget paints it behind the drawing so the
  /// disc and the artwork cannot show a seam, and it stays the same in both
  /// themes because a picture does not invert. Changing it means regenerating
  /// the catalogue, which is why `avatar_assets_test.dart` asserts the shipped
  /// files really carry this exact value.
  static const int tileBackgroundArgb = 0xFFEDF2F5;

  /// Six tones, darkest first. Frozen: the id stores an INDEX, so changing a
  /// value here silently changes the appearance of everyone who picked it.
  static const List<int> skinTones = <int>[
    0xFF3B2219,
    0xFF5A3825,
    0xFF8D5524,
    0xFFC68642,
    0xFFE0AC69,
    0xFFF1C27D,
  ];

  /// Default tone: deliberately the second, not the first. On `#3B2219` the
  /// black line art that draws the eyes and the mouth loses contrast and the
  /// face reads less well. This keeps a firmly dark default while the darkest
  /// tone stays one tap away.
  static const int defaultToneIndex = 1;

  /// Colour of the check mark drawn on the selected tone swatch. A single
  /// colour cannot serve: white on `#F1C27D` measures 1.65:1 and `#0D1F2D` on
  /// `#3B2219` measures 1.14:1, so both uniform choices fail. Measured ratios
  /// for the values below, all above the 4.5:1 for text and well above the
  /// 3:1 required of a meaningful interface element: 14.70, 10.36, 6.07, 5.51,
  /// 8.21, 10.19. `test/domain/avatars/avatar_contrast_test.dart` recomputes
  /// them so the bar cannot be crossed in silence.
  static const List<int> toneCheckColors = <int>[
    0xFFFFFFFF,
    0xFFFFFFFF,
    0xFFFFFFFF,
    0xFF0D1F2D,
    0xFF0D1F2D,
    0xFF0D1F2D,
  ];

  /// The grammar the server also enforces, in `firestore.rules` and in
  /// `projectPublicProfile`. The character class is what makes a path
  /// traversal impossible rather than improbable: no dot, no slash, no
  /// backslash, no percent, no space, nothing outside ASCII, so no homoglyph
  /// either. The anchored pattern also bounds the length at 30 characters,
  /// which is why no separate size cap is needed.
  static const String idPattern = r'^(human|animal)_[a-z0-9]{1,20}(_t[1-6])?$';

  static final RegExp _id = RegExp(idPattern);

  static const String _assetDir = 'assets/avatars';

  /// The 28 human characters. Kept in step with the shipped files by
  /// `test/domain/avatars/avatar_assets_test.dart`, which compares this list
  /// against the directory in BOTH directions.
  static const List<String> humanIds = <String>[
    'human_afro1',
    'human_bantu1',
    'human_bun1',
    'human_buns1',
    'human_cornrows1',
    'human_cornrows2',
    'human_curly1',
    'human_dreads1',
    'human_dreads2',
    'human_flattop',
    'human_graybun',
    'human_graymed',
    'human_grayshort',
    'human_hijab1',
    'human_long1',
    'human_longafro',
    'human_medium1',
    'human_mohawk1',
    'human_nohair1',
    'human_nohair2',
    'human_pomp1',
    'human_shaved1',
    'human_shaved2',
    'human_shaved3',
    'human_short1',
    'human_turban1',
    'human_twists1',
    'human_twists2',
  ];

  /// The 12 animal characters. They have no skin, so no tone.
  static const List<String> animalIds = <String>[
    'animal_bell1',
    'animal_blob1',
    'animal_block1',
    'animal_chimney1',
    'animal_dome1',
    'animal_lean1',
    'animal_peak1',
    'animal_round1',
    'animal_squat1',
    'animal_steps1',
    'animal_tower1',
    'animal_wedge1',
  ];

  /// The three entries whose grey hair is the whole reason they read as elders.
  /// Named here so a test can assert the asset really carries the grey.
  static const List<String> elderIds = <String>[
    'human_graybun',
    'human_graymed',
    'human_grayshort',
  ];

  /// Hair colour of the elders, as written into their assets.
  static const String elderHairHex = '#e8e1e1';

  static const int humanCount = 28;
  static const int animalCount = 12;

  /// Every id in the catalogue, humans then animals: the order the picker
  /// grid uses.
  static List<String> get allIds => <String>[...humanIds, ...animalIds];

  /// Builds the id stored on a profile for [characterId] in [toneIndex].
  /// Animals ignore the tone, because they have no skin to tint.
  static String composeId(String characterId, int toneIndex) {
    if (animalIds.contains(characterId)) return characterId;
    return '${characterId}_t${toneIndex + 1}';
  }

  /// Resolves a stored id. NEVER throws, and returns null for anything that is
  /// not exactly a catalogue entry, so an unknown value degrades to initials.
  static AvatarRef? parse(String? avatarId) {
    if (avatarId == null || avatarId.isEmpty) return null;
    if (!_id.hasMatch(avatarId)) return null;

    // Split the optional `_tN` suffix off the character id.
    var characterId = avatarId;
    int? toneIndex;
    final suffix = RegExp(r'_t([1-6])$').firstMatch(avatarId);
    if (suffix != null) {
      characterId = avatarId.substring(0, suffix.start);
      toneIndex = int.parse(suffix.group(1)!) - 1;
    }

    final isHuman = humanIds.contains(characterId);
    final isAnimal = !isHuman && animalIds.contains(characterId);
    if (!isHuman && !isAnimal) return null;

    if (isAnimal) {
      // A tone on an animal is meaningless rather than invalid: the character
      // still resolves and the tone is dropped.
      return AvatarRef(
        assetPath: '$_assetDir/$characterId.svg',
        characterId: characterId,
        toneIndex: null,
        skinToneArgb: null,
      );
    }

    // A human with no tone predates the suffix or was written by another
    // client: fall back to the default rather than refusing to draw.
    final tone = toneIndex ?? defaultToneIndex;
    return AvatarRef(
      assetPath: '$_assetDir/$characterId.svg',
      characterId: characterId,
      toneIndex: tone,
      skinToneArgb: skinTones[tone],
    );
  }
}
