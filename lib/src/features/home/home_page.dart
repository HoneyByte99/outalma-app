import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
import '../../core/utils/format_utils.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/saved_locations_service.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/price_type.dart';
import '../../domain/models/review.dart';
import '../../domain/models/service.dart';
import '../../domain/utils/distance.dart';
import '../../app/app_spacing.dart';
import '../shared/category_icon.dart';
import '../shared/mode_badge.dart';
import '../shared/network_image.dart';
import '../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Filter state — local to this page subtree
// ---------------------------------------------------------------------------

final _selectedCategoryProvider = StateProvider<CategoryId?>((ref) => null);
final _searchQueryProvider = StateProvider<String>((ref) => '');

bool _serviceMatchesLocation(Service service, LocationFilter filter) {
  for (final zone in service.serviceZones) {
    if (zone.latitude == 0 && zone.longitude == 0) continue;
    final dist = haversineKm(
      filter.lat,
      filter.lng,
      zone.latitude,
      zone.longitude,
    );
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

    final displayName = authAsync.valueOrNull is AuthAuthenticated
        ? (authAsync.valueOrNull as AuthAuthenticated).user.displayName
        : '';

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: const _LocationPill(),
        actions: const [ModeBadge(), BellIconButton(), SizedBox(width: 4)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting — compact single line
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.m,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Text(
              displayName.isNotEmpty
                  ? l10n.homeGreeting(displayName)
                  : l10n.homeGreetingNoName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Search bar — replaces static subtitle
          const _SearchBar(),
          // Category chips
          const _CategoryChipsRow(),
          const SizedBox(height: AppSpacing.l),
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

    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: () => _showLocationSheet(context, ref),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: oc.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
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
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: oc.primary,
              ),
            ],
          ),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXLarge),
        ),
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
          decoration: InputDecoration(hintText: l10n.locationAddressHint),
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
              ref
                  .read(savedLocationsProvider.notifier)
                  .add(
                    SavedLocation(
                      label: name,
                      address: filter.label,
                      lat: filter.lat,
                      lng: filter.lng,
                      radiusKm: filter.radiusKm,
                    ),
                  );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.locationSaved(name))));
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  bool _geoLoading = false;

  Future<void> _useMyLocation() async {
    setState(() => _geoLoading = true);

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationServiceDisabled,
              ),
            ),
          );
        }
        return;
      }

      // Check permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationPermissionDenied,
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      // Reverse geocode to get a readable label
      final geocoding = ref.read(geocodingServiceProvider);
      final label = await geocoding.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      _controller.text = label ?? 'Ma position';
      setState(() => _suggestions = []);

      ref.read(locationFilterProvider.notifier).state = LocationFilter(
        label: label ?? 'Ma position',
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: _radiusKm,
      );
    } catch (e) {
      debugPrint('[Location] GPS error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.locationGeoError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  void _updateRadius(double value) {
    setState(() => _radiusKm = value);
    _radiusDebounce?.cancel();
    _radiusDebounce = Timer(const Duration(milliseconds: 300), () {
      final current = ref.read(locationFilterProvider);
      if (current != null) {
        ref.read(locationFilterProvider.notifier).state = current.copyWith(
          radiusKm: value,
        );
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.m, AppSpacing.xl, 0),
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
            const SizedBox(height: AppSpacing.l),

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
                    icon: Icon(
                      Icons.star_outline_rounded,
                      color: oc.warning,
                      size: 24,
                    ),
                    tooltip: l10n.locationSaveTooltip,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),

            // Search field
            TextField(
              controller: _controller,
              autofocus: false,
              decoration: InputDecoration(
                hintText: l10n.locationSearchHint,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: oc.icons,
                ),
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
            const SizedBox(height: AppSpacing.s),

            // "Use my location" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _geoLoading ? null : _useMyLocation,
                icon: _geoLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: oc.primary,
                      ),
                label: Text(l10n.locationUseMyPosition),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.minTouchTarget),
                  side: BorderSide(color: oc.primary.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Suggestions
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: oc.cardSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: oc.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: oc.border.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return InkWell(
                      onTap: () => _selectSuggestion(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: oc.secondaryText,
                            ),
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
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Icon(Icons.radar_outlined, size: 16, color: oc.secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    l10n.locationRadius,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: oc.secondaryText),
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
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.locationValidate),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.m),

            // "Toute la France" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearFilter,
                icon: const Icon(Icons.public_outlined, size: 18),
                label: Text(l10n.locationAllFrance),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.minTouchTarget),
                  side: BorderSide(color: oc.border),
                ),
              ),
            ),

            // Saved locations
            if (savedLocations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.locationMyAddresses,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.s),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${location.address}, ${location.radiusKm.round()} km',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              icon: Icon(Icons.close, size: 18, color: oc.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final query = ref.watch(_searchQueryProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.m,
      ),
      child: TextField(
        controller: _controller,
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 150), () {
            ref.read(_searchQueryProvider.notifier).state = v.trim();
          });
        },
        decoration: InputDecoration(
          hintText: l10n.homeSearchHint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: oc.icons),
                  onPressed: () {
                    _controller.clear();
                    ref.read(_searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
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
      height: AppSpacing.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
    return Semantics(
      label: label,
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? oc.primary : oc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? oc.primary : oc.border),
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
    final searchQuery = ref.watch(_searchQueryProvider).toLowerCase();
    final servicesAsync = ref.watch(serviceListProvider);

    return servicesAsync.when(
      loading: () => const _ServiceGridLoading(),
      error: (_, __) =>
          _ErrorState(onRetry: () => ref.invalidate(serviceListProvider)),
      data: (services) {
        var filtered = selectedCategory == null
            ? services
            : services.where((s) => s.categoryId == selectedCategory).toList();

        if (locationFilter != null) {
          filtered = filtered
              .where((s) => _serviceMatchesLocation(s, locationFilter))
              .toList();
        }

        if (searchQuery.isNotEmpty) {
          filtered = filtered
              .where((s) => s.title.toLowerCase().contains(searchQuery))
              .toList();
        }

        if (filtered.isEmpty) {
          return _EmptyState(searchQuery: searchQuery);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width > 700 ? 3 : 2;
            const spacing = AppSpacing.l;
            const hPad = AppSpacing.l;
            final cardWidth =
                (width - hPad * 2 - (columns - 1) * spacing) / columns;
            const infoHeight = 112.0;
            final cardHeight = cardWidth + infoHeight;
            final ratio = cardWidth / cardHeight;

            // Auto-load more services when the user scrolls near the bottom
            // (B.4 pagination). We bump the page size by 30 each time, which
            // makes the underlying Firestore stream extend its limit.
            return NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (notif is ScrollEndNotification &&
                    notif.metrics.extentAfter < 200) {
                  final currentLimit = ref.read(serviceListPageSizeProvider);
                  if (services.length >= currentLimit) {
                    // Only request more if we've actually got the previous
                    // page filled — otherwise we're at the true end.
                    ref.read(serviceListPageSizeProvider.notifier).state =
                        currentLimit + 30;
                  }
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  AppSpacing.xxl,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: ratio,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  return _ServiceCard(service: filtered[i]);
                },
              ),
            );
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
    final providerUser = ref
        .watch(userByIdProvider(service.providerId))
        .valueOrNull;
    final reviews =
        ref.watch(reviewsForUserProvider(service.providerId)).valueOrNull ?? [];
    final formattedPrice = formatPriceFromCents(service.price);
    final priceLabel = service.priceType == PriceType.hourly
        ? '$formattedPrice/h'
        : formattedPrice;

    return Semantics(
      label: service.title,
      button: true,
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.serviceDetail(service.id)),
        child: Container(
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(color: oc.border),
          boxShadow: [
            BoxShadow(
              color: oc.shadow,
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image — takes all remaining space
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusLarge),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    service.photos.isNotEmpty
                        ? AppNetworkImage(
                            url: service.photos.first,
                            fit: BoxFit.cover,
                            errorWidget: _iconPlaceholder(oc),
                          )
                        : _iconPlaceholder(oc),
                    Positioned(
                      top: AppSpacing.s,
                      left: AppSpacing.s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: Text(
                          service.categoryId.label,
                          style: Theme.of(context).textTheme.labelSmall
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
            // Info — intrinsic height, never overflows
            // Info block \u2014 hierarchy A.4: title dominant, price+rating
            // secondary on one row, provider name as discreet tertiary.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.s,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: oc.primary,
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _RatingRow(reviews: reviews),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    providerUser?.displayName ?? '\u2014',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _iconPlaceholder(OutalmaColors oc) {
    return ColoredBox(
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
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;

    if (reviews.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_outline_rounded, size: 12, color: oc.icons),
          const SizedBox(width: 3),
          Text(
            l10n.ratingNew,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: oc.secondaryText,
              fontStyle: FontStyle.italic,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    final avg = reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 12, color: oc.warning),
        const SizedBox(width: 2),
        Text(
          '${avg.toStringAsFixed(1)} (${reviews.length})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: oc.secondaryText,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _ServiceGridLoading extends StatefulWidget {
  const _ServiceGridLoading();

  @override
  State<_ServiceGridLoading> createState() => _ServiceGridLoadingState();
}

class _ServiceGridLoadingState extends State<_ServiceGridLoading>
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        const spacing = AppSpacing.l;
        const hPad = AppSpacing.l;
        final cardWidth =
            (constraints.maxWidth - hPad * 2 - (columns - 1) * spacing) /
            columns;
        const infoHeight = 112.0;
        final ratio = cardWidth / (cardWidth + infoHeight);

        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final shimmer = Color.lerp(oc.border, oc.surface, _anim.value)!;
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.xxl,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: ratio,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                child: Container(color: shimmer),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + error states
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  const _EmptyState({this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final message = searchQuery.isNotEmpty
        ? l10n.homeSearchEmpty(searchQuery)
        : l10n.servicesEmpty;

    final hasActiveFilters = ref.watch(_selectedCategoryProvider) != null ||
        ref.watch(_searchQueryProvider).isNotEmpty ||
        ref.watch(locationFilterProvider) != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 56, color: oc.icons),
            const SizedBox(height: AppSpacing.l),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: AppSpacing.l),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(_selectedCategoryProvider.notifier).state = null;
                  ref.read(_searchQueryProvider.notifier).state = '';
                  ref.read(locationFilterProvider.notifier).state = null;
                },
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(l10n.clearFilters),
              ),
            ],
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
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
