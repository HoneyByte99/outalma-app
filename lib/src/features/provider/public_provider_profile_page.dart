import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../shared/network_image.dart';
import '../shared/verified_badge.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/review/review_providers.dart';
import '../../application/user/user_providers.dart';
import '../../core/utils/format_utils.dart';
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
    final userAsync = ref.watch(userByIdProvider(providerId));
    final reviewsAsync = ref.watch(reviewsForUserProvider(providerId));
    final servicesAsync = ref.watch(publicProviderServicesProvider(providerId));

    // The page hinges on the USER document. The providers/{uid} doc is optional
    // (it only adds bio / serviceArea / verified badge). While the user doc is
    // still loading we show a spinner; if it resolves to null the provider does
    // not exist and we show a graceful unavailable state.
    if (userAsync.isLoading && !userAsync.hasValue) {
      return Scaffold(
        backgroundColor: oc.background,
        appBar: AppBar(backgroundColor: oc.surface),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (userAsync.valueOrNull == null) {
      return Scaffold(
        backgroundColor: oc.background,
        appBar: AppBar(backgroundColor: oc.surface),
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
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: oc.surface,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: oc.surface.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: oc.primaryText,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _ProfileHeader(
                providerId: providerId,
                reviewsAsync: reviewsAsync,
              ),
            ),
          ),

          // ---- Reviews ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                l10n.reviewsLabel,
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
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
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
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
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

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.providerId, required this.reviewsAsync});

  final String providerId;
  final AsyncValue<List<Review>> reviewsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final user = ref.watch(userByIdProvider(providerId)).valueOrNull;
    final providerProfile = ref
        .watch(providerProfileByIdProvider(providerId))
        .valueOrNull;
    final reviews = reviewsAsync.valueOrNull ?? [];
    final avgRating = reviews.isEmpty
        ? null
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    // A.8 - trust signal: a provider is "verified" once they have completed
    // their onboarding (profile exists) AND have a verified phone number on
    // file (phoneE164 set, which only happens through Twilio OTP or
    // sign-up).
    final isVerified =
        providerProfile != null && (user?.phoneE164?.isNotEmpty ?? false);

    return Container(
      color: oc.cardSurface,
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          UserAvatar(
            displayName: user?.displayName ?? '',
            photoPath: user?.photoPath,
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
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (avgRating != null) ...[
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 16,
                          color: context.oc.star,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${avgRating.toStringAsFixed(1)} (${reviews.length})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (user?.country != null && user!.country.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: oc.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        CountryUtils.flagAndName(user.country),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
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
    final reviewer = ref.watch(userByIdProvider(review.reviewerId)).valueOrNull;

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
                  review.categoryId!.label,
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
    final formattedPrice = formatPriceFromCents(service.price);
    final priceLabel = service.priceType.name == 'hourly'
        ? '$formattedPrice/h'
        : formattedPrice;

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
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
          ),
        ],
      ),
    );
  }
}
