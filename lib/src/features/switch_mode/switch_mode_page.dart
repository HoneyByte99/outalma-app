import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/theme/theme_provider.dart';
import '../../application/user/user_providers.dart';
import '../../domain/enums/active_mode.dart';

class SwitchModePage extends ConsumerStatefulWidget {
  const SwitchModePage({super.key});

  @override
  ConsumerState<SwitchModePage> createState() => _SwitchModePageState();
}

class _SwitchModePageState extends ConsumerState<SwitchModePage> {
  bool _saving = false;

  Future<void> _selectMode(ActiveMode mode) async {
    if (ref.read(activeModeProvider) == mode) {
      context.pop();
      return;
    }

    setState(() => _saving = true);

    try {
      await ref.read(authNotifierProvider.notifier).switchMode(mode);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Impossible de changer de mode. Réessayez.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final activeMode = ref.watch(activeModeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Mode section ---
                    Text(
                      'Votre mode actif',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Passez du mode client au mode prestataire à tout moment.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: oc.secondaryText,
                          ),
                    ),
                    const SizedBox(height: 32),
                    _ModeCard(
                      mode: ActiveMode.client,
                      isActive: activeMode == ActiveMode.client,
                      icon: Icons.search_rounded,
                      title: 'Mode Client',
                      subtitle:
                          'Recherchez et réservez des services à domicile.',
                      accentColor: oc.primary,
                      onTap: () => _selectMode(ActiveMode.client),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      mode: ActiveMode.provider,
                      isActive: activeMode == ActiveMode.provider,
                      icon: Icons.handyman_rounded,
                      title: 'Mode Prestataire',
                      subtitle: 'Proposez vos services et gérez vos missions.',
                      accentColor: oc.success,
                      onTap: () => _selectMode(ActiveMode.provider),
                    ),

                    const SizedBox(height: 40),

                    // --- Appearance section ---
                    Text(
                      'Apparence',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choisissez le thème de l\'application.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: oc.secondaryText,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _ThemeOption(
                      label: 'Système',
                      subtitle: 'Suit les préférences de votre appareil',
                      icon: Icons.brightness_auto_outlined,
                      selected: themeMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                    const SizedBox(height: 10),
                    _ThemeOption(
                      label: 'Clair',
                      subtitle: 'Toujours en mode clair',
                      icon: Icons.light_mode_outlined,
                      selected: themeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    const SizedBox(height: 10),
                    _ThemeOption(
                      label: 'Sombre',
                      subtitle: 'Toujours en mode sombre',
                      icon: Icons.dark_mode_outlined,
                      selected: themeMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode card
// ---------------------------------------------------------------------------

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.isActive,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final ActiveMode mode;
  final bool isActive;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.06)
              : oc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? accentColor : oc.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isActive ? accentColor : oc.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isActive)
              Icon(Icons.check_circle_rounded, color: accentColor, size: 24)
            else
              Icon(Icons.circle_outlined, color: oc.border, size: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme option tile
// ---------------------------------------------------------------------------

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? oc.primary.withValues(alpha: 0.06) : oc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? oc.primary : oc.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? oc.primary : oc.icons),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected ? oc.primary : oc.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
                        ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: oc.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
