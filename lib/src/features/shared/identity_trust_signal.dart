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
  /// profile. CLIENT surfaces only, and it renders ONLY when the provider is
  /// verified: see [_TrustBadge] for why the two other states render nothing.
  badge,
}

/// The public trust signal of a provider: verified, under way, or not verified.
///
/// The two styles answer two different questions, so they do NOT show the same
/// thing, and that asymmetry is deliberate:
///
///  - [TrustSignalStyle.badge], on a CLIENT surface, answers "can I trust this
///    provider". Only `verified` says anything useful there, so only `verified`
///    renders. The rest is an empty slot.
///  - [TrustSignalStyle.pill] answers "where do I stand", which is a PROVIDER
///    question, so it keeps the three states.
///
/// One rule holds for both: while the projection has not been read, or if the
/// read failed, the slot is EMPTY. Showing "not verified" while the read is
/// still in flight publishes a false claim about a real person: a provider who
/// did the three photos and waited 48 hours would be shown as unverified to a
/// client every time the network coughs. Showing nothing costs the same code
/// and says nothing untrue.
class IdentityTrustSignal extends ConsumerWidget {
  /// [style] is REQUIRED, with no default. `pill` has no production caller
  /// since the public profile moved to the badge, so a default would hand the
  /// full-width pill to any future site that forgot to choose, on a screen that
  /// never allowed for it.
  const IdentityTrustSignal({
    super.key,
    required this.providerId,
    required this.style,
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

/// A badge beside a name, on a CLIENT surface. Renders ONLY when the provider
/// is verified; `pending` and `absent` render nothing at all.
///
/// This used to show three glyphs, one per state, on the argument that a client
/// who cannot tell a verified provider from an unverified one has to open every
/// listing. Two measurements killed that argument:
///
///  - The two extra glyphs were 15 px and label-less. At that size a clock and
///    a shield are not readable as "verification under way" and "not verified";
///    they read as decoration, so they did not in fact let a client tell the
///    states apart.
///  - Almost nobody is verified at launch. A muted glyph on every single card
///    is therefore the BACKGROUND, and the green check is one variation inside
///    a wall of grey. Removing the noise is what makes the check visible, which
///    is the entire point of a trust signal.
///
/// A trust signal is only ever positive. The absence of a badge says nothing
/// about the person, which is exactly right: `absent` means "we have no claim
/// to make", and `pending` is an internal state a client cannot act on. Neither
/// belongs on a surface where a client is choosing.
///
/// The provider still needs to know where they stand, and they do: their own
/// dashboard, their profile and the identity status screen each render that
/// state themselves. None of them goes through this widget.
///
/// Contrast, measured on `cardSurface` (budget line A1, 3:1 for a meaning
/// bearing interface element):
///   verified, light  trustVerifiedText #00795A on cardSurface #FFFFFF -> 5.41:1
///   verified, dark   trustVerifiedText #2DD17A on cardSurface #1F252F -> 7.71:1
/// Meaning does not ride on the tint alone (A3): the badge carries its own
/// accessibility label, and its presence, not its colour, is the message.
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.status});

  final IdentityTrustStatus? status;

  @override
  Widget build(BuildContext context) {
    if (status != IdentityTrustStatus.verified) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;

    return Semantics(
      label: l10n.trustVerifiedLabel,
      child: Icon(
        Icons.verified_rounded,
        size: 15,
        color: oc.trustVerifiedText,
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
