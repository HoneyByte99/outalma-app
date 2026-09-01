import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/review/review_providers.dart';
import '../../domain/review/rating_display.dart';
import '../../../l10n/app_localizations.dart';

/// Which reputation a surface is showing. There is no default on purpose.
///
/// The same widget serves two different things, and no call site can guess
/// which: a PROVIDER's public rating comes from the server-owned aggregate,
/// while a CLIENT's reputation is derived from their recent reviews. Reading
/// the aggregate for a client would show "Nouveau" for every client for ever,
/// since no aggregate is ever written for them.
enum RatingSource { provider, client }

/// Compact, read-only trust signal: average rating + review count for a user.
/// Shows a neutral "New" label below the review floor.
///
/// MUST be mounted inside a BOUNDED width. Both branches carry a `Flexible`, so
/// an unbounded incoming width (a column of a `Row` with no `Expanded`, a
/// horizontal list) raises "RenderFlex children have non-zero flex but incoming
/// width constraints are unbounded". Every current call site sits under an
/// `Expanded`; the older code merely overflowed there, this one asserts.
class RatingSummary extends ConsumerWidget {
  const RatingSummary({
    super.key,
    required this.userId,
    required this.source,
    this.explainBasis = false,
  });

  final String userId;
  final RatingSource source;

  /// Say what the number is computed FROM, not just what it is.
  ///
  /// The two measures on these screens genuinely differ: a provider's public
  /// rating counts only reviews written by the client of a completed booking,
  /// while the list underneath shows every review received, in both roles.
  /// Left unnamed, the screen reads as a contradiction a user can falsify by
  /// counting: "3 avis" above six tiles, or "Nouveau" above five four- and
  /// five-star reviews.
  ///
  /// Turn it on wherever the floor can be read as a judgement with no
  /// explanation: the two surfaces that show a list below, and the provider's
  /// own dashboard. The card and the service detail keep the short form, where
  /// space is counted and the reader compares offers rather than judging one
  /// reputation in isolation.
  final bool explainBasis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final async = switch (source) {
      RatingSource.provider => ref.watch(providerRatingProvider(userId)),
      RatingSource.client => ref.watch(clientReputationProvider(userId)),
    };
    // Unresolved reads say nothing: claiming "Nouveau" while the read is in
    // flight would flash a false statement about a real person on every scroll.
    if (!async.hasValue) return const SizedBox.shrink();
    final stats = async.value!;

    if (stats.isNew) {
      // No reviews yet: keep a star shape (outlined) so non-readers still
      // recognise this as a rating slot, paired with the localized label.
      //
      // This is the MAJORITY case on the current catalogue: 13 of the 15 rated
      // providers sit below the floor, so the branch that needs the explanation
      // most is this one, not the resolved one.
      final floorHint = explainBasis
          ? (source == RatingSource.provider
                // Two values, not one: on a provider the basis is specifically
                // the reviews written by clients; on a client it is every review
                // received, which IS what the list below shows.
                ? l10n.ratingFloorHintClients(kMinReviewsForAverage)
                : l10n.ratingFloorHint(kMinReviewsForAverage))
          : null;

      return Semantics(
        label: floorHint == null
            ? l10n.ratingNew
            : '${l10n.ratingNew} $floorHint',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded, size: 15, color: oc.secondaryText),
            const SizedBox(width: 3),
            // Standalone Text on purpose: the four surfaces show the same word
            // for the same uid, and two existing tests match it exactly.
            Text(
              l10n.ratingNew,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: oc.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (floorHint != null) ...[
              const SizedBox(width: 4),
              // Flexible, because a Row child that is not flexible receives
              // maxWidth: infinity and overflows to the RIGHT instead of
              // wrapping. The header column of the public profile is 227 px at
              // 375 px, less than this label needs at a 200% text scale.
              Flexible(
                child: Text(
                  floorHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final average = stats.average!;
    // The cap belongs to the client WINDOW only. A provider count comes from
    // the exact server aggregate, and showing "50+" here while the card and
    // the service detail show "(60)" would be the cross-surface disagreement
    // this increment exists to close.
    final countLabel =
        source == RatingSource.client && stats.count >= kClientReputationWindow
        ? '$kClientReputationWindow+'
        : l10n.reviewsCount(stats.count);

    // Above the floor, only a provider needs its basis named: a client's
    // reputation is derived from the very list shown underneath, so the header
    // and the list already agree there.
    final trailing = explainBasis && source == RatingSource.provider
        ? l10n.ratingFromClients(stats.count)
        : countLabel;

    return Semantics(
      label: '${average.toStringAsFixed(1)} $trailing',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 15, color: oc.star),
          const SizedBox(width: 3),
          // Standalone, and never concatenated with the basis: two existing
          // tests match this exact string.
          Text(
            average.toStringAsFixed(1),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              trailing,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
