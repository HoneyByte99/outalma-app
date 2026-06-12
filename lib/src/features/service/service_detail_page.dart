import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/service/service_providers.dart';
import '../../application/user/user_providers.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/price_type.dart';
import '../../domain/models/service.dart';
import '../booking/booking_request_sheet.dart';
import '../shared/network_image.dart';
import '../shared/marketplace_disclaimer.dart';
import '../shared/verified_badge.dart';
import 'service_zones_map.dart';
import '../shared/user_avatar.dart';

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));

    return serviceAsync.when(
      loading: () => const _ServiceDetailLoading(),
      error: (_, __) => _ServiceDetailError(
        onRetry: () => ref.invalidate(serviceDetailProvider(serviceId)),
      ),
      data: (service) {
        if (service == null) return const _ServiceDetailError();
        return _ServiceDetailContent(service: service);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

class _ServiceDetailContent extends ConsumerWidget {
  const _ServiceDetailContent({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final uid = ref.watch(authNotifierProvider).valueOrNull is AuthAuthenticated
        ? (ref.watch(authNotifierProvider).valueOrNull as AuthAuthenticated)
              .user
              .id
        : null;
    final isOwner = uid != null && uid == service.providerId;
    final formattedPrice = formatPriceFromCents(service.price);
    final priceLabel = service.priceType == PriceType.hourly
        ? '$formattedPrice/h'
        : '$formattedPrice (${l10n.priceFixed})';

    return Scaffold(
      backgroundColor: oc.background,
      body: CustomScrollView(
        slivers: [
          // ---- Collapsible hero header ----
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: oc.surface,
            leading: Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: oc.surface.withValues(alpha: 0.9),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: oc.primaryText,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              if (!isOwner)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: oc.surface.withValues(alpha: 0.9),
                    child: IconButton(
                      tooltip: l10n.bookingReport,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        Icons.flag_outlined,
                        size: 18,
                        color: oc.primaryText,
                      ),
                      onPressed: () => context.push(
                        AppRoutes.report(type: 'service', id: service.id),
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.none,
              background: _HeroGallery(
                photos: service.photos,
                fallback: _heroFallback(oc),
              ),
            ),
          ),

          // ---- Body ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  _CategoryBadge(categoryId: service.categoryId),
                  const SizedBox(height: AppSpacing.m),

                  // Title
                  Text(
                    service.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.s),

                  // Price
                  Text(
                    priceLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: oc.primary),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Provider info
                  _ProviderRow(providerId: service.providerId),
                  const SizedBox(height: AppSpacing.xl),

                  // Description
                  if (service.description != null &&
                      service.description!.isNotEmpty) ...[
                    Text(
                      l10n.serviceDescription,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _ExpandableText(text: service.description!),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Service zones
                  if (service.serviceZones.isNotEmpty) ...[
                    Text(
                      l10n.serviceZonesLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    ServiceZonesMap(zones: service.serviceZones),
                    const SizedBox(height: AppSpacing.s),
                    for (final zone in service.serviceZones)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: oc.secondaryText,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              zone.radiusKm > 0
                                  ? '${zone.label}, ${zone.radiusKm} km'
                                  : zone.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: oc.secondaryText),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ---- Sticky bottom bar ----
      bottomNavigationBar: isOwner
          ? _EditBottomBar(serviceId: service.id)
          : _BookingBottomBar(service: service),
    );
  }

  Widget _heroFallback(OutalmaColors oc) {
    return ColoredBox(
      color: oc.border,
      child: Center(
        child: Image.asset(
          'assets/images/logo_icon_cropped.png',
          height: 100,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero gallery — swipeable photo carousel with page indicators
// ---------------------------------------------------------------------------

class _HeroGallery extends StatefulWidget {
  const _HeroGallery({required this.photos, required this.fallback});

  final List<String> photos;
  final Widget fallback;

  @override
  State<_HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<_HeroGallery> {
  // viewportFraction < 1 lets the next photo peek in from the right — the
  // primary visual cue that the hero is swipeable (no text needed).
  final _controller = PageController(viewportFraction: 0.92);
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    // Empty state — no photos uploaded.
    if (photos.isEmpty) return widget.fallback;

    // Single photo — no carousel chrome needed.
    if (photos.length == 1) {
      return AppNetworkImage(
        url: photos.first,
        fit: BoxFit.cover,
        width: double.infinity,
        errorWidget: widget.fallback,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          label: l10n.servicePhotoCounter(_current + 1, photos.length),
          child: PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: AppNetworkImage(
                url: photos[i],
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: widget.fallback,
              ),
            ),
          ),
        ),
        // Page indicator dots — anchored to the bottom of the hero.
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.m,
          child: _PageDots(count: photos.length, current: _current),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    // A dark pill behind the dots guarantees contrast against any photo
    // (bright walls, tiles, sky) without per-background contrast math.
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == current ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == current
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category badge
// ---------------------------------------------------------------------------

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.categoryId});

  final CategoryId categoryId;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: oc.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        categoryId.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: oc.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider row
// ---------------------------------------------------------------------------

class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final user = ref.watch(userByIdProvider(providerId)).valueOrNull;
    final providerProfile = ref
        .watch(providerProfileByIdProvider(providerId))
        .valueOrNull;
    final isVerified =
        providerProfile != null && (user?.phoneE164?.isNotEmpty ?? false);

    return Semantics(
      label: '${user?.displayName ?? ''} — ${l10n.serviceViewProfile}',
      button: true,
      child: InkWell(
        onTap: () => context.push(AppRoutes.providerProfile(providerId)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: oc.cardSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            border: Border.all(color: oc.border),
          ),
          child: Row(
            children: [
              UserAvatar(
                displayName: user?.displayName ?? '',
                photoPath: user?.photoPath,
                radius: 22,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.serviceProviderLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: oc.secondaryText),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user?.displayName ?? '—',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: oc.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const VerifiedBadge(compact: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    l10n.serviceViewProfile,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: oc.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: oc.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable description text
// ---------------------------------------------------------------------------

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  static const _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : _maxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: oc.secondaryText,
            height: 1.5,
          ),
        ),
        if (widget.text.length > 200) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            button: true,
            expanded: _expanded,
            label: _expanded ? l10n.seeLess : l10n.seeMore,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s,
                  horizontal: AppSpacing.xs,
                ),
                child: Text(
                  _expanded ? l10n.seeLess : l10n.seeMore,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: oc.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky booking bottom bar
// ---------------------------------------------------------------------------

class _BookingBottomBar extends StatelessWidget {
  const _BookingBottomBar({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.m,
        AppSpacing.xl,
        AppSpacing.m + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MarketplaceDisclaimer(dense: true),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton(
            onPressed: () => _openBookingSheet(context),
            child: Text(l10n.serviceBook),
          ),
        ],
      ),
    );
  }

  void _openBookingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingRequestSheet(
        serviceId: service.id,
        providerId: service.providerId,
        serviceTitle: service.title,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Owner edit bottom bar
// ---------------------------------------------------------------------------

class _EditBottomBar extends StatelessWidget {
  const _EditBottomBar({required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.m,
        AppSpacing.xl,
        AppSpacing.m + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: ElevatedButton.icon(
        onPressed: () => context.push(AppRoutes.serviceEdit(serviceId)),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(l10n.serviceEditListing),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading state — animated shimmer skeleton
// ---------------------------------------------------------------------------

class _ServiceDetailLoading extends StatefulWidget {
  const _ServiceDetailLoading();

  @override
  State<_ServiceDetailLoading> createState() => _ServiceDetailLoadingState();
}

class _ServiceDetailLoadingState extends State<_ServiceDetailLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmer = Color.lerp(oc.border, oc.surface, _anim.value)!;
        return Scaffold(
          backgroundColor: oc.background,
          appBar: AppBar(leading: const BackButton()),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 240, color: shimmer),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 80,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Container(
                      height: 24,
                      width: 200,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Container(
                      height: 20,
                      width: 100,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ServiceDetailError extends StatelessWidget {
  const _ServiceDetailError({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: oc.icons),
              const SizedBox(height: AppSpacing.l),
              Text(
                l10n.serviceNotFound,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.s),
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.retry),
                )
              else
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.back),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
