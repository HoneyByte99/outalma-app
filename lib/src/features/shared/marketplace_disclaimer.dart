import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Reusable trust/safety notice: Outalma only connects clients and independent
/// providers — any agreement and payment happens directly between the two
/// parties, outside the app and at their own risk. Shown at booking time, on
/// the service detail, and in onboarding/CGU.
class MarketplaceDisclaimer extends StatelessWidget {
  const MarketplaceDisclaimer({super.key, this.dense = false});

  /// When true, renders as plain inline text (no card) for tight spots.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final text = Text(
      l10n.marketplaceDisclaimer,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: oc.secondaryText, height: 1.4),
    );

    if (dense) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: oc.secondaryText),
          const SizedBox(width: 6),
          Expanded(child: text),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: oc.secondaryText.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: oc.secondaryText),
          const SizedBox(width: 8),
          Expanded(child: text),
        ],
      ),
    );
  }
}
