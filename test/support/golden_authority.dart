/// One authority for golden bytes: the CI runner.
///
/// The nine goldens in this repo were generated on macOS and compared for the
/// first time on `ubuntu-latest`, where they failed with pixel diffs of 1.5 to
/// 3 per cent. That is font rasterisation, not a regression, but it is also
/// exactly the SIZE of a real visual regression, so the two cannot be told
/// apart by widening a comparison tolerance: a threshold big enough to absorb
/// the platform difference would let a genuine one through, and the golden
/// suite would become decorative.
///
/// So the bytes committed are the RUNNER's, produced on `ubuntu-latest` with
/// the Flutter version pinned in `.github/workflows/ci.yml`, and the comparison
/// runs only where they were produced.
///
/// The opposite arrangement was considered and rejected: keeping the macOS
/// bytes and skipping the comparison in CI. A test that never runs in CI is not
/// a guard, it is a comment.
///
/// To regenerate after an INTENTIONAL visual change, let the runner do it. Do
/// not run `flutter test --update-goldens` on a Mac: that replaces the runner's
/// bytes with local ones, and every golden goes red on the next push.
library;

import 'dart:io' show Platform;

/// Pass as `skip:` on a golden comparison.
///
/// FALSE on Linux, so the comparison really runs in CI, which is the whole
/// point. True anywhere else, because the committed bytes are not this
/// platform's.
///
/// A `bool` and not a reason string: `testWidgets` types its `skip` as `bool?`,
/// unlike `test`, so the explanation lives in this library's doc instead of in
/// the runner output.
final bool goldenSkip = !Platform.isLinux;
