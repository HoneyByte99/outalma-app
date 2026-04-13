import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/home/location_providers.dart';
import '../../application/review/review_providers.dart';
import '../../application/service/service_providers.dart';
import '../../application/user/user_providers.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/saved_locations_service.dart';
import '../../domain/enums/active_mode.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/models/review.dart';
import '../../domain/models/service.dart';
import '../shared/category_icon.dart';
import '../shared/user_avatar.dart';
import '../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Filter state — local to this page subtree
// ---------------------------------------------------------------------------

final _selectedCategoryProvider = StateProvider<CategoryId?>((ref) => null);

/// Haversine distance in km between two lat/lng points.
double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _deg2rad(double deg) => deg * (math.pi / 180);

bool _serviceMatchesLocation(Service service, LocationFilter filter) {
  for (final zone in service.serviceZones) {
    if (zone.latitude == 0 && zone.longitude == 0) continue;
    final dist =
        _haversineKm(filter.lat, filter.lng, zone.latitude, zone.longitude);
    if (dist <= filter.radiusKm + zone.radiusKm) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// HomePage
// ---------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final authAsync = ref.watch(authNotifierProvider);
    final activeMode = ref.watch(activeModeProvider);

    final displayName = authAsync.valueOrNull is AuthAuthenticated
        ? (authAsync.valueOrNull as AuthAuthenticated).user.displayName
        : '';

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: const _LocationPill(),
        actions: [
          _ModeBadge(activeMode: activeMode),
          const BellIconButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              displayName.isNotEmpty
                  ? l10n.homeGreeting(displayName)
                  : l10n.homeGreetingNoName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              l10n.homeSearchPrompt,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: oc.secondaryText),
            ),
          ),
          // Category chips
          const _CategoryChipsRow(),
          const SizedBox(height: 8),
          // Service grid
          const Expanded(child: _ServiceGrid()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location pill — compact AppBar location indicator
// ---------------------------------------------------------------------------

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final filter = ref.watch(locationFilterProvider);
    final label = filter != null
        ? '${filter.label}, ${filter.radiusKm.round()} km'
        : l10n.locationAllFrance;

    return GestureDetector(
      onTap: () => _showLocationSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: oc.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 16, color: oc.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: oc.primary,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: oc.primary),
          ],
        ),
      ),
    );
  }

  void _showLocationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.oc.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _LocationSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Location bottom sheet — search + radius + favorites
// ---------------------------------------------------------------------------

class _LocationSheet extends ConsumerStatefulWidget {
  const _LocationSheet();

  @override
  ConsumerState<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<_LocationSheet> {
  final _controller = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  late double _radiusKm;
  Timer? _radiusDebounce;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(locationFilterProvider);
    _radiusKm = filter?.radiusKm ?? 30;
    if (filter != null) {
      _controller.text = filter.label;
    }
  }

  @override
  void dispose() {
    _radiusDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String input) async {
    if (input.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final geocoding = ref.read(geocodingServiceProvider);
      final results = await geocoding.autocomplete(input);
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {}
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _controller.text = suggestion.description;
    setState(() => _suggestions = []);

    final geocoding = ref.read(geocodingServiceProvider);
    final coords = await geocoding.getPlaceLatLng(suggestion.placeId);
    if (coords == null || !mounted) return;

    // Apply the filter but keep the sheet open so the user can adjust the radius.
    ref.read(locationFilterProvider.notifier).state = LocationFilter(
      label: suggestion.description,
      lat: coords.lat,
      lng: coords.lng,
      radiusKm: _radiusKm,
    );
  }

  void _applyFavorite(SavedLocation loc) {
    ref.read(locationFilterProvider.notifier).state = LocationFilter(
      label: loc.address,
      lat: loc.lat,
      lng: loc.lng,
      radiusKm: loc.radiusKm,
    );
    Navigator.of(context).pop();
  }

  void _clearFilter() {
    ref.read(locationFilterProvider.notifier).state = null;
    Navigator.of(context).pop();
  }

  void _saveCurrentLocation() {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.read(locationFilterProvider);
    if (filter == null) return;

    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.locationAddressName),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.locationAddressHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              ref.read(savedLocationsProvider.notifier).add(SavedLocation(
                    label: name,
                    address: filter.label,
                    lat: filter.lat,
                    lng: filter.lng,
                    radiusKm: filter.radiusKm,
                  ));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.locationSaved(name))),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _updateRadius(double value) {
    setState(() => _radiusKm = value);
    _radiusDebounce?.cancel();
    _radiusDebounce = Timer(const Duration(milliseconds: 300), () {
      final current = ref.read(locationFilterProvider);
      if (current != null) {
        ref.read(locationFilterProvider.notifier).state =
            current.copyWith(radiusKm: value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final filter = ref.watch(locationFilterProvider);
    final savedLocations = ref.watch(savedLocationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: oc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.locationTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (filter != null)
                  IconButton(
                    onPressed: _saveCurrentLocation,
                    icon: Icon(Icons.star_outline_rounded,
                        color: oc.warning, size: 24),
                    tooltip: l10n.locationSaveTooltip,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Search field
            TextField(
              controller: _controller,
              autofocus: false,
              decoration: InputDecoration(
                hintText: l10n.locationSearchHint,
                prefixIcon:
                    Icon(Icons.search_rounded, size: 20, color: oc.icons),
                suffixIcon: filter != null
                    ? IconButton(
                        onPressed: () {
                          _controller.clear();
                          _clearFilter();
                        },
                        icon: Icon(Icons.close, size: 18, color: oc.icons),
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 4),

            // Suggestions
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: oc.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: oc.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: oc.border.withValues(alpha: 0.5)),
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return InkWell(
                      onTap: () => _selectSuggestion(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 16, color: oc.secondaryText),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.description,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Radius slider + validate button
            if (filter != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.radar_outlined, size: 16, color: oc.secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    l10n.locationRadius,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: oc.secondaryText),
                  ),
                  Expanded(
                    child: Slider(
                      value: _radiusKm,
                      min: 5,
                      max: 200,
                      divisions: 39,
                      activeColor: oc.primary,
                      inactiveColor: oc.border,
                      onChanged: _updateRadius,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${_radiusKm.round()} km',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: oc.primary,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.locationValidate),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // "Toute la France" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearFilter,
                icon: const Icon(Icons.public_outlined, size: 18),
                label: Text(l10n.locationAllFrance),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: oc.border),
                ),
              ),
            ),

            // Saved locations
            if (savedLocations.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.locationMyAddresses,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: savedLocations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final loc = savedLocations[i];
                    return _SavedLocationTile(
                      location: loc,
                      onTap: () => _applyFavorite(loc),
                      onDelete: () =>
                          ref.read(savedLocationsProvider.notifier).remove(i),
                    );
                  },
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SavedLocationTile extends StatelessWidget {
  const _SavedLocationTile({
    required this.location,
    required this.onTap,
    required this.onDelete,
  });

  final SavedLocation location;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: oc.border),
        ),
        child: Row(
          children: [
            Icon(Icons.star_rounded, size: 18, color: oc.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${location.address}, ${location.radiusKm.round()} km',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: oc.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close, size: 16, color: oc.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chips row
// ---------------------------------------------------------------------------

class _CategoryChipsRow extends ConsumerWidget {
  const _CategoryChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(_selectedCategoryProvider);

    final items = <(String label, IconData icon, CategoryId? value)>[
      (l10n.categoryAll, Icons.apps_outlined, null),
      ...CategoryId.values.map((c) => (c.label, c.icon, c)),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, icon, value) = items[i];
          final isActive = selected == value;
          return _CategoryChip(
            icon: icon,
            label: label,
            isActive: isActive,
            onTap: () =>
                ref.read(_selectedCategoryProvider.notifier).state = value,
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final color = isActive ? oc.surface : oc.primaryText;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? oc.primary : oc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? oc.primary : oc.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service grid
// ---------------------------------------------------------------------------

class _ServiceGrid extends ConsumerWidget {
  const _ServiceGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(_selectedCategoryProvider);
    final locationFilter = ref.watch(locationFilterProvider);
    final servicesAsync = ref.watch(serviceListProvider);

    return servicesAsync.when(
      loading: () => const _ServiceGridLoading(),
      error: (_, __) => _ErrorState(
        onRetry: () => ref.invalidate(serviceListProvider),
      ),
      data: (services) {
        var filtered = selectedCategory == null
            ? services
            : services
                .where((s) => s.categoryId == selectedCategory)
                .toList();

        if (locationFilter != null) {
          filtered = filtered
              .where((s) => _serviceMatchesLocation(s, locationFilter))
              .toList();
        }

        if (filtered.isEmpty) {
          return const _EmptyState();
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            return _ServiceCard(service: filtered[i]);
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Service card
// ---------------------------------------------------------------------------

class _ServiceCard extends ConsumerWidget {
  const _ServiceCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final providerUser =
        ref.watch(userByIdProvider(service.providerId)).valueOrNull;
    final reviews =
        ref.watch(reviewsForUserProvider(service.providerId)).valueOrNull ?? [];
    final priceLabel = service.priceType.name == 'hourly'
        ? '${(service.price / 100).toStringAsFixed(0)} \u20ac/h'
        : '${(service.price / 100).toStringAsFixed(0)} \u20ac';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.serviceDetail(service.id)),
      child: Container(
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: oc.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A1B3A4B),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 60,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    service.photos.isNotEmpty
                        ? Image.network(
                            service.photos.first,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) =>
                                _iconPlaceholder(oc),
                          )
                        : _iconPlaceholder(oc),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 32,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              oc.cardSurface.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: oc.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service.categoryId.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 40,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          priceLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: oc.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        _RatingRow(reviews: reviews),
                      ],
                    ),
                    Row(
                      children: [
                        UserAvatar(
                          displayName: providerUser?.displayName ?? '',
                          photoPath: providerUser?.photoPath,
                          radius: 10,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            providerUser?.displayName ?? '\u2014',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: oc.secondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder(dynamic oc) {
    return Container(
      color: oc.primary.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          service.categoryId.icon,
          size: 40,
          color: oc.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rating row — stars + average or "Nouveau" badge
// ---------------------------------------------------------------------------

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;

    if (reviews.isEmpty) {
      return Row(
        children: [
          Icon(Icons.star_outline_rounded, size: 14, color: oc.icons),
          const SizedBox(width: 3),
          Text(
            'Nouveau',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: oc.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      );
    }

    final avg = reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
    final fullStars = avg.floor();
    final hasHalf = (avg - fullStars) >= 0.5;

    return Row(
      children: [
        for (int i = 0; i < fullStars; i++)
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBBF24)),
        if (hasHalf)
          const Icon(Icons.star_half_rounded, size: 14, color: Color(0xFFFBBF24)),
        for (int i = 0; i < 5 - fullStars - (hasHalf ? 1 : 0); i++)
          Icon(Icons.star_outline_rounded, size: 14, color: oc.icons),
        const SizedBox(width: 4),
        Text(
          '${avg.toStringAsFixed(1)} (${reviews.length})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: oc.secondaryText,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _ServiceGridLoading extends StatelessWidget {
  const _ServiceGridLoading();

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(color: oc.border),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + error states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 56, color: oc.icons),
            const SizedBox(height: 16),
            Text(
              l10n.servicesEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: oc.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode badge
// ---------------------------------------------------------------------------

class _ModeBadge extends ConsumerWidget {
  const _ModeBadge({required this.activeMode});

  final ActiveMode activeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final isClient = activeMode == ActiveMode.client;
    final label = isClient ? l10n.modeClient : l10n.modeProvider;
    final color = isClient ? oc.primary : oc.success;

    return GestureDetector(
      onTap: () {
        final newMode =
            isClient ? ActiveMode.provider : ActiveMode.client;
        ref.read(authNotifierProvider.notifier).switchMode(newMode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newMode == ActiveMode.client
                ? l10n.modeClientActivated
                : l10n.modeProviderActivated),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.swap_horiz_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined, size: 56, color: oc.icons),
            const SizedBox(height: 16),
            Text(
              l10n.errorLoading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
