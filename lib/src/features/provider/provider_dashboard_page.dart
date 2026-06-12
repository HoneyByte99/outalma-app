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
import '../../application/service/service_providers.dart';
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
    final profile = profileAsync.valueOrNull;
    // A profile may be auto-created when a service is published, but it isn't
    // "complete" until the provider has set their bio and (geocoded) service
    // area. We nudge — never block — until then.
    final profileComplete =
        profile != null &&
        (profile.bio?.trim().isNotEmpty ?? false) &&
        (profile.serviceArea?.trim().isNotEmpty ?? false);
    final servicesCount = servicesAsync.valueOrNull?.length ?? 0;
    final showFab = servicesCount > 0;

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

          // Providers are active by default — no blocking "activate" gate. We
          // always show the operational dashboard; profile completion (bio /
          // service area / working hours) is a non-blocking nudge.

          // No service yet : (nudge) + profile card + create-first-service CTA.
          if (servicesCount == 0)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (!profileComplete) const _CompleteProfileBanner(),
                  if (profile != null) _ProfileCard(profile: profile),
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
          // Has services : (nudge) + profile card + stats + services list.
          else ...[
            if (!profileComplete)
              const SliverToBoxAdapter(child: _CompleteProfileBanner()),
            if (profile != null)
              SliverToBoxAdapter(child: _ProfileCard(profile: profile)),
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
// Complete-profile nudge (non-blocking) — lazy onboarding
// ---------------------------------------------------------------------------

class _CompleteProfileBanner extends StatelessWidget {
  const _CompleteProfileBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: oc.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => GoRouter.of(context).push(AppRoutes.providerOnboarding),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: oc.warning, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dashboardCompleteProfileTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.dashboardCompleteProfileBody,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: oc.icons, size: 22),
              ],
            ),
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final formattedPrice = formatPriceFromCents(service.price);
    final priceLabel = service.priceType.name == 'hourly'
        ? '$formattedPrice/h'
        : '$formattedPrice (forfait)';
    // A rejected/pending service can't be toggled live by the provider — the
    // moderation flow governs it.
    final moderationLocked =
        service.status == 'rejected' || service.status == 'pending_review';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
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
                Flexible(
                  child: Text(
                    priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: oc.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: _CategoryChip(categoryId: service.categoryId)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only moderation states (pending/rejected) — the active/
                // inactive state is the toggle below.
                _ServiceStatusBadge(service: service),
                Icon(Icons.chevron_right_rounded, color: oc.icons, size: 20),
              ],
            ),
            onTap: () => context.push(AppRoutes.serviceEdit(service.id)),
          ),
          Divider(height: 1, color: oc.border, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
            child: Row(
              children: [
                // On/off shortcut — activate/deactivate without opening details.
                Switch(
                  value: service.published,
                  onChanged: moderationLocked
                      ? null
                      : (v) => _setPublished(context, ref, v),
                ),
                Text(
                  service.published ? l10n.serviceActive : l10n.serviceInactive,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: service.published ? oc.success : oc.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(l10n.serviceDelete),
                  style: TextButton.styleFrom(foregroundColor: oc.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setPublished(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(serviceRepositoryProvider)
          .update(
            service.copyWith(published: value, updatedAt: DateTime.now()),
          );
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.serviceFormSaveError),
            backgroundColor: oc.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.serviceDeleteTitle),
        content: Text(l10n.serviceDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.bookingBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.serviceDelete, style: TextStyle(color: oc.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(serviceRepositoryProvider).delete(service.id);
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.serviceDeleted)));
      }
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.serviceFormSaveError),
            backgroundColor: oc.error,
          ),
        );
      }
    }
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: oc.secondaryText),
      ),
    );
  }
}

/// Effective service state for the provider: combines the moderation [status]
/// (server-managed) with the [published] flag. Icon + colour so the state reads
/// without relying on text alone.
class _ServiceStatusBadge extends StatelessWidget {
  const _ServiceStatusBadge({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;

    // Only the moderation states need a badge — the live/offline state is shown
    // by the activate/deactivate toggle on the card.
    final (label, color, icon) = switch (service.status) {
      'rejected' => (l10n.serviceStatusRejected, oc.error, Icons.block_rounded),
      'pending_review' => (
        l10n.serviceStatusPending,
        oc.warning,
        Icons.hourglass_top_rounded,
      ),
      _ => (null, oc.secondaryText, Icons.circle),
    };
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
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
