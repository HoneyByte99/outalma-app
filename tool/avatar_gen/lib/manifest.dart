/// THE catalogue. This file, not the generator, is the source of truth for
/// what the 40 avatars are.
///
/// Every option that influences how a character reads is PINNED to a single
/// value. That is not verbosity, it is the whole design: in DiceBear an option
/// receives a LIST and a seeded PRNG draws from it, so a list of one forces the
/// choice whatever the seed. The result is a pure function of this file.
///
/// Two traps this file exists to avoid, both of which cost a full pass when
/// missed:
///
///  1. Since DiceBear 10 a component option is suffixed `Variant`. The trap that
///     name is guarding against is REAL, but it lives in the HTTP API, not here:
///     `api.dicebear.com/10.x/open-peeps/svg?seed=Test&head=afro` returns 200 and
///     draws `head-grayBun`, a seeded draw, because the API ignores unknown query
///     parameters. Verified against the live API.
///
///     The Dart library does NOT: `Options._validateAndCopy` refuses an unknown
///     key outright, so `'head': ['afro']` in the manifest throws
///     `Invalid options: unallowed additional property head` before any guard in
///     this file runs. Verified by mutation.
///
///     This comment is on its third revision and each one was wrong in a way worth
///     recording: it first credited the resolved-options check with catching the
///     suffix (it would only have warned), then the key-name check (which does
///     refuse it, but never gets the chance), and the truth is that the library
///     fails loudly on its own. The two generator guards are therefore BELTS, and
///     they still earn their place on what the library does not check: a legal key
///     carrying a wrong value, and a `*Variant` that resolves to nothing.
///
///  2. `headContrastColor` is the hair colour, and only `#e8e1e1` of its ten
///     palette values reads as grey. Left unpinned, an elder comes out
///     brown-haired nine times out of ten and the category vanishes without a
///     single failing test.
///
/// Skin colour is deliberately ABSENT here: the generator injects a sentinel
/// and the app recolours it at runtime.
library;

/// Which DiceBear style an entry is drawn from.
enum AvatarStyle { openPeeps, critters }

/// One catalogue entry: a stable id, a style, and the fully pinned options.
class AvatarEntry {
  const AvatarEntry({
    required this.id,
    required this.style,
    required this.options,
  });

  /// Matches `AvatarCatalog.idPattern` on the app side, minus the tone suffix.
  /// The asset is written as `<id>.svg`, so this is also the file name.
  final String id;
  final AvatarStyle style;

  /// Pinned options, keyed exactly as `OptionsDescriptor` names them.
  final Map<String, Object> options;

  bool get isHuman => style == AvatarStyle.openPeeps;
}

// Palette values, quoted from the style definitions so a reader does not have
// to trust a hex out of nowhere.
//
// open_peeps clothing : #8fa7df #78e185 #ffcf77 #e279c7 #e78276 #9ddadb #fdea6b
// open_peeps headContrast (10) : #2c1b18 #e8e1e1 #ecdcbf #d6b370 #f59797
//                                #b58143 #a55728 #724133 #4a312c #c93305
// open_peeps ink : #000000 (single value)
// critters body/accent (12) : #7dd3fc #a5b4fc #c4b5fd #f0abfc #fda4af #fca5a5
//                             #fdba74 #fcd34d #bef264 #6ee7b9 #5eead4 #e2e8f0
// critters ink : #1e293b (single value)

/// Hair colour of the three elders. The ONLY value of the ten that reads grey.
const String kElderHair = '#e8e1e1';

/// Shared background for all 40 tiles, human and animal alike, so the grid
/// reads as one set. Equal to `AppColors.surfaceVariant` on the app side.
/// Pinned for the animals because a Critters background is NOT transparent: it
/// ships an opaque full-canvas rect, and left to the draw it would be one of
/// twelve saturated colours behind the ink.
const String kTileBackground = '#EDF2F5';

/// `#e2e8f0` is excluded from every animal body: at 1.06:1 against
/// [kTileBackground] the creature would be an outline and nothing else.
const String kCrittersInk = '#1e293b';

const List<AvatarEntry> catalogue = [
  // ---------------------------------------------------------------------------
  // Humans. No age or gender label is ever shown (product decision): the spread
  // below serves variety, it is not a taxonomy the interface announces.
  // Afro-textured hair is first-class here, not an afterthought: afro, longAfro,
  // bantuKnots, cornrows, cornrows2, twists, twists2, dreads1, dreads2, plus
  // hijab and turban.
  // ---------------------------------------------------------------------------
  AvatarEntry(
    id: 'human_afro1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['afro'],
      'expressionVariant': ['smile'],
      'clothingColor': ['#8fa7df'],
    },
  ),
  AvatarEntry(
    id: 'human_longafro',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['longAfro'],
      'expressionVariant': ['smileBig'],
      'clothingColor': ['#78e185'],
    },
  ),
  AvatarEntry(
    id: 'human_bantu1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['bantuKnots'],
      'expressionVariant': ['calm'],
      'clothingColor': ['#ffcf77'],
    },
  ),
  AvatarEntry(
    id: 'human_cornrows1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['cornrows'],
      'expressionVariant': ['cheeky'],
      'clothingColor': ['#e279c7'],
      'headContrastColor': ['#2c1b18'],
    },
  ),
  AvatarEntry(
    id: 'human_cornrows2',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['cornrows2'],
      'expressionVariant': ['lovingGrin1'],
      'clothingColor': ['#9ddadb'],
    },
  ),
  AvatarEntry(
    id: 'human_twists1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['twists'],
      'expressionVariant': ['smile'],
      'clothingColor': ['#fdea6b'],
    },
  ),
  AvatarEntry(
    id: 'human_twists2',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['twists2'],
      'expressionVariant': ['awe'],
      'clothingColor': ['#e78276'],
    },
  ),
  AvatarEntry(
    id: 'human_hijab1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['hijab'],
      'expressionVariant': ['calm'],
      'clothingColor': ['#8fa7df'],
    },
  ),
  AvatarEntry(
    id: 'human_bun1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['bun'],
      'expressionVariant': ['serious'],
      'accessoriesVariant': ['glasses2'],
      'accessoriesProbability': 100,
      'clothingColor': ['#78e185'],
    },
  ),
  AvatarEntry(
    id: 'human_long1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['long'],
      'expressionVariant': ['smile'],
      'clothingColor': ['#e279c7'],
    },
  ),
  AvatarEntry(
    id: 'human_curly1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['longCurly'],
      'expressionVariant': ['smileTeethGap'],
      'clothingColor': ['#9ddadb'],
    },
  ),
  AvatarEntry(
    id: 'human_buns1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['buns'],
      'expressionVariant': ['smileLOL'],
      'clothingColor': ['#8fa7df'],
    },
  ),
  AvatarEntry(
    id: 'human_medium1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['medium1'],
      'expressionVariant': ['smile'],
      'clothingColor': ['#ffcf77'],
    },
  ),
  AvatarEntry(
    id: 'human_shaved1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['shaved1'],
      'expressionVariant': ['serious'],
      'facialHairVariant': ['full'],
      'facialHairProbability': 100,
      'clothingColor': ['#8fa7df'],
    },
  ),
  AvatarEntry(
    id: 'human_shaved2',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['shaved2'],
      'expressionVariant': ['calm'],
      'facialHairVariant': ['goatee1'],
      'facialHairProbability': 100,
      'clothingColor': ['#78e185'],
    },
  ),
  AvatarEntry(
    id: 'human_shaved3',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['shaved3'],
      'expressionVariant': ['driven'],
      'facialHairVariant': ['moustache1'],
      'facialHairProbability': 100,
      'clothingColor': ['#ffcf77'],
    },
  ),
  AvatarEntry(
    id: 'human_flattop',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['flatTop'],
      'expressionVariant': ['smile'],
      'facialHairVariant': ['chin'],
      'facialHairProbability': 100,
      'clothingColor': ['#e279c7'],
    },
  ),
  AvatarEntry(
    id: 'human_pomp1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['pomp'],
      'expressionVariant': ['explaining'],
      'accessoriesVariant': ['glasses'],
      'accessoriesProbability': 100,
      'clothingColor': ['#9ddadb'],
    },
  ),
  AvatarEntry(
    id: 'human_dreads1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['dreads1'],
      'expressionVariant': ['smileBig'],
      'clothingColor': ['#fdea6b'],
    },
  ),
  AvatarEntry(
    id: 'human_dreads2',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['dreads2'],
      'expressionVariant': ['cheeky'],
      'facialHairVariant': ['full2'],
      'facialHairProbability': 100,
      'clothingColor': ['#e78276'],
    },
  ),
  AvatarEntry(
    id: 'human_nohair1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['noHair1'],
      'expressionVariant': ['solemn'],
      'facialHairVariant': ['moustache3'],
      'facialHairProbability': 100,
      'clothingColor': ['#8fa7df'],
    },
  ),
  AvatarEntry(
    id: 'human_nohair2',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['noHair2'],
      'expressionVariant': ['smile'],
      'accessoriesVariant': ['glasses5'],
      'accessoriesProbability': 100,
      'clothingColor': ['#78e185'],
    },
  ),
  AvatarEntry(
    id: 'human_turban1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['turban'],
      'expressionVariant': ['calm'],
      'facialHairVariant': ['full3'],
      'facialHairProbability': 100,
      'clothingColor': ['#ffcf77'],
    },
  ),
  AvatarEntry(
    id: 'human_short1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['short1'],
      'expressionVariant': ['smile'],
      'clothingColor': ['#e279c7'],
    },
  ),
  AvatarEntry(
    id: 'human_mohawk1',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['mohawk'],
      'expressionVariant': ['driven'],
      'clothingColor': ['#78e185'],
      'headContrastColor': ['#c93305'],
    },
  ),
  // The three elders. `kElderHair` is what makes them read as elders at all.
  AvatarEntry(
    id: 'human_graybun',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['grayBun'],
      'expressionVariant': ['old'],
      'clothingColor': ['#9ddadb'],
      'headContrastColor': [kElderHair],
    },
  ),
  AvatarEntry(
    id: 'human_graymed',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['grayMedium'],
      'expressionVariant': ['solemn'],
      'accessoriesVariant': ['glasses3'],
      'accessoriesProbability': 100,
      'clothingColor': ['#fdea6b'],
      'headContrastColor': [kElderHair],
    },
  ),
  AvatarEntry(
    id: 'human_grayshort',
    style: AvatarStyle.openPeeps,
    options: {
      'headVariant': ['grayShort'],
      'expressionVariant': ['tired'],
      'facialHairVariant': ['full4'],
      'facialHairProbability': 100,
      'clothingColor': ['#e78276'],
      'headContrastColor': [kElderHair],
    },
  ),

  // ---------------------------------------------------------------------------
  // Animals. Critters draws friendly creatures (ears, horns, fins, antennae),
  // not named species: it is the only CC0 animal-ish style in the package.
  // ---------------------------------------------------------------------------
  AvatarEntry(
    id: 'animal_round1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['round'],
      'topVariant': ['earsRound'],
      'patternVariant': ['spot'],
      'cheeksVariant': ['blush'],
      'eyesVariant': ['happy'],
      'mouthVariant': ['smile'],
      'bodyColor': ['#fdba74'],
      'accentColor': ['#fca5a5'],
    },
  ),
  AvatarEntry(
    id: 'animal_blob1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['blob'],
      'topVariant': ['earsDroop'],
      'patternVariant': ['dots'],
      'cheeksVariant': ['freckles'],
      'eyesVariant': ['bigPupils'],
      'mouthVariant': ['grin'],
      'bodyColor': ['#7dd3fc'],
      'accentColor': ['#a5b4fc'],
    },
  ),
  AvatarEntry(
    id: 'animal_dome1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['dome'],
      'topVariant': ['hornsSmall'],
      'patternVariant': ['stripes'],
      'cheeksVariant': ['blushBig'],
      'eyesVariant': ['round'],
      'mouthVariant': ['tinySmile'],
      'bodyColor': ['#bef264'],
      'accentColor': ['#6ee7b9'],
    },
  ),
  AvatarEntry(
    id: 'animal_bell1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['bell'],
      'topVariant': ['antennae'],
      'patternVariant': ['speckles'],
      'cheeksVariant': ['blush'],
      'eyesVariant': ['wide'],
      'mouthVariant': ['ooh'],
      'bodyColor': ['#f0abfc'],
      'accentColor': ['#c4b5fd'],
    },
  ),
  AvatarEntry(
    id: 'animal_tower1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['tower'],
      'topVariant': ['earsPointy'],
      'patternVariant': ['bars'],
      'cheeksVariant': ['freckles'],
      'eyesVariant': ['squint'],
      'mouthVariant': ['smirk'],
      'bodyColor': ['#a5b4fc'],
      'accentColor': ['#7dd3fc'],
    },
  ),
  AvatarEntry(
    id: 'animal_squat1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['squat'],
      'topVariant': ['crown'],
      'patternVariant': ['ring'],
      'cheeksVariant': ['blush'],
      'eyesVariant': ['trio'],
      'mouthVariant': ['laugh'],
      'bodyColor': ['#fcd34d'],
      'accentColor': ['#fdba74'],
    },
  ),
  AvatarEntry(
    id: 'animal_lean1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['lean'],
      'topVariant': ['fin'],
      'patternVariant': ['chevron'],
      'cheeksVariant': ['blushBig'],
      'eyesVariant': ['sideeye'],
      'mouthVariant': ['wavy'],
      'bodyColor': ['#5eead4'],
      'accentColor': ['#bef264'],
    },
  ),
  AvatarEntry(
    id: 'animal_peak1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['peak'],
      'topVariant': ['horns'],
      'patternVariant': ['belly'],
      'cheeksVariant': ['blush'],
      'eyesVariant': ['angry'],
      'mouthVariant': ['teeth'],
      'bodyColor': ['#fca5a5'],
      'accentColor': ['#fdba74'],
    },
  ),
  AvatarEntry(
    id: 'animal_wedge1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['wedge'],
      'topVariant': ['spike'],
      'patternVariant': ['dotRow'],
      'cheeksVariant': ['freckles'],
      'eyesVariant': ['sleepy'],
      'mouthVariant': ['line'],
      'bodyColor': ['#c4b5fd'],
      'accentColor': ['#f0abfc'],
    },
  ),
  AvatarEntry(
    id: 'animal_block1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['block'],
      'topVariant': ['nub'],
      'patternVariant': ['bar'],
      'cheeksVariant': ['blush'],
      'eyesVariant': ['dots'],
      'mouthVariant': ['dot'],
      'bodyColor': ['#6ee7b9'],
      'accentColor': ['#5eead4'],
    },
  ),
  AvatarEntry(
    id: 'animal_steps1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['steps'],
      'topVariant': ['sprout'],
      'patternVariant': ['dots'],
      'cheeksVariant': ['blushBig'],
      'eyesVariant': ['wink'],
      'mouthVariant': ['catMouth'],
      'bodyColor': ['#fda4af'],
      'accentColor': ['#f0abfc'],
    },
  ),
  AvatarEntry(
    id: 'animal_chimney1',
    style: AvatarStyle.critters,
    options: {
      'bodyVariant': ['chimney'],
      'topVariant': ['bobble'],
      'patternVariant': ['spot'],
      'cheeksVariant': ['blush'],
      'eyesVariant': ['mono'],
      'mouthVariant': ['tooth'],
      'bodyColor': ['#fdba74'],
      'accentColor': ['#fcd34d'],
    },
  ),
];
