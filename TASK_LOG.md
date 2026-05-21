# TASK_LOG — Batch 1 : Bugs Critiques

Branch: `fix/qe-critical-bugs` (UX batch on `fix/ux-batch1`)
Last update: 2026-05-21

---

## Batch UX-1 — Fixes prioritaires UI/UX

Branche : `fix/ux-batch1` (depuis `fix/qe-critical-bugs`)

| Fix | Statut | Commit | Détail |
|-----|--------|--------|--------|
| UX-1 — Sheet de réservation non-scrollable clavier ouvert | ✅ | `16e5f9a` | `booking_request_sheet.dart` : contenu enveloppé dans `SingleChildScrollView` + `ConstrainedBox(maxHeight: 85% * screen height)`. `viewInsets.bottom` appliqué en padding bas du scroll. Les boutons nav restent atteignables sur iPhone SE clavier ouvert. |
| UX-2 — `SafeArea(top: false)` sur les pages Auth | ✅ | `2f45367` | `sign_in_page.dart` + `sign_up_page.dart` : `top: false` → `top: true` pour éviter chevauchement Dynamic Island / notch sur iPhone 14 Pro+. |
| UX-3 — Loader CTA auth provoque layout shift | ✅ | `2f45367` | `sign_in_page.dart` : `ElevatedButton` toujours monté, `onPressed: _loading ? null : _ctaAction()`, child swap entre `Text` et `SizedBox(20×20, CircularProgressIndicator(strokeWidth: 2, color: white))`. Plus de saut visuel. |
| UX-4 — `_PickerButton` sans feedback tactile | ✅ | `16e5f9a` | `booking_request_sheet.dart` : `GestureDetector` remplacé par `Material(transparent) + InkWell(borderRadius: 12)`, ripple visible sur tap des tuiles date / heure. |
| UX-5 — Prix sans séparateur de milliers | ✅ | `fb143af` | Nouveau `lib/src/core/utils/format_utils.dart` exposant `formatPriceFromCents(int)` basé sur `NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0)`. 4 sites display mis à jour : `service_detail_page.dart` (~L65), `home_page.dart` (~L902), `public_provider_profile_page.dart` (~L341), `provider_dashboard_page.dart` (~L312). `service_form_page.dart` non touché : valeur brute liée à un `TextField` d'édition, pas un display. |

### Vérification UX batch

- `dart analyze` sur tous les fichiers modifiés → **No issues found**.
- Pas de test runtime device exécuté (hors scope subagent ; revue visuelle à faire sur iPhone SE + iPhone 14 Pro).

---

---

## Statut global (Batch 1 — itération 2, chemins corrigés vers `lib/src/`)

| Bug | Statut | Commit | Détail |
|-----|--------|--------|--------|
| C1 — `MAPS_API_KEY` jamais résolu en dev | ✅ | `3e63a93` | Rename `PLACES_API_KEY` → `MAPS_API_KEY`, assert dans `GeocodingService`, `scripts/run.sh` ajouté, CI + docs alignés. |
| C2 — iOS silencieux si Secrets.xcconfig absent | ✅ | `ab846bf` | `fatalError` en Debug si vide, `NSLog` warning en Release. `Secrets.xcconfig.example` déjà présent, format conservé. |
| C3 — `_markRead` à chaque frame dans le chat | ✅ | `20851ef` | Retiré du `addPostFrameCallback` du builder ; remplacé par `ref.listen` qui ne déclenche `_markRead` que si la longueur de la liste de messages change. |
| C4 — Upload voice cassé sur natif | ✅ | `a30bd71` | `kIsWeb ? http.get : File(path).readAsBytes()`. Import `dart:io show File` ajouté (déjà utilisé ailleurs dans le repo, compatible web build). |

---

## Verification

- `flutter analyze` sur `lib/src/features/chat/chat_page.dart` +
  `lib/src/data/services/geocoding_service.dart` → **No issues found**.
- iOS Swift / CI YAML / Markdown : pas d'analyzer ; relecture manuelle.
- Pas de test runtime device exécuté (hors scope subagent).

---

## Notes pour le director

- `scripts/run.sh` exige `MAPS_API_KEY` en variable d'env ; documenter dans le README si pas déjà fait.
- Le commit `375bc7b` (`chore(wip)`) regroupe deux WIP non liés (Nominatim fallback dans `geocoding_service.dart` + RatingRow layout dans `home_page.dart`) qui traînaient unstaged sur la branche avant cette session — à reviewer / valider en QA.
- Aucune clé secrète n'a été commitée. `Secrets.xcconfig` reste gitignored.

---

## Itération précédente (archivée)

L'itération précédente du Batch 1 ciblait des fichiers FlutterFlow inexistants
(`booking_pay_widget.dart`, `polyline_map.dart`, etc.). Ces chemins étaient
erronés ; l'architecture réelle est `lib/src/...`. Cf. commit `c13e1ff` pour
l'historique d'escalade.

---

_Rapporté par outalma-dev-worker — 2026-05-21_
