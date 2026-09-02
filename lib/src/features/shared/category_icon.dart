import 'package:flutter/material.dart';
import '../../domain/enums/category_id.dart';
import '../../../l10n/app_localizations.dart';

extension CategoryIdIcon on CategoryId {
  IconData get icon => switch (this) {
    CategoryId.menage => Icons.cleaning_services_outlined,
    CategoryId.plomberie => Icons.plumbing_outlined,
    CategoryId.jardinage => Icons.yard_outlined,
    CategoryId.electricite => Icons.electrical_services_outlined,
    CategoryId.peinture => Icons.format_paint_outlined,
    CategoryId.bricolage => Icons.handyman_outlined,
    CategoryId.gardeEnfants => Icons.child_care_outlined,
    CategoryId.cuisine => Icons.restaurant_outlined,
    CategoryId.repassage => Icons.iron_outlined,
  };
}

extension CategoryIdL10n on CategoryId {
  String labelOf(AppLocalizations l10n) => switch (this) {
    CategoryId.menage => l10n.categoryMenage,
    CategoryId.plomberie => l10n.categoryPlomberie,
    CategoryId.jardinage => l10n.categoryJardinage,
    CategoryId.electricite => l10n.categoryElectricite,
    CategoryId.peinture => l10n.categoryPeinture,
    CategoryId.bricolage => l10n.categoryBricolage,
    CategoryId.gardeEnfants => l10n.categoryGardeEnfants,
    CategoryId.cuisine => l10n.categoryCuisine,
    CategoryId.repassage => l10n.categoryRepassage,
  };
}
