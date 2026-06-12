import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/review/review_providers.dart';
import '../../../l10n/app_localizations.dart';

/// Compact, read-only trust signal: average rating + review count for a user.
/// Shows a neutral "New" label when the user has no reviews yet. Used to
/// surface a client's reputation to the provider (incoming requests + booking
/// detail) without exposing a full client profile.
class RatingSummary extends ConsumerWidget {
  const RatingSummary({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final stats = ref.watch(ratingSummaryProvider(userId)).valueOrNull;
    if (stats == null) return const SizedBox.shrink();

    if (stats.count == 0) {
      return Text(
        l10n.ratingNew,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: oc.secondaryText,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 15, color: oc.star),
        const SizedBox(width: 3),
        Text(
          stats.average.toStringAsFixed(1),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(
          l10n.reviewsCount(stats.count),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
        ),
      ],
    );
  }
}
