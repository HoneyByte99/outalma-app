# Release Readiness

The MVP is not releasable until every item below is true.

---

## Security ✅ Complete

- [x] Firebase config files gitignored — injected via GitHub Secrets in CI
- [x] Maps API key rotated — new key restricted to Maps SDK iOS + Android only
- [x] Places API key injected via `--dart-define=PLACES_API_KEY` (never hardcoded)
- [x] All GCP keys restricted: iOS by bundle ID, Android by package + SHA-1, Browser by domain
- [x] `android/local.properties` and `ios/Flutter/Secrets.xcconfig` gitignored
- [x] GitHub Secrets: `MAPS_API_KEY`, `PLACES_API_KEY`, `FIREBASE_OPTIONS_DART`, `GOOGLE_SERVICES_JSON`, `GOOGLE_SERVICE_INFO_PLIST`
- [x] Firestore rules: status immutable from client, default deny, participant-only access
- [x] Storage rules: participant-only chat media, owner-only service images
- [ ] Firebase App Check enabled (DeviceCheck iOS / Play Integrity Android) — defer to post-TestFlight

---

## Backend contracts

- [ ] `BookingStatus` values are identical in Dart, TypeScript, Firestore, and rules
- [ ] All Dart models match their Firestore document schema exactly (field names, types)
- [ ] All Cloud Functions callable from Dart with correct parameter shapes
- [ ] `acceptBooking` creates chat, sets `chatId` on booking, in a single transaction
- [ ] `cancelBooking` (client or provider, only when `requested`), `markInProgress` (provider), `confirmDone` (client) implemented and tested
- [ ] PhoneShare readable when `status ∈ {accepted, in_progress, done}`, not before
- [ ] Firestore rules tested with 2 real accounts: client cannot accept, provider cannot book, no direct status write

---

## Core flows (end-to-end, manual test required)

- [ ] Sign up → profile setup → sign in works on Android and iOS
- [ ] Client can switch to provider mode and back
- [ ] Provider can create and publish a service
- [ ] Client can browse services and open service detail
- [ ] Client can submit a booking request
- [ ] Provider receives booking and can accept or reject
- [ ] Chat is unlocked after accept; inaccessible before
- [ ] Client and provider can exchange messages in real time
- [ ] Client confirms done (`confirmDone`) and leaves a review on the provider
- [ ] Provider leaves a review on the client after `done`
- [ ] Push notification received on new booking request and new message

---

## Quality

- [x] `flutter analyze --fatal-warnings` — no issues
- [x] 169 unit/integration tests passing
- [ ] 90%+ coverage on: domain models, booking state machine, repositories, Cloud Functions, Riverpod notifiers
- [ ] All screens have loading, error, and empty states
- [ ] No raw `Map<String, dynamic>` crossing layer boundaries
- [ ] No Firestore import in domain layer
- [ ] No business logic in widget files

---

## UX

- [ ] Design tokens applied consistently (colors, typography, spacing)
- [ ] App does not look like a default Flutter scaffold
- [ ] Booking flow is 3 steps or fewer for the client
- [ ] No dead-end screens (every error has a recovery path)
- [ ] Works on Android and iOS (TestFlight target)

---

## Infrastructure

- [ ] Firebase project configured for production (not dev/staging)
- [ ] Firestore indexes deployed
- [ ] Storage rules deployed
- [ ] Cloud Functions deployed (Gen2)
- [ ] App icons and splash screens set
- [x] CI pipeline passing — format, analyze, test (PR #3 in progress)

---

## TestFlight distribution

- [x] `ios/ExportOptions.plist` created — app-store, automatic signing, team 88K4254XLD
- [x] `flutter build ipa --release` — builds 2 and 3 archived and uploaded
- [x] Apple Distribution certificate — created automatically by Xcode (`Apple Distribution: Papa Amath BA`)
- [x] App Store Connect app record created for `com.honeybyte.outalmaApp` (App ID: 6771747896)
- [x] IPA uploaded to App Store Connect — build 1.0.0 (3) active
- [x] Internal TestFlight group "Internal Testers" created; amathba2@gmail.com invited
