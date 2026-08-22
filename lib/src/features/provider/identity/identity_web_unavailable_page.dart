import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';

/// Shown where the capture entry would be, on web (AC-C04, design section 8).
///
/// The capture is mobile only (D2): `camera` and ML Kit have no web support. The
/// route still exists and renders this, so a shared link never lands on a
/// missing page (E15), and no capture screen is ever reachable. Nothing throws.
class IdentityWebUnavailablePage extends StatelessWidget {
  const IdentityWebUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.identityGuideTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_iphone_rounded,
                  size: 48,
                  color: oc.secondaryText,
                ),
                const SizedBox(height: AppSpacing.l),
                Text(
                  l10n.identityWebOnlyMobile,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.l),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.identityWebBack),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
