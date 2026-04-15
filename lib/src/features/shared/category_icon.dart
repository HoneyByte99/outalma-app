import 'package:flutter/material.dart';
import '../../domain/enums/category_id.dart';

extension CategoryIdIcon on CategoryId {
  IconData get icon => switch (this) {
    CategoryId.menage => Icons.cleaning_services_outlined,
    CategoryId.plomberie => Icons.plumbing_outlined,
    CategoryId.jardinage => Icons.yard_outlined,
    CategoryId.electricite => Icons.electrical_services_outlined,
    CategoryId.peinture => Icons.format_paint_outlined,
    CategoryId.bricolage => Icons.handyman_outlined,
    CategoryId.gardeEnfants => Icons.child_care_outlined,
  };
}
