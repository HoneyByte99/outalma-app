# Design Tokens v2 — Phase A.1

> Date : mai 2026
> Origine : UX review externe + audit interne. Objectif : passer de "7/10 moderne mais dense" à "8.5/10 calme et premium".

## Changements résumés

| Token | Avant (v1) | Après (v2) | Raison |
|---|---|---|---|
| `dark.background` | `#0A1A24` | `#121821` | Désaturation : moins "tech terminal", plus neutre |
| `dark.surface` | `#122230` | `#1A2029` | Idem, plus chaud |
| `dark.cardSurface` | `#162838` | `#1F252F` | Élévation perçue plus douce mais nette |
| `dark.surfaceVariant` | `#1A3040` | `#252C37` | Cohérent avec la nouvelle base |
| `dark.border` | `#2A4555` | `#2B323D` | Moins contrasté → bords moins agressifs |
| `dark.inputFill` | `#0F1E28` | `#181E27` | Plus proche du background pour moins de tension |
| `dark.primaryText` | `#E2EEF4` | `#E5ECF1` | Légèrement plus neutre (moins bleu) |
| `dark.secondaryText` | `#7AA3B5` | `#95A7B5` | **+15% luminosité** : moins de fatigue de lecture |
| `dark.icons` | `#5A8090` | `#7A8B98` | Plus lisible |
| `dark.shadow` | `#1A000000` | `#33000000` | Ombre plus marquée pour mieux séparer les surfaces |

Le **light mode est inchangé** — il n'avait pas le problème "trop tech" du dark mode.

## Nouvelle échelle Typography

Hiérarchie nettement plus marquée entre niveaux. Avant : `titleLarge` (bold 16) et `titleMedium` (500 16) avaient la même taille, juste un poids différent. Après : différenciation taille + poids + letter-spacing.

| Style | Avant | Après | Usage canonique |
|---|---|---|---|
| `headlineLarge` | 28 bold | 30 w700 (-0.3) | Hero page (sign-up, accueil) |
| `headlineMedium` | 24 bold | 24 w700 (-0.2) | Title de section principale |
| `headlineSmall` | 20 bold | 20 w700 | Title de sous-section |
| `titleLarge` | 16 bold | **17 w700** | Titre dominant d'une card |
| `titleMedium` | 16 w500 | **15 w600** | Sous-titre d'une card |
| `titleSmall` | 14 w500 | 13 w600 | Étiquette section interne |

## Nouvelle échelle Spacing

`lib/src/app/app_spacing.dart` — référentiel unique :

```
xs   =  4   tight inline gaps
s    =  8   icon ↔ label
m    = 12   default inter-element
l    = 16   card padding, section margin
xl   = 20   between cards
xxl  = 24   between major sections
xxxl = 32   page-level breathing
```

Border radii :
- `radiusSmall = 8` (chips, badges)
- `radiusMedium = 12` (boutons, inputs)
- `radiusLarge = 16` (cards)
- `radiusXLarge = 20` (modals, sheets)

Touch targets : minimum 44pt (iOS HIG, Material Design 48dp accommodated).

## Adoption

Cette v2 est **rétrocompatible** : les couleurs vivent dans `OutalmaColors` (ThemeExtension) donc tous les sites qui utilisent `context.oc.background` etc. récupèrent les nouvelles valeurs sans changement.

Pour le spacing, les sites existants utilisent encore des constantes inline (`EdgeInsets.all(12)`). À mesure des passes A.4-A.9, on remplacera progressivement par `AppSpacing.m`, `AppSpacing.l`, etc. Pas un grand bang.

## Critère de validation

Lancement de l'app sur simulateur après changement : la sensation doit être **plus calme** et **moins "tech terminal"**. Si ce n'est pas le cas, on ajuste les couleurs encore.
