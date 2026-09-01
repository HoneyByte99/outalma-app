import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../application/identity/identity_trust_providers.dart';
import '../../domain/enums/identity_trust_status.dart';

/// How the signal renders.
enum TrustSignalStyle {
  /// Icon plus label, on its own line. The full three states.
  pill,

  /// A badge beside a name, on a listing card, a service header or the public
  /// profile. All THREE resolved states render, each with its own glyph, so a
  /// client knows BEFORE opening a listing rather than after.
  badge,
}

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
    this.style = TrustSignalStyle.pill,
  });

  final String providerId;
  final TrustSignalStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(identityTrustProvider(providerId));

    // Loading and error collapse to the same nothing, on purpose.
    final status = async.hasValue ? async.value : null;
    if (!async.hasValue) return const SizedBox.shrink();

    if (style == TrustSignalStyle.badge) {
      return _TrustBadge(status: status);
    }

    return _TrustPill(status: status);
  }
}

/// A badge beside a name. Both RESOLVED states render, because a client who
/// cannot tell a verified provider from an unverified one without opening the
/// listing has to open every listing.
///
/// `pending` has its OWN glyph, not the muted one. It used to fold in, on the
/// argument that sixteen pixels cannot carry "verification under way" while the
/// pill could. That stopped holding the day the badge became the only trust
/// signal on the public profile: a provider halfway through verification would
/// have looked exactly like one who never tried. Each state also keeps its own
/// accessibility label, so none is ever announced as another.
///
/// Contrast, measured on `cardSurface` (budget line A1, 3:1 for a meaning
/// bearing interface element):
///   verified, light  trustVerifiedText #00795A on cardSurface #FFFFFF -> 5.41:1
///   verified, dark   trustVerifiedText #2DD17A on cardSurface #1F252F -> 7.71:1
///   muted,    light  secondaryText     #5C7A8A on cardSurface #FFFFFF -> 4.56:1
///   muted,    dark   secondaryText     #95A7B5 on cardSurface #1F252F -> 6.21:1
/// Meaning never rides on the tint alone: the icon changes with the state (A3).
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.status});

  final IdentityTrustStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final verified = status == IdentityTrustStatus.verified;

    final label = switch (status) {
      IdentityTrustStatus.verified => l10n.trustVerifiedLabel,
      IdentityTrustStatus.pending => l10n.trustPendingLabel,
      null => l10n.trustUnverifiedLabel,
    };

    // Three states, three glyphs. `pending` used to fold into the muted state,
    // which left two visual states for three accessibility labels: a provider
    // halfway through verification looked exactly like one who never tried.
    // Now that the badge is the ONLY trust signal on the public profile, the
    // pill having been retired from it, that fold would have been a real loss.
    // No new colour pair: `secondaryText` on `cardSurface` is already measured
    // for A1, and meaning still rides on the shape, never on the tint alone.
    final icon = switch (status) {
      IdentityTrustStatus.verified => Icons.verified_rounded,
      IdentityTrustStatus.pending => Icons.schedule_rounded,
      null => Icons.shield_outlined,
    };

    return Semantics(
      label: label,
      child: Icon(
        icon,
        size: 15,
        color: verified ? oc.trustVerifiedText : oc.secondaryText,
      ),
    );
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
