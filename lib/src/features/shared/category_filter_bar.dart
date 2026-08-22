import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../domain/enums/category_id.dart';
import '../../../l10n/app_localizations.dart';
import 'category_icon.dart';

/// Horizontal, scrollable task filter shown on the client home.
///
/// A leading "Tout" entry (value == `null`) shows every published listing and is
/// the default selection. The task order follows the curated
/// [CategoryId.clientFilterCategories] list (demand + affinity), never the raw
/// enum order, so the most-requested everyday tasks come first.
///
/// Stateless and Riverpod-free on purpose: the caller owns [selected] and
/// reacts to [onSelected]. This keeps the bar trivially testable and golden-able.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CategoryId? selected;
  final ValueChanged<CategoryId?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final items = <(String label, IconData icon, CategoryId? value)>[
      (l10n.categoryAll, Icons.apps_outlined, null),
      ...CategoryId.clientFilterCategories.map(
        (c) => (c.labelOf(l10n), c.icon, c),
      ),
    ];

    return SizedBox(
      height: AppSpacing.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (context, i) {
          final (label, icon, value) = items[i];
          return CategoryFilterChip(
            icon: icon,
            label: label,
            isActive: selected == value,
            onTap: () => onSelected(value),
          );
        },
      ),
    );
  }
}

/// A single pill in the [CategoryFilterBar]. Selected: filled primary with
/// on-primary text/icon. Unselected: surface with border and primary text.
class CategoryFilterChip extends StatelessWidget {
  const CategoryFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final color = isActive ? oc.surface : oc.primaryText;
    return Semantics(
      label: label,
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? oc.primary : oc.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
            border: Border.all(color: isActive ? oc.primary : oc.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
