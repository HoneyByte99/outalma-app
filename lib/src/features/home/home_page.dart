import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/service/service_providers.dart';
import '../../application/user/user_providers.dart';
import '../../data/services/geocoding_service.dart';
import '../../domain/enums/active_mode.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/models/service.dart';
import '../shared/category_icon.dart';
import '../shared/user_avatar.dart';

// ---------------------------------------------------------------------------
// Filter state — local to this page subtree
// ---------------------------------------------------------------------------

final _selectedCategoryProvider = StateProvider<CategoryId?>((ref) => null);

/// Location search filter: place label, lat/lng, and search radius.
class _LocationFilter {
  const _LocationFilter({
    required this.label,
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });
  final String label;
  final double lat;
  final double lng;
  final double radiusKm;
}

final _locationFilterProvider = StateProvider<_LocationFilter?>((ref) => null);

/// Haversine distance in km between two lat/lng points.
double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0; // Earth radius in km
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

/// Returns true if any of the service's zones overlaps with the search circle.
bool _serviceMatchesLocation(Service service, _LocationFilter filter) {
  for (final zone in service.serviceZones) {
    if (zone.latitude == 0 && zone.longitude == 0) continue; // legacy
    final dist = _haversineKm(filter.lat, filter.lng, zone.latitude, zone.longitude);
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
    final oc = context.oc;
    final authAsync = ref.watch(authNotifierProvider);
    final activeMode = ref.watch(activeModeProvider);

    final displayName = authAsync.valueOrNull is AuthAuthenticated
        ? (authAsync.valueOrNull as AuthAuthenticated).user.displayName
        : '';

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: const Text('Outalma'),
        actions: [
          _ModeBadge(
            activeMode: activeMode,
            onTap: () => context.go(AppRoutes.profile),
          ),
          const BellIconButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              displayName.isNotEmpty
                  ? 'Bonjour $displayName'
                  : 'Bonjour',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Que recherchez-vous ?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: oc.secondaryText,
                  ),
            ),
          ),
          // Location search bar
          const _LocationSearchBar(),
          const SizedBox(height: 8),
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
// Category chips row
// ---------------------------------------------------------------------------

class _CategoryChipsRow extends ConsumerWidget {
  const _CategoryChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedCategoryProvider);

    final items = <(String label, CategoryId? value)>[
      ('Tout', null),
      ...CategoryId.values.map((c) => (c.label, c)),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, value) = items[i];
          final isActive = selected == value;
          return _CategoryChip(
            label: label,
            isActive: isActive,
            onTap: () => ref
                .read(_selectedCategoryProvider.notifier)
                .state = value,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location search bar — Uber-style
// ---------------------------------------------------------------------------

class _LocationSearchBar extends ConsumerStatefulWidget {
  const _LocationSearchBar();

  @override
  ConsumerState<_LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends ConsumerState<_LocationSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<PlaceSuggestion> _suggestions = [];
  double _radiusKm = 30;
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
    _focusNode.unfocus();

    final geocoding = ref.read(geocodingServiceProvider);
    final coords = await geocoding.getPlaceLatLng(suggestion.placeId);
    if (coords == null || !mounted) return;

    ref.read(_locationFilterProvider.notifier).state = _LocationFilter(
      label: suggestion.description,
      lat: coords.lat,
      lng: coords.lng,
      radiusKm: _radiusKm,
    );
  }

  void _updateRadius(double value) {
    setState(() => _radiusKm = value);
    final current = ref.read(_locationFilterProvider);
    if (current != null) {
      ref.read(_locationFilterProvider.notifier).state = _LocationFilter(
        label: current.label,
        lat: current.lat,
        lng: current.lng,
        radiusKm: value,
      );
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _suggestions = [];
      _expanded = false;
    });
    ref.read(_locationFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final filter = ref.watch(_locationFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: oc.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: oc.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 20, color: oc.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _expanded || filter != null
                        ? TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Où cherchez-vous ?',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                              isDense: true,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                            onChanged: _onSearchChanged,
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Où cherchez-vous ?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: oc.secondaryText),
                            ),
                          ),
                  ),
                  if (filter != null)
                    GestureDetector(
                      onTap: _clear,
                      child: Icon(Icons.close, size: 18, color: oc.secondaryText),
                    ),
                ],
              ),
            ),
          ),

          // Suggestions dropdown
          if (_suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: oc.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: oc.border),
                boxShadow: [
                  BoxShadow(
                    color: oc.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
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

          // Radius slider — visible when a location is selected
          if (filter != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.radar_outlined, size: 16, color: oc.secondaryText),
                const SizedBox(width: 6),
                Text(
                  'Rayon',
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
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? oc.primary : oc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? oc.primary : oc.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isActive ? oc.surface : oc.primaryText,
                fontWeight: FontWeight.w600,
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
    final locationFilter = ref.watch(_locationFilterProvider);
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
    final priceLabel = service.priceType.name == 'hourly'
        ? '${(service.price / 100).toStringAsFixed(0)} €/h'
        : '${(service.price / 100).toStringAsFixed(0)} €';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.serviceDetail(service.id)),
      child: Container(
        decoration: BoxDecoration(
          color: context.isDark ? oc.surface : oc.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: oc.shadow,
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image — 60% of card height
            Expanded(
              flex: 60,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    service.photos.isNotEmpty
                        ? Image.network(
                            service.photos.first,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => _iconPlaceholder(oc),
                          )
                        : _iconPlaceholder(oc),

                    // Soft bottom fade into card surface
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
                              (context.isDark ? oc.surface : oc.surfaceVariant)
                                  .withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Category badge top-left
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
                          _categoryLabel(service.categoryId),
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

            // Info section — 40% of card height
            Expanded(
              flex: 40,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title + price
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
                      ],
                    ),
                    // Provider row
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
                            providerUser?.displayName ?? '—',
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
          _categoryIcon(service.categoryId),
          size: 40,
          color: oc.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  String _categoryLabel(CategoryId id) => id.label;

  IconData _categoryIcon(CategoryId id) => id.icon;
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
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 56,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun service disponible\npour le moment',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: oc.secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode badge — AppBar shortcut to profile/switch tab
// ---------------------------------------------------------------------------

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.activeMode, required this.onTap});

  final ActiveMode activeMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final isClient = activeMode == ActiveMode.client;
    final label = isClient ? 'Client' : 'Prestataire';
    final color = isClient ? oc.primary : oc.success;

    return GestureDetector(
      onTap: onTap,
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
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 56,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

