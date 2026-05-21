import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/user/user_providers.dart';
import '../../domain/enums/active_mode.dart';

/// Persistent indicator of the user's active mode (client/provider).
///
/// Drop this into the `actions:` of any top-level [AppBar]. Tapping it toggles
/// the mode with a quick fade, haptic feedback, and a snackbar confirmation.
/// The color reflects the mode (primary = client, success-green = provider)
/// and animates smoothly during transitions.
class ModeBadge extends ConsumerWidget {
  const ModeBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final activeMode = ref.watch(activeModeProvider);
    final isClient = activeMode == ActiveMode.client;
    final label = isClient ? l10n.modeClient : l10n.modeProvider;
    final color = isClient ? oc.primary : oc.success;

    return Semantics(
      button: true,
      label: '$label. ${l10n.modeBadgeTapToSwitch}',
      child: GestureDetector(
        onTap: () => _toggle(context, ref, isClient, l10n),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(
            vertical: AppSpacing.s,
            horizontal: AppSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.xs + 1,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style:
                    Theme.of(context).textTheme.labelMedium!.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                child: Text(label),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.swap_horiz_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool isClient,
    AppLocalizations l10n,
  ) async {
    await HapticFeedback.selectionClick();
    final newMode = isClient ? ActiveMode.provider : ActiveMode.client;
    try {
      await ref.read(authNotifierProvider.notifier).switchMode(newMode);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorGeneral)),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newMode == ActiveMode.client
              ? l10n.modeClientActivated
              : l10n.modeProviderActivated,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
