# QE Audit complémentaire — Outalma App
**Date** : 2026-05-24
**Scope** : Audit exhaustif des défauts résiduels (post-audit initial)
**Méthodologie** : passes ciblées sur i18n, navigation, gestion d'erreurs, UI/layout, formulaires, state, sécurité, perf
**Résultat global** : `flutter analyze` → 13 issues (12 warnings/info, 0 erreur)

Légende sévérité :
- 🔴 **blocker** : bug ou risque utilisateur direct
- 🟡 **warning** : fuite ressource, UX dégradée, dette
- 🔵 **cosmetic** : nettoyage, lint, dette mineure

---

## 1. Localisation / i18n

### 1.1 Strings hardcodées (français) hors `otp_lab` (debug-only)
- 🟡 `lib/src/app/router.dart:426,432` — `Text('Service introuvable')` dans `_ServiceEditLoader`.
  Doit utiliser une clé ARB (ex. `serviceNotFound`).
- 🟡 `lib/src/app/app.dart:98` — `SnackBar(content: Text('Vérification de l\'email échouée.'))` dans le boot global. Pas de clé ARB → s'affiche en français même en locale `en`.
- 🟡 `lib/src/features/provider/service_form_page.dart:664` — `hintText: 'Ville ou adresse'` codé en dur. Doit être `l10n.locationAddressHint` (déjà présent).
- 🟡 `lib/src/features/shared/phone_field.dart:360` — `hintText: 'Rechercher un pays…'` codé en dur.
- 🔵 `lib/src/features/auth/otp_lab/otp_lab_page.dart:264-357` — multiples strings FR codées (debug-only, route bloquée en release → tolérable).

### 1.2 Clés ARB non référencées (36 keys mortes)
Dans `lib/l10n/app_fr.arb` et `app_en.arb` mais jamais utilisées dans le code :
```
bookingStep3Title, chatSend, datetime, errorNetwork, homeSearchPrompt, km,
navNotifications, otpError, otpHint, otpPhoneError, otpResend, otpResendIn,
otpSubtitle, otpTitle, otpVerify, phoneAuthButton, phoneAuthOrWith,
phoneAuthSubtitle, phoneAuthTitle, phoneAuthWebUnsupported, phoneAuthWithNumber,
phoneNameButton, phoneNameError, phoneNameHint, phoneNameSubtitle, phoneNameTitle,
phoneOtpSentTo, photoAdd, placeholders, query, seconds, signUpVerificationResent,
tooltipProviderProfile, zoneAddTitle, zoneAddressHint, zoneEditTitle, zoneModify
```
La majorité semble être des reliquats du refactor "phone auth → email auth + phone OTP". Sévérité : 🔵 cosmetic — alourdit les ARB mais n'affecte pas runtime.

### 1.3 Parité FR/EN
- ✅ Les deux fichiers ont 499 lignes et un set de clés strictement identique (`diff` vide).

---

## 2. Navigation / Routing

### 2.1 PopScope / WillPopScope absents partout
- 🟡 Aucun `PopScope` ni `WillPopScope` dans tout `lib/`. Conséquences :
  - Sur Android, back button ferme directement la BottomSheet et tout formulaire avec saisie en cours → perte de données utilisateur.
  - Pages concernées particulièrement à risque : `booking_request_sheet.dart`, `service_form_page.dart`, `report_page.dart`, `review_form_page.dart`, `provider_onboarding_page.dart`, `chat_page.dart` (saisie message ou enregistrement audio en cours).
  - Au minimum sur `provider_onboarding_page` (multi-step) et `service_form_page` (long formulaire), un prompt « Abandonner les modifications ? » est attendu.

### 2.2 Routes
- ✅ Toutes les routes déclarées dans `router.dart` ont au moins un caller (vérifié via grep `AppRoutes.<name>`).
- ✅ Garde `redirect` couvre auth + provider-only routes.
- 🔵 `bookingDeepLink` (`/booking/:id`) et `bookingDetail` (`/bookings/:id`) coexistent. Bien documenté mais source de confusion potentielle pour les nouveaux devs.

### 2.3 Garde provider-only
- 🟡 `router.dart:142-148` bloque `/provider/onboarding`, `/provider/calendar`, `/provider/services` quand `mode == client`. Mais `/provider/inbox` (qui peut contenir des bookings provider sensibles) n'est protégé que par le shell branch mapping, pas par la garde de redirection. Un deep-link `/provider/inbox` en mode client passerait par le filtre `isProviderTab` → redirection vers `/home` ✅. Faux positif au final, mais à documenter.

---

## 3. Gestion d'erreurs

### 3.1 `AsyncValue.when` — états error tous gérés
- ✅ 19 occurrences de `.when` trouvées ; toutes ont un handler `error: (_, __)` dédié (vérifié par grep).
- 🔵 Cas d'erreur cachés derrière `const SizedBox.shrink()` (silent fail) :
  - `lib/src/features/booking/booking_detail_page.dart:236, 446`
  - `lib/src/features/profile/profile_page.dart:965`
  Acceptable pour des sous-widgets non-critiques (badges, sections facultatives), mais à logguer via Crashlytics au minimum.

### 3.2 Try/catch sur appels Firebase
- ✅ Toutes les Cloud Functions appelées depuis Dart sont wrappées (audit précédent).
- ✅ Auth flows (sign_in/sign_up/forgot_password) ont des branches `on FirebaseAuthException` + `catch (_)`.

### 3.3 Pas de `StreamBuilder` / `FutureBuilder`
- ✅ Confirmé : l'app utilise exclusivement Riverpod. Pas de risque de `ConnectionState.waiting` oublié.

### 3.4 Late / force unwrap
- ✅ Aucun `late <type>` non-final trouvé.
- ✅ Aucun pattern force-unwrap `.!` suspect en fin de ligne.

---

## 4. UI / Layout

### 4.1 Assets
- ✅ `assets/images/logo_icon_cropped.png` et `logo_outalma.png` présents et référencés correctement.
- ✅ `pubspec.yaml` déclare le dossier `assets/images/` → pas de fichier manquant détecté.

### 4.2 Image caching
- 🟡 `lib/src/features/provider/service_form_page.dart:829` — utilise `Image.network(...)` au lieu de `AppNetworkImage` / `CachedNetworkImage`. Recharge l'image à chaque rebuild + pas de cache disque. Toutes les autres pages utilisent `AppNetworkImage`. Incohérence à corriger.

### 4.3 Overflow potentiel
- Non trouvé de pattern évident (pas de `Row` sans `Expanded/Flexible` confirmé à risque sur texte long). À valider en QA manuelle sur écrans étroits.

### 4.4 `const` manquants
- 🔵 `prefer_const_constructors` signalé par analyzer uniquement dans `test/widget/shared/maps_launcher_test.dart` (3 occurrences). Code de prod OK.

---

## 5. Formulaires

### 5.1 `TextEditingController` non disposé
- 🔴 `lib/src/features/home/home_page.dart:269` — `nameController = TextEditingController()` créé dans `_saveCurrentLocation()` (dialog). **Jamais disposé**. Fuite mémoire chaque fois que l'utilisateur ouvre le dialog « Sauvegarder l'adresse ». Critique côté MVP car l'action peut être répétée.

### 5.2 Validation
- 🟡 Aucun `Form` + `validator:` dans `sign_in_page.dart` ni `sign_up_page.dart`. La validation est faite manuellement (`if (email.isEmpty || password.isEmpty)`). Conséquences :
  - Pas de feedback inline sur champ invalide (erreur via SnackBar uniquement).
  - Pas de validation format email côté client (Firebase renvoie `authErrorInvalidEmail` après aller-retour réseau).
  - Pas de validation longueur mot de passe avant submit sign-up (6 chars → géré côté Firebase, latence inutile).
- ✅ `service_form_page.dart` et `profile_page.dart` utilisent `validator:` correctement.

### 5.3 Keyboard dismiss
- ✅ `sign_in_page.dart:237` et `sign_up_page.dart:227` ont `FocusScope.of(context).unfocus()` via `GestureDetector`.
- 🟡 Manque sur : `booking_request_sheet.dart`, `service_form_page.dart`, `review_form_page.dart`, `report_page.dart`, `provider_onboarding_page.dart`, `chat_page.dart`, `home_page.dart` (search field). En particulier sur mobile, le clavier reste ouvert et masque les CTA.

---

## 6. State management (Riverpod)

### 6.1 Resets après logout
- ⚠️ À vérifier manuellement : pas d'audit ciblé sur le reset des `StateProvider` (ex. `locationFilterProvider`, `savedLocationsProvider`) lors d'un sign-out. Risque que les filtres ou favoris d'un utilisateur déconnecté restent visibles pour le suivant sur le même appareil (multi-comptes).

### 6.2 `ref.listen` d'erreurs
- ✅ `router.dart:81-87` écoute `authNotifierProvider` ; pas besoin de listen d'erreur global supplémentaire (déjà géré par `Crashlytics` + redirect vers `/sign-in` sur error).

---

## 7. Sécurité / Firestore rules

### 7.1 `firestore.rules`
- ✅ Audit complet : règles solides.
  - Default `deny` en fin (ligne 297).
  - `users` : écriture self-only avec garde anti-account-takeover (phoneE164 / email immutables côté client).
  - `bookings` : statut immutable côté client, transitions via Cloud Functions uniquement.
  - `chats/messages` : create restreint aux participants avec `senderId == auth.uid`.
  - `reviews` : seulement si booking en statut `done` et reviewer participant.
  - `notifications` : owner read-only, peut seulement flip `read`.
- ✅ Aucune collection sensible ouverte sans auth.

### 7.2 Secrets / clés API
- ✅ Aucun secret hardcodé dans `lib/`. `MAPS_API_KEY` injecté via `String.fromEnvironment` (build-time), Firebase config via `firebase_options.dart` (généré).
- 🔵 `firebase_options.dart` est commit dans le repo — c'est attendu (clés Firebase publiques, sécurité = rules), mais vérifier que le `.example` reste à jour.

---

## 8. Performance

### 8.1 Images
- 🟡 Voir 4.2 — `service_form_page.dart:829` recharge sans cache.

### 8.2 Rebuilds
- Pas d'audit ciblé (hors scope). Aucun `setState` dans `build` détecté à l'œil.

### 8.3 Analyzer
- 🔵 `lib/src/features/booking/booking_detail_page.dart:8` — `Unused import: '../../app/app_spacing.dart'`.
- 🔵 Tests : 6 warnings/info (imports inutilisés, paramètres morts, `_` leading underscores). Nettoyage cosmétique.

---

## Top 5 priorités à corriger

1. 🔴 **Fuite TextEditingController** — `lib/src/features/home/home_page.dart:269`
   Le `nameController` du dialog « sauvegarder une adresse » n'est jamais `dispose()`. Migrer vers un `StatefulWidget` dédié pour le dialog ou disposer manuellement après `Navigator.pop`.

2. 🟡 **PopScope absent partout** — particulièrement `service_form_page.dart`, `provider_onboarding_page.dart`, `booking_request_sheet.dart`
   Ajouter un prompt « Abandonner les modifications ? » sur back Android quand un formulaire est dirty. Risque réel de perte de données utilisateur sur le MVP.

3. 🟡 **Strings hardcodées hors otp_lab** — `router.dart:426/432`, `app.dart:98`, `service_form_page.dart:664`, `phone_field.dart:360`
   4 strings FR codées en dur cassent la locale `en`. Migration simple vers ARB.

4. 🟡 **Form validators absents sur sign_in / sign_up**
   Encapsuler dans `Form` + `TextFormField` avec `validator:` pour validation inline + désactiver le CTA tant que le formulaire est invalide. Évite les aller-retours Firebase pour des erreurs détectables côté client (format email, longueur mot de passe).

5. 🟡 **Keyboard dismiss manquant** sur 7 pages avec formulaire (voir §5.3)
   Wrapper le `Scaffold.body` dans un `GestureDetector(onTap: () => FocusScope.of(context).unfocus())` — pattern déjà appliqué sur sign_in/sign_up, à généraliser.

---

## Conclusion

L'application est globalement saine. Aucun crash latent évident, sécurité Firestore solide, gestion d'erreurs systématique via `AsyncValue.when`. Les défauts identifiés sont essentiellement de la dette UX (back button, keyboard, validation inline) et un nettoyage i18n (36 clés mortes, 4 strings hardcodées). Une seule fuite mémoire réelle (point 1) mais à fréquence d'occurrence faible.

Pour un MVP France/Sénégal : **corriger les points 1, 3 et 5 avant release** (impact utilisateur direct), reporter 2 et 4 sur la première itération post-launch.
