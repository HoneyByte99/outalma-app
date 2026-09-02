import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../shared/network_image.dart';
import '../shared/identity_trust_signal.dart';
import '../review/rating_summary.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/review/review_providers.dart';
import '../../application/user/public_profile_providers.dart';
import '../shared/service_price_label.dart';
import '../../domain/models/review.dart';
import '../../domain/models/service.dart';
import '../shared/category_icon.dart';
import '../../domain/utils/country_utils.dart';
import '../shared/user_avatar.dart';

class PublicProviderProfilePage extends ConsumerWidget {
  const PublicProviderProfilePage({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final userAsync = ref.watch(publicProfileByIdProvider(providerId));
    final reviewsAsync = ref.watch(reviewsForUserProvider(providerId));
    final servicesAsync = ref.watch(publicProviderServicesProvider(providerId));

    // The page hinges on the PUBLIC PROJECTION, not on users/{uid}: it is
    // reachable without an account and `users` is gated on signedIn(), which
    // made the whole screen resolve to "provider unavailable" for a visitor.
    // The providers/{uid} doc stays optional (it only adds the bio). While the
    // projection is still loading we show a spinner; if it resolves to null the
    // provider does not exist and we show a graceful unavailable state.
    if (userAsync.isLoading && !userAsync.hasValue) {
      return Scaffold(
        backgroundColor: oc.background,
        appBar: AppBar(backgroundColor: oc.cardSurface),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (userAsync.valueOrNull == null) {
      return Scaffold(
        backgroundColor: oc.background,
        appBar: AppBar(backgroundColor: oc.cardSurface),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 56, color: oc.icons),
              const SizedBox(height: 16),
              Text(
                l10n.providerProfileUnavailable,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: oc.background,
      body: CustomScrollView(
        slivers: [
          // The header used to live in a FlexibleSpaceBar under a fixed
          // expandedHeight of 200, and it overflowed the moment a provider's
          // bio ran to three lines: the yellow "BOTTOM OVERFLOWED" banner was
          // visible on the real app. Growing the fixed height only postpones
          // the same trap, and clipping the bio cuts the text a provider sells
          // themselves with, so the header now sizes to its own content and
          // survives a 200% text scale (budget line A6).
          SliverAppBar(
            pinned: true,
            // cardSurface, NOT surface: the two are the same white in light
            // mode but differ in dark (#1A2029 against #1F252F), and the
            // FlexibleSpaceBar used to hide that. Without this a band appears
            // between the bar and the header in dark mode.
            backgroundColor: oc.cardSurface,
            // AppTheme.light() sets no surfaceTintColor, unlike dark(), so M3
            // would tint the bar on scroll now that nothing covers it.
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            // No title on purpose. Without a flexibleSpace a pinned title is
            // visible AT REST, 56 px above the same name in the header: the lot
            // would fix one rendering defect by introducing a duplicated name
            // on the screen where a client decides. A pinned bar carrying only
            // a back button is ordinary mobile behaviour; driving the title
            // from scroll offset is the complete answer and the complexity the
            // MVP rule declines.
            leading: const BackButton(),
          ),
          SliverToBoxAdapter(child: ProfileHeader(providerId: providerId)),

          // ---- Reviews ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              // The label varies, the title itself is always rendered: making
              // it conditional would leave the empty and error states floating
              // with no heading just above "Services proposes". "Tous les avis
              // recus" says the list counts something other than the header.
              child: Text(
                (reviewsAsync.valueOrNull?.isNotEmpty ?? false)
                    ? l10n.reviewsAllReceived
                    : l10n.reviewsLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),

          reviewsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: _ErrorSection(
                label: l10n.errorGeneral,
                retryLabel: l10n.retry,
                onRetry: () =>
                    ref.invalidate(reviewsForUserProvider(providerId)),
              ),
            ),
            data: (reviews) => reviews.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptySection(
                      icon: Icons.star_outline_rounded,
                      label: l10n.reviewsEmpty,
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _ReviewTile(review: reviews[i]),
                        childCount: reviews.length,
                      ),
                    ),
                  ),
          ),

          // ---- Services ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                l10n.servicesOffered,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),

          servicesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: _ErrorSection(
                label: l10n.errorGeneral,
                retryLabel: l10n.retry,
                onRetry: () =>
                    ref.invalidate(publicProviderServicesProvider(providerId)),
              ),
            ),
            data: (services) => services.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptySection(
                      icon: Icons.work_outline_rounded,
                      label: l10n.serviceEmptyTitle,
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _PublicServiceTile(service: services[i]),
                        childCount: services.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile header
// ---------------------------------------------------------------------------

@visibleForTesting
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final user = ref.watch(publicProfileByIdProvider(providerId)).valueOrNull;
    final providerProfile = ref
        .watch(providerProfileByIdProvider(providerId))
        .valueOrNull;
    // D6-a/E7: the trust badge reflects a server-owned identity verdict,
    // rendered by IdentityTrustSignal below (no client-side phone heuristic).

    return Container(
      color: oc.cardSurface,
      // 20 at the top, not 80: the 80 existed only to clear the app bar the
      // header used to sit behind. It sits below it now.
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        // start, not center: at a variable height, an avatar centred against a
        // four-line bio floats far from the name it belongs to.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            displayName: user?.displayName ?? '',
            photoPath: user?.photoPath,
            avatarId: user?.avatarId,
            radius: 40,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user?.displayName ?? '-',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Inline beside the name, like the service detail, and no
                    // longer a full pill on its own line. The comment that used
                    // to justify the dedicated line was about the PILL, which
                    // carries text and would eat the name at 375 px; a 15 px
                    // badge read together with the name does not.
                    //
                    // Renders ONLY for a verified provider. This is a client
                    // surface, so it makes no claim about anyone else: it drops
                    // the sentence "Identite non verifiee", which taught every
                    // client that nobody here is trustworthy, and it no longer
                    // leaves a muted glyph in its place either.
                    IdentityTrustSignal(
                      providerId: providerId,
                      style: TrustSignalStyle.badge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // One display rule, in one place. This header used to compute
                // its own five-star row, which is how it once showed "5.0 (2)"
                // while the card said "Nouveau". explainBasis because the list
                // of every review received sits right below.
                RatingSummary(
                  userId: providerId,
                  source: RatingSource.provider,
                  explainBasis: true,
                ),
                const SizedBox(height: 4),
                // Nullable on the projection, unlike AppUser.country which
                // defaults to 'FR': the public document omits the field when
                // the user declared no country, so a flag is shown only when
                // there is one to show rather than defaulted to France.
                if (user?.country != null && user!.country!.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: oc.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      // Flexible: a Row child that is not flexible receives
                      // maxWidth: infinity and overflows to the RIGHT rather
                      // than wrapping. "Emirats arabes unis" exceeds the 227 px
                      // this column gets at 375 px once the text scale rises.
                      Flexible(
                        child: Text(
                          CountryUtils.flagAndName(user.country!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: oc.secondaryText),
                        ),
                      ),
                    ],
                  ),
                if (providerProfile?.bio?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    providerProfile!.bio!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: oc.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review tile
// ---------------------------------------------------------------------------

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    // The reviewer is resolved from the public projection too. A reviewer is
    // usually a CLIENT, not a provider, so providers/{uid} could never have
    // named them even if it carried a display name.
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
              UserAvatar(
                displayName: reviewer?.displayName ?? '',
                photoPath: reviewer?.photoPath,
                avatarId: reviewer?.avatarId,
                radius: 16,
              ),
              const SizedBox(width: 10),
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
                    color: context.oc.star,
                  ),
                ),
              ),
            ],
          ),
          // Which service category this rating concerns (context: a provider
          // may be strong in one category and weak in another).
          if (review.categoryId != null) ...[
            const SizedBox(height: 8),
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

// ---------------------------------------------------------------------------
// Service tile
// ---------------------------------------------------------------------------

class _PublicServiceTile extends StatelessWidget {
  const _PublicServiceTile({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    final priceLabel = servicePriceLabel(service, l10n);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.serviceDetail(service.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: oc.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: SizedBox(
                width: 80,
                height: 80,
                child: service.photos.isNotEmpty
                    ? AppNetworkImage(
                        url: service.photos.first,
                        fit: BoxFit.cover,
                        errorWidget: _iconFallback(oc),
                      )
                    : _iconFallback(oc),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: oc.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: oc.icons,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback(OutalmaColors oc) {
    return ColoredBox(
      color: oc.primary.withValues(alpha: 0.08),
      child: Icon(
        Icons.work_outline_rounded,
        size: 28,
        color: oc.primary.withValues(alpha: 0.4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty section placeholder
// ---------------------------------------------------------------------------

/// A network error inside a profile section, distinct from an empty section: a
/// short line plus a retry, so a load failure never reads as "no reviews" or "no
/// services" (aligned with the home and chat error states).
class _ErrorSection extends StatelessWidget {
  const _ErrorSection({
    required this.label,
    required this.retryLabel,
    required this.onRetry,
  });

  final String label;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: oc.icons),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: oc.icons),
          const SizedBox(width: 10),
          // Expanded, like _ErrorSection just above already had. Without it
          // "Aucun avis recu pour le moment" overflows about 83 px to the RIGHT
          // at 375 px, which is a real defect on a phone at a raised text scale
          // AND the reason an overflow regression test on this page could never
          // reach green: viewport slivers paint last-to-first, so this error was
          // reported before the header's and takeException() returns only the
          // first one.
          Expanded(
            child: Text(
              label,
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
