import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../application/identity/identity_trust_providers.dart';
import '../../domain/enums/identity_trust_status.dart';

/// The public trust signal of a provider: verified, under way, or not verified.
///
/// Four display situations, not three, and the distinction matters:
///
///  - projection not read yet, or read failed  -> NOTHING. An empty slot.
///  - read, document absent                    -> "Identity not verified"
///  - read, pending                            -> "Verification under way"
///  - read, verified                           -> "Verified profile"
///
/// The first line is the one that is easy to get wrong. Showing "not verified"
/// while the read is still in flight publishes a false claim about a real
/// person: a provider who did the three photos and waited 48 hours would be
/// shown as unverified to a client every time the network coughs. Showing
/// nothing costs the same code and says nothing untrue.
class IdentityTrustSignal extends ConsumerWidget {
  const IdentityTrustSignal({
    super.key,
    required this.providerId,
    this.compact = false,
  });

  final String providerId;

  /// Icon only, verified state only. Used on grid cards, where a negative
  /// mention in icon form would be undecipherable. Never use it for a state
  /// the reader has to guess.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(identityTrustProvider(providerId));

    // Loading and error collapse to the same nothing, on purpose.
    final status = async.hasValue ? async.value : null;
    if (!async.hasValue) return const SizedBox.shrink();

    if (compact) {
      if (status != IdentityTrustStatus.verified) {
        return const SizedBox.shrink();
      }
      final l10n = AppLocalizations.of(context)!;
      return Semantics(
        label: l10n.trustVerifiedLabel,
        child: Icon(
          Icons.verified_rounded,
          size: 16,
          color: context.oc.trustVerifiedText,
        ),
      );
    }

    return _TrustPill(status: status);
  }
}

/// The full form: icon plus label, always on its own line.
///
/// Never inline with a name: measured at 375 px, a full mention next to a name
/// leaves two characters for the name itself.
class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.status});

  final IdentityTrustStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;

    // Two colours per state, and they are not interchangeable: the pill is
    // tinted from the ACCENT, the icon and the label use the darkened token.
    // That pairing is what was measured (4.73:1 and 5.76:1); tinting the pill
    // from the darkened token instead would still pass, at 4.56:1 and 5.35:1,
    // but it is not what the design proved, and the margin is thinner.
    late final Color color;
    late final Color? tint;
    late final IconData icon;
    late final String label;
    late final bool filled;

    switch (status) {
      case IdentityTrustStatus.verified:
        color = oc.trustVerifiedText;
        tint = oc.success;
        icon = Icons.verified_rounded;
        label = l10n.trustVerifiedLabel;
        filled = true;
      case IdentityTrustStatus.pending:
        color = oc.trustPendingText;
        tint = oc.warning;
        icon = Icons.schedule_rounded;
        label = l10n.trustPendingLabel;
        filled = true;
      case null:
        // Not an affirmation, so not a pill: an absence of verification is an
        // absence, and dressing it as a coloured chip would turn every provider
        // into an alert at launch, when almost nobody is verified yet.
        color = oc.secondaryText;
        tint = null;
        icon = Icons.shield_outlined;
        label = l10n.trustUnverifiedLabel;
        filled = false;
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        // Wraps rather than truncates: at a 200 percent text scale a truncated
        // meaning-bearing label would fail the accessibility bar, and this one
        // carries the whole message.
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    if (!filled) return content;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: tint!.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: content,
    );
  }
}
