import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';

// ===========================================================================
// TODO_CONSENT_TEXT_TO_VALIDATE
// ---------------------------------------------------------------------------
// BROUILLON, A VALIDER PAR AMATH / juriste avant mise en ligne.
//
// Les six mentions du consentement (cles l10n `identityGuideMention1..6`) et le
// libelle de la case (`identityConsentCheckbox`) sont un BROUILLON derive de la
// note _docs/CONFORMITE-VERIFICATION-MVP-2026-08.md section 1 et de la
// proposition du design (section 9). Ce texte est repris tel quel dans le
// dossier CDP : il n'a PAS de valeur juridique tant qu'Amath et un juriste ne
// l'ont pas valide.
//
// Deux points portent un risque juridique et non un choix de style :
//   - Mentions 4 et 5 : conservation jusqu'a la suppression du compte (decision
//     D4), derogation assumee a la ligne S11. A confirmer avec la CDP.
//   - Mention 3 : "seules les personnes habilitees" doit rester exacte si le
//     perimetre des roles habilites change.
//
// NE PAS presenter ce texte comme valide. Marqueur volontairement visible en
// revue de code.
// ===========================================================================

/// The information guide and the consent gate, on a single scrolling screen
/// (design section 4). The text is legal, so it is not sliced into reassuring
/// cards: one column, scrollable, readable at a 200 percent text scale (A6).
///
/// The first photo is unreachable until the consent box is ticked (AC-C03):
/// [onStart] is only wired to the button once [_consented] is true, and the
/// button is disabled with a helper line otherwise, never a mute greyed button.
class IdentityGuidePage extends StatefulWidget {
  const IdentityGuidePage({super.key, required this.onStart, this.onOpenTerms});

  /// Opens the capture journey. Called only after consent (AC-C03).
  final VoidCallback onStart;

  /// Opens the terms of use from the checkbox label. Optional so the widget is
  /// trivially testable without a router.
  final VoidCallback? onOpenTerms;

  @override
  State<IdentityGuidePage> createState() => _IdentityGuidePageState();
}

class _IdentityGuidePageState extends State<IdentityGuidePage> {
  // Consent is NOT remembered between two openings of the guide (E15): a fresh
  // decision every time the screen is shown.
  bool _consented = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final textTheme = Theme.of(context).textTheme;

    final mentions = <String>[
      l10n.identityGuideMention1,
      l10n.identityGuideMention2,
      l10n.identityGuideMention3,
      l10n.identityGuideMention4,
      l10n.identityGuideMention5,
      l10n.identityGuideMention6,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.identityGuideTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.identityGuideTitle, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.m),

              // The three steps, so the duration expectation is set up front.
              // A Wrap so they drop to a column at a 200 percent scale (A6).
              Wrap(
                spacing: AppSpacing.l,
                runSpacing: AppSpacing.s,
                children: [
                  _Step(
                    icon: Icons.badge_outlined,
                    label: l10n.identityGuideStepRecto,
                  ),
                  _Step(
                    icon: Icons.flip_to_back_outlined,
                    label: l10n.identityGuideStepVerso,
                  ),
                  _Step(
                    icon: Icons.face_outlined,
                    label: l10n.identityGuideStepSelfie,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),

              // What is happening and why, in plain terms.
              Text(l10n.identityGuideWhy, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.s),
              Text(l10n.identityGuideNext, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.s),
              Text(l10n.identityGuideHave, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.l),

              // The six mandatory mentions (AC-C02), on `surfaceVariant` and in
              // `primaryText`: `secondaryText` only holds 4.5:1 on white
              // (design section 1), so a tinted block must use primary text.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.l),
                decoration: BoxDecoration(
                  color: oc.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final mention in mentions) ...[
                      Text(
                        mention,
                        style: textTheme.bodyMedium?.copyWith(
                          color: oc.primaryText,
                        ),
                      ),
                      if (mention != mentions.last)
                        const SizedBox(height: AppSpacing.s),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),

              // The consent box: 48 point target (AppSpacing.minTouchTarget),
              // clickable label, link to the terms of use.
              _ConsentCheckbox(
                value: _consented,
                onChanged: (v) => setState(() => _consented = v),
                onOpenTerms: widget.onOpenTerms,
              ),
              const SizedBox(height: AppSpacing.l),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _consented ? widget.onStart : null,
                  child: Text(l10n.identityGuideStart),
                ),
              ),
              if (!_consented) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  l10n.identityGuideConsentHint,
                  style: textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: oc.primaryText),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    this.onOpenTerms,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.identityConsentCheckbox,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (onOpenTerms != null)
                    TextButton(
                      onPressed: onOpenTerms,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        l10n.identityConsentTermsLink,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
