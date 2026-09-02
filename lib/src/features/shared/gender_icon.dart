import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../domain/enums/gender.dart';

/// The declared gender of a provider, as a pictogram and nothing else.
///
/// No word beside it: that is the owner's decision, on the two surfaces where a
/// client is choosing (catalogue card, service detail). Both lines are already
/// contested (the provider's name has about forty pixels on a card at 375 px),
/// and a two-glyph icon says what "Homme"/"Femme" would say for a tenth of the
/// width. The word is still THERE for anyone who needs it, just not painted: a
/// [Semantics] label announces it to a screen reader, and a [Tooltip] prints it
/// on long press.
///
/// UNKNOWN RENDERS NOTHING. Not a neutral glyph, not a placeholder, not a
/// reserved slot: [SizedBox.shrink]. The 50 accounts that exist in production
/// today all predate this field, and a default pictogram would assert a gender
/// next to a real person's name on a page the whole internet can read. A wrong
/// pictogram is worse than no pictogram, so absence stays absence.
///
/// Glyph choice, [Icons.man] / [Icons.woman] rather than [Icons.male] /
/// [Icons.female]:
///
///  - The Mars and Venus symbols differ by a small appendage on the rim of a
///    shared circle (an arrow up-right, a cross below). At the 14 px this line
///    can spare, that appendage is about three pixels: the two glyphs collapse
///    to the same silhouette, and a client reading a grid at arm's length sees
///    one shape, not two.
///  - The human pictograms differ in the OUTLINE itself, straight legs against
///    a triangular skirt. A difference in the whole shape survives downscaling,
///    which is the property that matters here.
///  - It is the convention of public signage, readable without reading, which
///    is not a detail in a market where French literacy varies.
///
/// Rendered in [OutalmaColors.secondaryText], the colour of the name it sits
/// beside, deliberately NOT an accent: this is an attribute of a person, not a
/// trust signal, and it must not read as one next to the verified badge.
class GenderIcon extends StatelessWidget {
  const GenderIcon({super.key, required this.gender, this.size = 14});

  /// Null for every account created before the field existed. Renders nothing.
  final Gender? gender;

  final double size;

  @override
  Widget build(BuildContext context) {
    final value = gender;
    if (value == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;

    final (icon, label) = switch (value) {
      Gender.male => (Icons.man, l10n.genderMale),
      Gender.female => (Icons.woman, l10n.genderFemale),
    };

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        // The tooltip is a long-press affordance, not a second announcement.
        // Without this the screen reader reads the word twice in a row.
        excludeSemantics: true,
        child: Icon(icon, size: size, color: oc.secondaryText),
      ),
    );
  }
}
