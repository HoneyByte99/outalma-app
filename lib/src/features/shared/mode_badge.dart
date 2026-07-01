import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/user/user_providers.dart';
import '../../domain/enums/active_mode.dart';
import '../auth/auth_prompt.dart';

/// Persistent indicator of the user's active mode (client/provider).
///
/// Drop this into the `actions:` of any top-level [AppBar]. Tapping it toggles
/// the mode with a quick fade, haptic feedback, and a snackbar confirmation.
/// The color reflects the mode (primary = client, success-green = provider)
/// and animates smoothly during transitions.
class ModeBadge extends ConsumerStatefulWidget {
  const ModeBadge({super.key});

  @override
  ConsumerState<ModeBadge> createState() => _ModeBadgeState();
}

class _ModeBadgeState extends ConsumerState<ModeBadge> {
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final activeMode = ref.watch(activeModeProvider);
    final isClient = activeMode == ActiveMode.client;
    final label = isClient ? l10n.modeClient : l10n.modeProvider;
    final color = _switching ? oc.icons : (isClient ? oc.primary : oc.success);

    return Semantics(
      button: true,
      label: '$label. ${l10n.modeBadgeTapToSwitch}',
      child: GestureDetector(
        onTap: _switching ? null : () => _toggle(isClient, l10n),
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
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                child: Text(label),
              ),
              const SizedBox(width: AppSpacing.xs),
              _switching
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: oc.icons,
                      ),
                    )
                  : Icon(Icons.swap_horiz_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(bool isClient, AppLocalizations l10n) async {
    if (_switching) return;
    // Switching to provider mode is a login-gated action. A guest (never
    // authenticated, always in client mode) is nudged to sign in instead.
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) {
      await showAuthPrompt(
        context,
        reason: l10n.providerModeRequiresLogin,
        redirect: GoRouterState.of(context).uri.toString(),
      );
      return;
    }
    setState(() => _switching = true);
    await HapticFeedback.selectionClick();
    final newMode = isClient ? ActiveMode.provider : ActiveMode.client;
    try {
      await ref.read(authNotifierProvider.notifier).switchMode(newMode);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorGeneral),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _switching = false);
    }
    if (!mounted) return;
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
