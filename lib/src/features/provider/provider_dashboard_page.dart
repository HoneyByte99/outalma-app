import '../shared/network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_shell.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/provider/provider_providers.dart';
import '../../core/utils/format_utils.dart';
import '../shared/mode_badge.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/models/provider_profile.dart';
import '../shared/category_icon.dart';
import '../../domain/models/service.dart';

class ProviderDashboardPage extends ConsumerWidget {
  const ProviderDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final profileAsync = ref.watch(currentProviderProfileProvider);
    final servicesAsync = ref.watch(providerServicesProvider);

    // Resolve the dashboard state with explicit priority: profile setup
    // first, then "create first service" if there are none, then the normal
    // services dashboard. Only the screen for the current state shows a
    // strong CTA — no competing primary actions (security review A.3).
    final hasProfile = profileAsync.valueOrNull != null;
    final servicesCount = servicesAsync.valueOrNull?.length ?? 0;
    final showFab = hasProfile && servicesCount > 0;

    return Scaffold(
      backgroundColor: oc.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: oc.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              l10n.dashboardTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            actions: const [ModeBadge(), BellIconButton(), SizedBox(width: 4)],
          ),

          // State 1 — no profile yet : full-bleed onboarding, only CTA.
          if (!hasProfile)
            SliverFillRemaining(
              hasScrollBody: false,
              child: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    _ErrorState(message: l10n.dashboardServicesError),
                data: (_) => _OnboardingBanner(),
              ),
            )
          // State 2 — profile OK but no service : compact profile card +
          // single dominant CTA to create the first service.
          else if (servicesCount == 0)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _ProfileCard(profile: profileAsync.value!),
                  servicesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, __) =>
                        _ErrorState(message: l10n.dashboardServicesError),
                    data: (_) => const _EmptyServices(),
                  ),
                ],
              ),
            )
          // State 3 — profile + services : normal dashboard.
          else ...[
            SliverToBoxAdapter(
              child: _ProfileCard(profile: profileAsync.value!),
            ),
            const SliverToBoxAdapter(child: _ProviderStatsRow()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.s,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.dashboardMyServices,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) =>
                      _ServiceTile(service: servicesAsync.value![i]),
                  childCount: servicesCount,
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.serviceNew),
              backgroundColor: oc.primary,
              tooltip: l10n.dashboardAdd,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding banner
// ---------------------------------------------------------------------------

class _OnboardingBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: oc.border),
          boxShadow: [
            BoxShadow(
              color: oc.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: oc.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_open_rounded,
                    color: oc.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dashboardActivateTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: oc.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.dashboardActivateBody,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  GoRouter.of(context).push(AppRoutes.providerOnboarding),
              style: ElevatedButton.styleFrom(
                backgroundColor: oc.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(l10n.dashboardActivateButton),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile card
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final ProviderProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: oc.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: oc.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_outlined, color: oc.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.active ? l10n.profileActive : l10n.profileInactive,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: profile.active ? oc.success : oc.secondaryText,
                    ),
                  ),
                  if (profile.serviceArea != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: oc.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            profile.serviceArea!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: oc.secondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: oc.secondaryText,
              ),
              onPressed: () =>
                  GoRouter.of(context).push(AppRoutes.providerOnboarding),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service tile
// ---------------------------------------------------------------------------

class _ServiceTile extends ConsumerWidget {
  const _ServiceTile({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final formattedPrice = formatPriceFromCents(service.price);
    final priceLabel = service.priceType.name == 'hourly'
        ? '$formattedPrice/h'
        : '$formattedPrice (forfait)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: oc.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 52,
            height: 52,
            child: service.photos.isNotEmpty
                ? AppNetworkImage(
                    url: service.photos.first,
                    fit: BoxFit.cover,
                    errorWidget: _iconFallback(oc),
                  )
                : _iconFallback(oc),
          ),
        ),
        title: Text(
          service.title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              priceLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: oc.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            _CategoryChip(categoryId: service.categoryId),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PublishedBadge(published: service.published),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: oc.icons, size: 20),
          ],
        ),
        onTap: () => context.push(AppRoutes.serviceEdit(service.id)),
      ),
    );
  }

  Widget _iconFallback(OutalmaColors oc) {
    return ColoredBox(
      color: oc.primary.withValues(alpha: 0.08),
      child: Icon(
        _categoryIcon(service.categoryId),
        size: 22,
        color: oc.primary,
      ),
    );
  }

  IconData _categoryIcon(CategoryId categoryId) => categoryId.icon;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.categoryId});

  final CategoryId categoryId;

  static Map<CategoryId, String> get _labels => {
    for (final c in CategoryId.values) c: c.label,
  };

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: oc.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _labels[categoryId] ?? '',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: oc.secondaryText),
      ),
    );
  }
}

class _PublishedBadge extends StatelessWidget {
  const _PublishedBadge({required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final label = published ? l10n.published : l10n.notPublished;
    final color = published ? oc.success : oc.secondaryText;
    final bg = published
        ? oc.success.withValues(alpha: 0.12)
        : oc.border.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + error states
// ---------------------------------------------------------------------------

class _EmptyServices extends StatelessWidget {
  const _EmptyServices();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.add_box_outlined, size: 56, color: oc.icons),
            const SizedBox(height: 16),
            Text(
              l10n.serviceEmptyTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.serviceEmptyBody,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => GoRouter.of(context).push(AppRoutes.serviceNew),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.serviceCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined, size: 40, color: oc.icons),
            const SizedBox(height: AppSpacing.m),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: oc.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.m),
            TextButton(
              onPressed: () {
                ref.invalidate(currentProviderProfileProvider);
                ref.invalidate(providerServicesProvider);
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider stats row (B.5) — KPIs for the provider dashboard.
// ---------------------------------------------------------------------------

class _ProviderStatsRow extends ConsumerWidget {
  const _ProviderStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final stats = ref.watch(providerStatsProvider);

    String acceptanceLabel() {
      final r = stats.acceptanceRate;
      if (r == null) return '—';
      return '${(r * 100).round()}%';
    }

    Widget tile({
      required IconData icon,
      required String value,
      required String label,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: oc.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: oc.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: oc.primary),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          tile(
            icon: Icons.event_available_rounded,
            value: '${stats.upcomingThisWeek}',
            label: l10n.dashboardStatsUpcomingWeek,
          ),
          const SizedBox(width: AppSpacing.s),
          tile(
            icon: Icons.calendar_today_outlined,
            value: '${stats.bookingsThisMonth}',
            label: l10n.dashboardStatsThisMonth,
          ),
          const SizedBox(width: AppSpacing.s),
          tile(
            icon: Icons.check_circle_outline_rounded,
            value: acceptanceLabel(),
            label: l10n.dashboardStatsAcceptanceRate,
          ),
        ],
      ),
    );
  }
}
