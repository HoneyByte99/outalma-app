# TASK_LOG — Batch 1 : Bugs Critiques

Branch: `fix/qe-critical-bugs` (depuis `ci/verify-test-pipeline`)
Date: 2026-05-21

---

## Statut global

| Bug | Statut | Détail |
|-----|--------|--------|
| C1 — Null-bang `totalPrice` | ❌ BLOQUÉ | Fichier cible inexistant |
| C2 — Boucle infinie chat `initState` | ❌ BLOQUÉ | Fichier cible inexistant |
| C3 — Priorité opérateur `creditCardType` | ❌ BLOQUÉ | Fichier cible inexistant |
| C4 — `setState` après dispose `PolylineMap` | ❌ BLOQUÉ | Fichier cible inexistant |

---

## 🚨 ESCALADE REQUISE — Fichiers cibles absents

### Problème

Les 4 fichiers référencés dans `CURRENT_TASK.md` n'existent pas dans le workspace :

```
lib/booking/booking_pay/booking_pay_widget.dart       → ABSENT
lib/messages/chat/chat_widget.dart                    → ABSENT
lib/flutter_flow/custom_functions.dart                → ABSENT
lib/custom_code/widgets/polyline_map.dart             → ABSENT
```

Ces chemins correspondent à une architecture **FlutterFlow** (génération automatique de code).

Le projet actuel dans `~/clawd/projects/outalma/outalma-app/lib/` utilise une architecture **Flutter custom** :

```
lib/src/features/booking/booking_request_sheet.dart   ← booking
lib/src/features/chat/chat_page.dart                  ← chat
lib/src/features/service/service_zones_map.dart       ← map
(pas d'équivalent custom_functions)
```

### Vérifications effectuées

- `find` exhaustif sur tout `lib/` → aucun des 4 fichiers
- `grep` sur `totalPrice`, `messagesCount`, `creditCardType`, `PolylineMap` → aucun match
- Les fichiers analogues existants (`booking_request_sheet.dart`, `chat_page.dart`) **ne contiennent pas les patterns de bugs décrits** — le code est propre sur ces points

### Décision requise par le Director

**Option A** : Mettre à jour `CURRENT_TASK.md` avec les vrais chemins et patterns de bugs dans l'architecture actuelle `lib/src/`.

**Option B** : Fournir le dépôt FlutterFlow si les bugs visaient une version parallèle du projet.

**Option C** : Annuler le Batch 1 — les bugs C1–C4 n'existent pas dans la codebase courante.

---

## Commits produits

Aucun (blocage avant le premier fix).

---

_Rapporté par outalma-dev-worker-01 — 2026-05-21_
