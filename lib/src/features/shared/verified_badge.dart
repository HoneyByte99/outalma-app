import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';

/// Trust signal badge — displayed next to a provider's name when their
/// profile is "verified" (phone confirmed + provider profile completed).
///
/// Sized to sit inline with a [titleLarge] heading.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false});

  /// `true` to omit the text label and only show the icon (use inline next
  /// to a provider name on small cards).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final color = oc.success;

    if (compact) {
      return Tooltip(
        message: l10n.verifiedBadgeLabel,
        child: Icon(
          Icons.verified_rounded,
          size: 16,
          color: color,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            l10n.verifiedBadgeLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}
