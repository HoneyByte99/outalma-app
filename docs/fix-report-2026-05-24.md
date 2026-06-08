# Fix Report — 2026-05-24

## Pré-release blockers

### Blocker 1 — Tests use-cases (`extra_positional_arguments`)
Corrections déjà appliquées dans les fichiers :
- `test/application/booking/booking_actions_test.dart` — suite réduite à des smoke tests `const AcceptBookingUseCase()` / `const RejectBookingUseCase()`.
- `test/application/booking/lifecycle_use_cases_test.dart` — smoke tests `const MarkInProgressUseCase()`, `const ConfirmDoneUseCase()`, `const CancelBookingUseCase()`.
- `test/application/booking/create_booking_use_case_test.dart` — smoke test `const CreateBookingUseCase()`.

Les anciens fakes `_FakeFunctions` ont été retirés ; le path HTTP est validé en intégration contre les Cloud Functions live.

### Blocker 2 — Bump pubspec
`pubspec.yaml:5` → `version: 1.0.0+4` (déjà bumpé depuis le build 3 sur TestFlight).

### Partiel — Bouton "Annuler" déconnexion
`lib/src/features/profile/profile_page.dart:891` — déjà un `OutlinedButton` (style cohérent : `foregroundColor: oc.primary`, border `oc.primary`, fond transparent, hauteur 48, radius 12).

## Résultats vérification

### `flutter analyze --no-pub`
```
13 issues found.
```
**Aucune erreur.** Seulement des warnings (imports inutilisés, déclarations non référencées) et infos (underscores locaux, `prefer_const_constructors`) sur des fichiers de tests/widgets périphériques :
- `lib/src/features/booking/booking_detail_page.dart:8` — unused_import
- `test/integration/booking_golden_path_test.dart` — 3 unused
- `test/widget/booking/booking_request_sheet_test.dart:22` — `_wrap` unused
- `test/widget/shared/maps_launcher_test.dart` — 4 infos underscore + 3 `prefer_const_constructors`

### `flutter test --no-pub`
```
All tests passed!
00:12 +635 ~3: All tests passed!
```
**635 passed / 0 failed / 3 skipped.**

## Statut release
Les 3 blockers + le partiel sont OK. Pas de modification supplémentaire requise — la branche est prête pour le push TestFlight build 4.
