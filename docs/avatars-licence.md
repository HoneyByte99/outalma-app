# Avatar catalogue: provenance and licence

The 40 SVG files in `assets/avatars/` are generated, not drawn by hand. This
records where they come from, because the provenance of a shipped asset should
be readable without digging through a plan.

Deliberately kept OUT of `assets/avatars/`: the asset declaration in
`pubspec.yaml` is per directory, so a licence file sitting in there would be
bundled into the APK for nothing.

## The two styles

| Style | Used for | Artist | Licence |
|---|---|---|---|
| Open Peeps | the 28 humans | [Pablo Stanley](https://www.openpeeps.com/) | **CC0 1.0** |
| Critters | the 12 animals | [DiceBear](https://www.dicebear.com) | **CC0 1.0** |

CC0 1.0 places the work in the public domain: copy, modify and distribute,
including commercially, without asking permission and without attribution. The
attribution above is therefore courtesy, not obligation.

Full licence text: <https://creativecommons.org/publicdomain/zero/1.0/>
Per-style licence table: <https://www.dicebear.com/licenses/>

## Why the files are generated locally and never fetched

DiceBear also runs a public HTTP API. It is **not** used, at build time or at
run time, and that is a licence decision rather than a technical one: their
documentation states the hosted API is free "for non-commercial purposes" and
directs commercial users to self-host. Outalma is a commercial marketplace.

The artwork itself is CC0 and unaffected by that restriction, so the route taken
is the one that owes nothing to anybody: generate the files once with the
MIT-licensed Dart library (`dicebear_core`, `dicebear_styles`, published by the
verified `dicebear.com` publisher on pub.dev), commit the output, and ship it.
No network call at run time, works offline, and nobody can change what a user's
avatar looks like after the fact.

## Why the provenance lives here and not inside the files

DiceBear embeds an RDF `<metadata>` block in every SVG, carrying the style name,
the artist and the CC0 notice. The generator strips it, for two reasons that are
not about licensing: it is 8 per cent of the raw catalogue (26.7 KB of 331.6 KB,
now 304.9 KB), and `flutter_svg` logs an "unhandled element <metadata/>" line
for it on EVERY parse, so it would also mean one log line per avatar rendered.

CC0 requires no attribution in the artifact, so nothing is owed. But provenance
that travels with the file is worth keeping SOMEWHERE, which is what this
document is for. The strip is deterministic, so regenerating still reproduces
the committed files byte for byte.

## Regenerating

```
cd tool/avatar_gen
dart pub get
dart run bin/generate.dart
```

`tool/avatar_gen/lib/manifest.dart` is the catalogue. See
`tool/avatar_gen/README.md` for what the generator refuses to do and why.
