# QA Full Audit — Outalma
**Date:** 2026-05-24  
**Scope:** Pre-commit audit (hardcoded strings, error handling, routing, loading states, permissions, assets, dead code, dependencies)  
**Auditor:** Claude Code (automated)

---

## 1. Localisation / Hardcoded Strings

**Overall:** ⚠️ Mostly good — ARB coverage is comprehensive, but 7 hardcoded strings found across production code.

### Issues found

| File | Line | Hardcoded string | Impact |
|------|------|-----------------|--------|
| `lib/src/features/onboarding/onboarding_page.dart` | 75 | `'Passer'` (skip button) | Shown to all users on first launch — always French, breaks English locale |
| `lib/src/features/auth/sign_in_page.dart` | 484, 491 | `'Mail'`, `'Phone'` (toggle labels) | UI text not translated; currently English-only |
| `lib/src/features/auth/sign_up_page.dart` | 503, 510 | `'Mail'`, `'Phone'` (toggle labels) | Same as above |
| `lib/src/app/router.dart` | 426, 432 | `'Service introuvable'` (error scaffold in `_ServiceEditLoader`) | French-only fallback shown for edit errors; an `l10n.serviceNotFound` key already exists in both ARBs |
| `lib/src/features/home/home_page.dart` | 387, 391 | `'Ma position'` (GPS fallback label) | French-only label shown when reverse geocoding returns null |
| `lib/src/features/provider/provider_calendar_page.dart` | 62 | `'Mois'` (calendar format label) | French-only in `table_calendar` format map |
| `lib/src/features/provider/provider_calendar_page.dart` | 484, 551 | `'Service'` (fallback title when `service?.title` is null) | Acceptable English fallback, but inconsistent with l10n approach |

### Notes
- The OTP Lab page (`auth/otp_lab/`) is debug-only and intentionally not localized — not an issue.
- The debug label `'🔬 OTP Lab (debug)'` in sign_in_page.dart is also debug-only — acceptable.
- The ARB files are well-structured with 185+ keys covering all main user flows in both EN and FR.

---

## 2. Gestion d'erreurs manquante

**Overall:** ✅ Generally good — try/catch pattern applied consistently across auth, booking, and profile flows. Two gaps identified.

### Issues found

**2.1 — `_selectSuggestion` in `home_page.dart` (line 232) — no try/catch**

```dart
Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _controller.text = suggestion.description;
    setState(() => _suggestions = []);
    final geocoding = ref.read(geocodingServiceProvider);
    final coords = await geocoding.getPlaceLatLng(suggestion.placeId);  // no catch
    if (coords == null || !mounted) return;
    ...
}
```
A network error from `getPlaceLatLng()` (Google Places API) will throw an unhandled exception and surface as a red-screen crash or silent failure depending on the caller. The adjacent `_onSearchChanged` (line 225) correctly wraps in try/catch, but `_selectSuggestion` does not.

**2.2 — `catch (_) {}` silent swallowing (booking_request_sheet.dart line 148)**

```dart
} catch (_) {}   // after stopping the AudioRecorder — failure silently ignored
```
This is defensible (stop-recording failure is non-critical), but there is no user feedback if the recorded bytes cannot be read, which means the user sees no voice message and no error.

### What is properly handled
- All Firebase auth errors (`FirebaseAuthException`, `FirebaseFunctionsException`) have specific handlers in sign_in, sign_up, booking_request_sheet, and booking_detail_page.
- Profile save, avatar upload, mode switch, cancel/confirm booking, report, review submit — all have try/catch with SnackBar feedback.
- Repository layer (Firestore) delegates error propagation up to the provider/widget layer as expected.

---

## 3. Navigation / Routing

**Overall:** ✅ Router is well-structured with no dead routes or circular redirects. One hardcoded French string found (see §1). One minor logical concern documented.

### Route inventory

All routes declared in `router.dart` map to real, existing page classes:

| Route | Target | Status |
|-------|--------|--------|
| `/onboarding` | `OnboardingPage` | ✅ |
| `/sign-in` | `SignInPage` | ✅ |
| `/sign-up` | `SignUpPage` | ✅ |
| `/otp-lab` (debug only) | `OtpLabPage` | ✅ |
| `/provider/onboarding` | `ProviderOnboardingPage` | ✅ |
| `/provider/calendar` | `ProviderCalendarPage` | ✅ |
| `/provider/services/new` | `ServiceFormPage` | ✅ |
| `/provider/services/:id/edit` | `_ServiceEditLoader` → `ServiceFormPage` | ✅ |
| `/home` (shell branch 0) | `HomePage` | ✅ |
| `/bookings` + `/:bookingId` (shell branch 1) | `BookingListPage`, `BookingDetailPage` | ✅ |
| `/provider` (shell branch 2) | `ProviderDashboardPage` | ✅ |
| `/provider/inbox` + `/bookings/:id` (shell branch 3) | `ProviderInboxPage`, `BookingDetailPage` | ✅ |
| `/chats` (shell branch 4) | `ChatsListPage` | ✅ |
| `/profile` (shell branch 5) | `ProfilePage` | ✅ |
| `/service/:serviceId` | `ServiceDetailPage` | ✅ |
| `/booking/:bookingId` (deep-link) | `BookingDetailPage` | ✅ |
| `/chat/:chatId` | `ChatPage` | ✅ |
| `/review/:bookingId` | `ReviewFormPage` | ✅ |
| `/report/:type/:id` | `ReportPage` | ✅ |
| `/provider-profile/:uid` | `PublicProviderProfilePage` | ✅ |
| `/notifications` | `NotificationsPage` | ✅ |

### Potential concern — mode redirect loop

The redirect logic in `RouterNotifier.redirect()` sends provider-mode users on client tabs (e.g. `/home`) to `/provider`, and vice versa. If `activeModeProvider` flips quickly (e.g., race condition on mode switch), there is a theoretical rapid redirect loop between `/home` and `/provider`. No concrete bug has been observed, but the design relies on `activeModeProvider` being stable before navigation settles.

### Dead route
The `SwitchModePage` widget exists at `lib/src/features/switch_mode/switch_mode_page.dart` but is **never imported, never registered in the router, and never navigated to**. The switch-mode functionality was integrated into `ProfilePage`. The ARB keys `switchModeTitle`, `switchModeHeading`, `switchModeDescription`, `switchModeThemeDescription` are defined but only used by the now-orphaned page. See §7.

---

## 4. États de chargement manquants

**Overall:** ✅ The main async operations all have loading states. The pattern `_loading = true/false` with `CircularProgressIndicator` is applied consistently.

### Properly handled
- `SignInPage` / `SignUpPage`: `_loading` bool disables button and shows inline spinner.
- `BookingRequestSheet`: `_loading` bool disables CTA during send.
- `BookingDetailPage`: Per-action loading booleans (`_loadingAccept`, `_loadingReject`, `_loading`).
- `ServiceFormPage`, `ProviderOnboardingPage`, `ReviewFormPage`, `ReportPage`: All have loading spinners.
- `ProfilePage._ProfileForm`, `_ModeToggle`, `_EditableUserHeader`: All have loading states.
- All Riverpod `AsyncValue.when()` usage properly handles the `loading:` branch.

### Minor gap
- `_ServiceEditLoader` in `router.dart` shows a full-screen `CircularProgressIndicator` while loading (correct), but the error body contains the hardcoded French string `'Service introuvable'` instead of using `l10n.serviceNotFound` (see §1).

---

## 5. Cohérence Permissions iOS/Android

**Overall:** ⚠️ Core permissions are consistent, but Android is missing the `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` permission for Android 13+ (API 33+).

### Permission comparison

| Feature | iOS (Info.plist) | Android (AndroidManifest.xml) | Status |
|---------|-----------------|-------------------------------|--------|
| Camera | `NSCameraUsageDescription` ✅ | `CAMERA` ✅ | ✅ Consistent |
| Microphone (voice messages) | `NSMicrophoneUsageDescription` ✅ | `RECORD_AUDIO` ✅ | ✅ Consistent |
| Location | `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription` ✅ | `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` ✅ | ✅ Consistent |
| Photo library | `NSPhotoLibraryUsageDescription` ✅ | ❌ Missing `READ_MEDIA_IMAGES` for API 33+ | ⚠️ Gap |
| Push notifications | iOS uses `aps-environment` entitlement (handled) | `POST_NOTIFICATIONS` ✅ | ✅ Consistent |
| Internet | Implicit on iOS | `INTERNET` ✅ | ✅ Consistent |

### Details on Android 13+ photo access gap

The `image_picker` package is used in `AvatarUploadService` and `ServicePhotoUploadService`. On Android 13+ (API 33), accessing photos requires `READ_MEDIA_IMAGES`. While newer versions of `image_picker` use the system photo picker (which doesn't require the permission), apps targeting older builds or using `ImageSource.gallery` directly may fail silently. The manifest declares `minSdkAndroid: 21` in `flutter_launcher_icons`, meaning Android 5+ users are supported.

**Recommendation:** Add `<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />` with `android:maxSdkVersion="32"` for legacy compatibility alongside the existing photo picker approach.

### iOS Info.plist: No issues
All 4 required usage descriptions are present and written in French (consistent with the app's primary locale). Map app queries (`comgooglemaps`, `waze`) are declared in `LSApplicationQueriesSchemes`.

---

## 6. Vérification des Assets

**Overall:** ⚠️ One referenced asset (`logo_outalma.png`) exists on disk but is not listed in `pubspec.yaml`. Two assets are properly declared and present.

### pubspec.yaml asset declarations

```yaml
flutter:
  assets:
    - assets/images/   # whole directory included
```

The entire `assets/images/` directory is declared, so all files in that folder are bundled.

### Files on disk

```
assets/images/
  logo_icon_cropped.png   ✅  (used in onboarding, auth, splash, launcher icon)
  logo_outalma.png        ⚠️  (exists on disk, included by wildcard, but not explicitly referenced in code)
```

### Code references

- `assets/images/logo_icon_cropped.png` — referenced in `OnboardingPage._Slide`, `SignInPage._AuthLogo`, `SignUpPage._AuthLogo`, `flutter_native_splash`, and `flutter_launcher_icons` config. **File exists.** ✅
- `assets/images/logo_outalma.png` — **file exists on disk** (modified in current git diff per `git status`), but **no Dart code reference was found** using `Image.asset('assets/images/logo_outalma.png')`. It is bundled by the wildcard but likely orphaned or prepared for future use.

### Summary

| Asset | Declared | Exists | Used in code | Status |
|-------|----------|--------|-------------|--------|
| `logo_icon_cropped.png` | via `assets/images/` | ✅ | ✅ | ✅ OK |
| `logo_outalma.png` | via `assets/images/` | ✅ | ❌ no code reference | ⚠️ Orphaned or prepared |

---

## 7. Dead Code

**Overall:** ⚠️ One dead widget page found. Two domain files with low/no external usage. Generated localization files correctly suppress lint warnings.

### Dead widget: `switch_mode_page.dart`

**File:** `lib/src/features/switch_mode/switch_mode_page.dart`

`SwitchModePage` is a full `ConsumerStatefulWidget` that:
- Is **not imported** anywhere in the codebase.
- Is **not registered** in the router.
- Has dedicated ARB keys (`switchModeTitle`, `switchModeHeading`, `switchModeDescription`, `switchModeThemeDescription`) that are also unreachable from any live code path.

The functionality (mode switching + theme selection) has been **migrated into `ProfilePage`**. This file should be deleted.

### Potentially dead: `lib/src/domain/enums/user_role.dart`

`UserRole` enum is defined but has **no imports outside its own file**. It is not used by any repository, provider, or widget. If role-based access is not yet implemented, this file can be removed.

### Suppressed lint warnings (expected, not an issue)

- `lib/l10n/app_localizations_fr.dart` line 1: `// ignore: unused_import` — standard Flutter gen-l10n output.
- `lib/l10n/app_localizations_en.dart` line 1: same.

### All other files appear reachable

No other `.dart` files in `lib/src/` appear to be fully unreferenced after checking import graphs for shared/, domain/, data/, and application/ layers.

---

## 8. Cohérence Versions Dépendances

**Overall:** ✅ No pinned-to-exact or `any` versions found. All dependencies use `^` constraints. Resolved (locked) versions are recent and consistent. One dependency override noted.

### Key resolved versions (from pubspec.lock)

| Package | pubspec.yaml constraint | Resolved version | Notes |
|---------|------------------------|-----------------|-------|
| `firebase_core` | `^3.1.0` | `3.15.2` | Current |
| `firebase_auth` | `^5.2.0` | `5.7.0` | Current |
| `cloud_firestore` | `^5.4.0` | `5.6.12` | Current |
| `cloud_functions` | `^5.1.0` | `5.6.2` | Current |
| `firebase_messaging` | `^15.1.3` | `15.2.10` | Current |
| `firebase_storage` | `^12.3.4` | `12.4.10` | Current |
| `firebase_crashlytics` | `^4.1.0` | `4.3.10` | Current |
| `go_router` | `^14.2.7` | `14.8.1` | Current |
| `flutter_riverpod` | `^2.5.1` | `2.6.1` | Current |
| `google_maps_flutter` | `^2.10.0` | `2.17.0` | Current |
| `intl` | `^0.20.2` | `0.20.2` | Exact match — no newer minor version |
| `geolocator` | `^14.0.2` | `14.0.2` | Exact match |
| `cached_network_image` | `^3.4.1` | `3.4.1` | Exact match |

### Dependency override

```yaml
dependency_overrides:
  record_linux: ^1.3.0
```

This override forces the Linux build of the `record` plugin to `^1.3.0` to resolve a platform compatibility conflict. This is a known pattern for desktop targets and is acceptable. However, it should be revisited if `record` is bumped significantly, as it could mask incompatibilities.

### No issues found with
- No `any` version constraints.
- No exact pinning (e.g., `== 1.2.3`).
- All Firebase packages share consistent major versions (v5.x for auth/functions/firestore, v3.x for core).
- `intl` version aligns with the Flutter SDK constraint (`^3.11.3` uses intl `0.20.x`).

---

## TOP 3 Priorités avant commit

1. **Hardcoded strings in production UI (§1)** — The `'Passer'` skip button and `'Mail'`/`'Phone'` toggle labels in onboarding and auth pages are always displayed in French/English regardless of locale. The router also uses a hardcoded French `'Service introuvable'` when the `l10n.serviceNotFound` key exists. These are visible regressions for multi-locale users. Fix: replace with `l10n.introNext` (or add a `introSkip` key), and use `l10n.serviceNotFound` in the router.

2. **Missing error handling in `_selectSuggestion` (§2)** — `home_page.dart` line 232: `geocoding.getPlaceLatLng()` can throw a network exception with no catch block. A user tapping a location suggestion during a network hiccup will get an unhandled exception. Fix: wrap in try/catch with a SnackBar using `l10n.zoneConnectionError` or `l10n.errorNetwork`.

3. **Android missing `READ_MEDIA_IMAGES` permission for API 33+ (§5)** — The app uses `image_picker` for avatar and service photos. On Android 13 devices with older plugin builds, photo access may silently fail. Fix: add `<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" android:maxSdkVersion="32" />` to `AndroidManifest.xml`.

---

## Verdict Global

**NOT READY** — 3 medium-impact issues must be fixed before commit: hardcoded UI strings in production locale-sensitive screens, one unguarded async call that can crash on network errors, and a missing Android 13+ media permission. The dead `SwitchModePage` file should also be cleaned up. All other areas (error handling, routing, loading states, assets, dependency versions) are in good shape.
