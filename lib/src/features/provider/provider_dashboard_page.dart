import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/user/user_providers.dart';
import '../../domain/enums/active_mode.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/models/provider_profile.dart';
import '../../domain/models/service.dart';

class ProviderDashboardPage extends ConsumerWidget {
  const ProviderDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final profileAsync = ref.watch(currentProviderProfileProvider);
    final servicesAsync = ref.watch(providerServicesProvider);
    final activeMode = ref.watch(activeModeProvider);

    return Scaffold(
      backgroundColor: oc.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: oc.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Tableau de bord',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            actions: [
              _ModeBadge(
                activeMode: activeMode,
                onTap: () => context.go(AppRoutes.profile),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () => context.push(AppRoutes.providerOnboarding),
                tooltip: 'Mon profil prestataire',
              ),
              const BellIconButton(),
              const SizedBox(width: 4),
            ],
          ),

          // ---- Profile banner (onboarding prompt if no profile) ----
          SliverToBoxAdapter(
            child: profileAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (profile) => profile == null
                  ? _OnboardingBanner()
                  : _ProfileCard(profile: profile),
            ),
          ),

          // ---- Services header ----
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mes services',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(AppRoutes.serviceNew),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
            ),
          ),

          // ---- Services list ----
          servicesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (_, __) => const SliverToBoxAdapter(
              child: _ErrorState(
                message: 'Impossible de charger vos services.',
              ),
            ),
            data: (services) => services.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyServices())
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _ServiceTile(service: services[i]),
                        childCount: services.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.serviceNew),
        backgroundColor: oc.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding banner
// ---------------------------------------------------------------------------

class _OnboardingBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              oc.success.withValues(alpha: 0.12),
              oc.success.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: oc.success.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: oc.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch_outlined,
                color: oc.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activez votre profil',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: oc.success,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Quelques infos pour commencer à recevoir des demandes.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () =>
                  GoRouter.of(context).push(AppRoutes.providerOnboarding),
              style: ElevatedButton.styleFrom(
                backgroundColor: oc.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Activer'),
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
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: oc.surface,
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
              child: Icon(
                Icons.verified_outlined,
                color: oc.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.active ? 'Profil actif' : 'Profil inactif',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: profile.active
                              ? oc.success
                              : oc.secondaryText,
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
    final priceLabel = service.priceType.name == 'hourly'
        ? '${(service.price / 100).toStringAsFixed(0)} €/h'
        : '${(service.price / 100).toStringAsFixed(0)} € (forfait)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: oc.surface,
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
                ? Image.network(
                    service.photos.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconFallback(oc),
                  )
                : _iconFallback(oc),
          ),
        ),
        title: Text(
          service.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
            _PublishedDot(published: service.published),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: oc.icons,
              size: 20,
            ),
          ],
        ),
        onTap: () => context.push(AppRoutes.serviceEdit(service.id)),
      ),
    );
  }

  Widget _iconFallback(dynamic oc) {
    return Container(
      color: oc.primary.withValues(alpha: 0.08),
      child: Icon(_categoryIcon(service.categoryId), size: 22, color: oc.primary),
    );
  }

  IconData _categoryIcon(CategoryId categoryId) {
    switch (categoryId) {
      case CategoryId.menage:
        return Icons.cleaning_services_outlined;
      case CategoryId.plomberie:
        return Icons.plumbing_outlined;
      case CategoryId.jardinage:
        return Icons.yard_outlined;
      case CategoryId.autre:
        return Icons.handyman_outlined;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.categoryId});

  final CategoryId categoryId;

  static const _labels = {
    CategoryId.menage: 'Ménage',
    CategoryId.plomberie: 'Plomberie',
    CategoryId.jardinage: 'Jardinage',
    CategoryId.autre: 'Autre',
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: oc.secondaryText,
            ),
      ),
    );
  }
}

class _PublishedDot extends StatelessWidget {
  const _PublishedDot({required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Tooltip(
      message: published ? 'Publié' : 'Non publié',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: published ? oc.success : oc.border,
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
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.add_box_outlined,
              size: 56,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun service publié',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre premier service pour commencer\nà recevoir des demandes.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: oc.secondaryText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => GoRouter.of(context).push(AppRoutes.serviceNew),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer un service'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.oc.secondaryText,
              ),
          textAlign: TextAlign.center,
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
