# TASK_LOG — Batch 1 : Bugs Critiques

Branch: `fix/qe-critical-bugs`
Last update: 2026-05-21

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
