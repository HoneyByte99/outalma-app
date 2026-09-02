import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/review/review_providers.dart';
import '../../application/user/public_profile_providers.dart';
import '../../domain/models/review.dart';
import '../shared/category_icon.dart';
import '../shared/user_avatar.dart';
import 'rating_summary.dart';
import '../../../l10n/app_localizations.dart';

/// Read-only view of the reviews a given user has received (client or provider).
/// Opened from the client summary on a booking so a provider can judge a client
/// before accepting, and reusable anywhere a reputation needs inspecting.
class UserReviewsPage extends ConsumerWidget {
  const UserReviewsPage({
    super.key,
    required this.userId,
    required this.source,
  });

  final String userId;

  /// Which reputation this page is showing. Carried by the route because the
  /// same screen is opened for a client from a booking and for a provider from
  /// a service listing, and it cannot tell them apart on its own.
  final RatingSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    // The public projection: this page is reachable without an account (it
    // opens from a public provider profile), and users/{uid} is gated on
    // signedIn().
    final user = ref.watch(publicProfileByIdProvider(userId)).valueOrNull;
    final reviewsAsync = ref.watch(reviewsForUserProvider(userId));

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(title: Text(user?.displayName ?? l10n.reviewsTitle)),
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.errorGeneral,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
              ),
              TextButton(
                onPressed: () => ref.invalidate(reviewsForUserProvider(userId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (reviews) {
          final sorted = [...reviews]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Aggregate reputation.
              Row(
                children: [
                  UserAvatar(
                    displayName: user?.displayName ?? '',
                    photoPath: user?.photoPath,
                    avatarId: user?.avatarId,
                    radius: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? '-',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        // explainBasis: this screen shows the list right
                        // underneath, so the header has to say what its number
                        // counts. Without it, "3 avis" sits above six tiles.
                        RatingSummary(
                          userId: userId,
                          source: source,
                          explainBasis: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      l10n.reviewsEmpty,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
                    ),
                  ),
                )
              else ...[
                // The list has its own title, so the two measures on this
                // screen are named rather than left to look like one another:
                // the header counts a filtered basis, this counts everything
                // received. Only in the data branch: loading and error replace
                // the whole body here, and hoisting the identity row out of the
                // `when` would change this screen's loading state, which is a
                // rework this lot does not carry.
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.reviewsAllReceived,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...sorted.map((r) => _ReviewTile(review: r)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    final reviewer = ref
        .watch(publicProfileByIdProvider(review.reviewerId))
        .valueOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reviewer?.displayName ?? '-',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: oc.star,
                  ),
                ),
              ),
            ],
          ),
          if (review.categoryId != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(review.categoryId!.icon, size: 13, color: oc.primary),
                const SizedBox(width: 4),
                Text(
                  review.categoryId!.labelOf(l10n),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: oc.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: oc.secondaryText,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
