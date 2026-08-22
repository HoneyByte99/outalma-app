import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';

/// Calm, centered empty-state block: an icon, a message, and an optional action.
///
/// Presentational and stateless so callers own the copy and the action. Reused
/// across discovery surfaces to keep empty states consistent (design bar:
/// "good loading, empty, and error states", reusable components).
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: oc.icons),
            const SizedBox(height: AppSpacing.l),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.l),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
