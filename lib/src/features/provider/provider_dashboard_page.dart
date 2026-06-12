import '../shared/network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_shell.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/service/service_providers.dart';
import '../../core/utils/format_utils.dart';
import '../review/rating_summary.dart';
import '../shared/mode_badge.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/models/provider_profile.dart';
import '../shared/category_icon.dart';
import '../shared/user_avatar.dart';
import '../shared/verified_badge.dart';
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
    // Every provider is available by default. The hub card carries a self-
    // service availability toggle (Disponible/En pause) that hides the whole
    // catalogue at once; per-listing on/off lives on each service tile. Profile
    // details (bio / working hours) are edited via the hub's edit pencil.
    final profile = profileAsync.valueOrNull;
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

          // Operational dashboard. No service yet : profile card +
          // create-first-service CTA.
          if (servicesCount == 0)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (profile != null) _ProviderHubCard(profile: profile),
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
          // Has services : profile card + stats + services list.
          else ...[
            if (profile != null)
              SliverToBoxAdapter(child: _ProviderHubCard(profile: profile)),
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
                  (context, i) => _ServiceTile(
                    service: servicesAsync.value![i],
                    // When the provider is paused, every listing is hidden from
                    // clients regardless of its own published flag — reflect
                    // that on the tile so the hub/listing hierarchy is clear.
                    providerPaused: profile != null && !profile.active,
                  ),
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
// Profile card
// ---------------------------------------------------------------------------

/// "Mon activité" — the provider hub. Identity row (avatar + name + verified +
/// rating + edit) over an availability control: a pill toggle distinct from the
/// per-listing switches below. "Disponible" → listings visible & bookable;
/// "En pause" → the whole catalogue is hidden (non-destructive, instant resume).
class _ProviderHubCard extends ConsumerStatefulWidget {
  const _ProviderHubCard({required this.profile});

  final ProviderProfile profile;

  @override
  ConsumerState<_ProviderHubCard> createState() => _ProviderHubCardState();
}

class _ProviderHubCardState extends ConsumerState<_ProviderHubCard> {
  /// Optimistic availability — reflects the tap immediately, reverts on error.
  bool? _pending;

  @override
  void didUpdateWidget(covariant _ProviderHubCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pending != null && widget.profile.active == _pending) _pending = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;

    final available = _pending ?? widget.profile.active;
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final appUser = auth is AuthAuthenticated ? auth.user : null;
    final isVerified = appUser?.phoneE164?.isNotEmpty ?? false;
    final publishedCount =
        ref
            .watch(providerServicesProvider)
            .valueOrNull
            ?.where((s) => s.published)
            .length ??
        0;
    // Toggling "Disponible" only makes sense once at least one listing is live.
    final canToggle = publishedCount > 0;
    final accent = available ? oc.success : oc.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          // Top-edge accent encodes the state before any text is read.
          border: Border(
            top: BorderSide(color: canToggle ? accent : oc.border, width: 3),
            left: BorderSide(color: oc.border),
            right: BorderSide(color: oc.border),
            bottom: BorderSide(color: oc.border),
          ),
        ),
        child: Column(
          children: [
            // Row 1 — identity
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              child: Row(
                children: [
                  UserAvatar(
                    displayName: appUser?.displayName ?? '',
                    photoPath: appUser?.photoPath,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                (appUser?.displayName.isNotEmpty ?? false)
                                    ? appUser!.displayName
                                    : l10n.hubFallbackName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
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
                        const SizedBox(height: 2),
                        RatingSummary(userId: widget.profile.uid),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: oc.secondaryText,
                    ),
                    tooltip: l10n.hubEditProfile,
                    onPressed: () =>
                        GoRouter.of(context).push(AppRoutes.providerOnboarding),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: oc.border),
            // Row 2 — availability (the whole row is the tap target)
            Semantics(
              button: canToggle,
              label: available ? l10n.hubSemanticsOn : l10n.hubSemanticsOff,
              child: InkWell(
                onTap: canToggle
                    ? () => _onToggle(available, publishedCount)
                    : null,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_rounded,
                        size: 22,
                        color: canToggle ? accent : oc.secondaryText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              available ? l10n.hubAvailable : l10n.hubPaused,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: canToggle
                                        ? accent
                                        : oc.secondaryText,
                                  ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              canToggle
                                  ? (available
                                        ? l10n.hubAvailableSub
                                        : l10n.hubPausedSub)
                                  : l10n.hubNoServicesHint,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: oc.secondaryText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AvailabilityPill(
                        available: available,
                        enabled: canToggle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onToggle(bool currentlyAvailable, int publishedCount) async {
    if (currentlyAvailable) {
      final confirmed = await _showPauseSheet(publishedCount);
      if (confirmed != true) return;
      await _apply(false);
    } else {
      await _apply(true);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final oc = context.oc;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.hubResumed)),
              ],
            ),
            backgroundColor: oc.success,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _apply(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending = value);
    try {
      await ref
          .read(providerRepositoryProvider)
          .setActive(widget.profile.uid, value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending = null);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.hubToggleError), backgroundColor: oc.error),
      );
    }
  }

  Future<bool?> _showPauseSheet(int count) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded, size: 48, color: oc.warning),
              const SizedBox(height: 16),
              Text(
                l10n.hubPauseTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                count > 0 ? l10n.hubPauseBody(count) : l10n.hubPauseBodyNoCount,
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oc.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.hubPauseCta),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom availability pill — deliberately NOT a [Switch], so a provider never
/// confuses this whole-account control with the per-listing switches below.
class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.available, required this.enabled});

  final bool available;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final track = !enabled
        ? oc.border
        : available
        ? oc.success
        : oc.warning.withValues(alpha: 0.28);
    return Container(
      width: 72,
      height: 36,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(18),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        alignment: available ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              available ? Icons.storefront_rounded : Icons.pause_rounded,
              size: 16,
              color: !enabled
                  ? oc.secondaryText
                  : available
                  ? oc.success
                  : oc.warning,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service tile
// ---------------------------------------------------------------------------

class _ServiceTile extends ConsumerStatefulWidget {
  const _ServiceTile({required this.service, this.providerPaused = false});

  final Service service;

  /// When the provider is "En pause", every listing is hidden from clients
  /// regardless of its own `published` flag — the footer reflects that.
  final bool providerPaused;

  @override
  ConsumerState<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends ConsumerState<_ServiceTile> {
  /// Optimistic published state: the value the provider just requested, held
  /// until the Firestore stream catches up (often slow on Senegal networks).
  /// `null` means "track the source of truth".
  bool? _pending;

  @override
  void didUpdateWidget(covariant _ServiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Stream has caught up to our optimistic value — stop overriding it.
    if (_pending != null && widget.service.published == _pending) {
      _pending = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
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
    final published = _pending ?? service.published;

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
          // On/off footer — status (dot + label) on the left, control on the
          // right. Hidden entirely under moderation: the trailing badge already
          // explains why, and a disabled switch reads as "broken". No divider —
          // this is a light footer of the same card, not a separate section.
          if (!moderationLocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Paused → a pause icon (not a colour-only dot) so the
                      // state reads without relying on colour alone.
                      if (widget.providerPaused)
                        Icon(
                          Icons.pause_circle_outline,
                          size: 14,
                          color: oc.warning,
                        )
                      else
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: published ? oc.success : oc.border,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        widget.providerPaused
                            ? l10n.serviceMaskedPaused
                            : published
                            ? l10n.serviceActive
                            : l10n.serviceInactive,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.providerPaused
                              ? oc.warning
                              : published
                              ? oc.success
                              : oc.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    label: published
                        ? l10n.serviceToggleDeactivate(service.title)
                        : l10n.serviceToggleActivate(service.title),
                    // Disabled while the whole profile is paused — a live-looking
                    // switch that does nothing visible to clients would confuse.
                    child: Switch(
                      value: published,
                      onChanged: widget.providerPaused
                          ? null
                          : (v) => _setPublished(v),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setPublished(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final messenger = ScaffoldMessenger.of(context);
    // Reflect the choice immediately; revert if the write fails.
    setState(() => _pending = value);
    try {
      await ref
          .read(serviceRepositoryProvider)
          .update(
            widget.service.copyWith(
              published: value,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.serviceFormSaveError),
          backgroundColor: oc.error,
        ),
      );
    }
  }

  Widget _iconFallback(OutalmaColors oc) {
    return ColoredBox(
      color: oc.primary.withValues(alpha: 0.08),
      child: Icon(
        _categoryIcon(widget.service.categoryId),
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
