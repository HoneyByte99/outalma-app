import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/review/review_providers.dart';
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
class RatingSummary extends ConsumerWidget {
  const RatingSummary({super.key, required this.userId, required this.source});

  final String userId;
  final RatingSource source;

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
      // No reviews yet — keep a star shape (outlined) so non-readers still
      // recognise this as a rating slot, paired with the localized label.
      return Semantics(
        label: l10n.ratingNew,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded, size: 15, color: oc.secondaryText),
            const SizedBox(width: 3),
            Text(
              l10n.ratingNew,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: oc.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final average = stats.average!;
    final countLabel = stats.count >= kClientReputationWindow
        ? '$kClientReputationWindow+'
        : l10n.reviewsCount(stats.count);

    return Semantics(
      label: '${average.toStringAsFixed(1)} $countLabel',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 15, color: oc.star),
          const SizedBox(width: 3),
          Text(
            average.toStringAsFixed(1),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Text(
            countLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
          ),
        ],
      ),
    );
  }
}
