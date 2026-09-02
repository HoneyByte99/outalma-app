# avatar_gen

Generates the 40 SVG files in `assets/avatars/` from DiceBear style
definitions. Development tooling: nothing under `lib/` of the app imports this
package, and `tool/**` is excluded from the app's analysis.

```
cd tool/avatar_gen
dart pub get
dart run bin/generate.dart            # writes ../../assets/avatars/
dart run bin/generate.dart --verbose  # plus the byte size of each file
dart run bin/dump_schema.dart critters   # authoritative option list of a style
```

Commit the SVGs it writes. `lib/manifest.dart` is the catalogue and the source
of truth for what the avatars are.

## A separate package, on purpose

Not a `dev_dependency` of the app. `dicebear_core` pulls `dicebear_schema` and
`json_schema`; a dev_dependency shares the app's resolution, so one constraint
conflict would block `flutter pub get` for everyone and for CI, over a package
the app never needs once the SVGs are committed. Isolating it also keeps the
9.7 MB of `dicebear_styles` out of every `pub get`, and makes it structurally
impossible for a file under `lib/` to import a package this young.

## What it refuses to do

The generator writes nothing unless all of the following hold. Each guard is
here because its absence is silent.

**1. Resolved options must equal the intent.** Since DiceBear 10 a component
option is suffixed `Variant`. Writing `head:` instead of `headVariant:` is
accepted, ignored **in silence**, and leaves the component to the seeded draw:
40 random avatars, no exception, no failing test. A guard on key NAMES would
pass that happily, because `head` is a legal component name. So the generator
compares what DiceBear actually resolved (`Avatar.resolvedOptions`) against what
the manifest asked for, which a wrong suffix cannot pass.

Shapes worth knowing before reading that code, all verified on the package: a
`*Variant` resolves to a bare string, a `*Color` resolves to a LIST, a
`*Probability` does not appear at all, and a `*Color` resolves to `null` when the
chosen component does not reference it. `afro`, for one, ignores
`headContrastColor` and draws its hair with the ink colour.

**2. The three elders really have grey hair.** `headContrastColor` is the hair
colour and only `#e8e1e1` of its ten palette values reads grey. Unpinned, an
elder comes out brown-haired nine times out of ten and the category vanishes
without a word, so the colour is asserted to have REACHED the drawing.

**3. The skin sentinel covers all the skin, proven differentially.** Each human
is rendered twice with two different sentinel colours and the outputs must be
identical once the token is substituted. "The sentinel appears at least once"
would not prove it covers ALL the skin and would miss a derived shade. This also
catches a sentinel colliding with a colour the drawing already uses. It works
because `<defs>` ids are hashed from style plus seed rather than random
(`idRandomization` is false).

Known limit, so nobody over-trusts it: this proves nothing DRIFTS, not that
every skin-looking area is sentinel-driven. A face filled with a baked colour
would be identical in both renders and pass. What actually establishes coverage
is substituting the sentinel for a loud colour once and looking.

**4. Nothing remote, nothing animated, counts exact.** No `<image`,
`xlink:href`, `url(http` or `<animate` (flutter_svg ignores SMIL, so an animated
file would render differently from the reference without a word), and exactly
28 humans and 12 animals with ids matching the catalogue grammar.

## What it strips

The RDF `<metadata>` block DiceBear embeds: 8 per cent of the raw catalogue and
one "unhandled element" log line per parse in flutter_svg. Deterministic, so
regeneration is still byte-reproducible. Provenance is recorded in
`docs/avatars-licence.md` instead, and CC0 owes no attribution in the artifact.

Note for whoever touches this: the differential proof compares the two sentinel
renders, so BOTH must be stripped the same way. Stripping only the shipped one
makes all 28 humans fail with "some skin is NOT carried by skinColor", which is
a lie about the assets and cost one debugging round.

## One trap when eyeballing the output

Do not inline the SAME avatar twice in one SVG document to compare two skin
tones side by side. Open Peeps uses `<defs>` plus `<use>`, ids are deterministic
per style and seed, so the second copy resolves its `<use>` references against
the FIRST copy's definitions: the face silently comes out identical in both and
you conclude the recolouring is broken when it is not. Render each tone as its
own file. This cost a wrong diagnosis once already.
