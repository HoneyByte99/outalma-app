# Release Readiness

The MVP is not releasable until every item below is true.

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

- [ ] 90%+ test coverage on: domain models, booking state machine, repositories, Cloud Functions, Riverpod notifiers
- [ ] Zero critical `flutter analyze` warnings
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
- [ ] Works on Android, iOS, and web (same codebase)

---

## Infrastructure

- [ ] Firebase project configured for production (not dev/staging)
- [ ] Firestore indexes deployed
- [ ] Storage rules deployed
- [ ] Cloud Functions deployed (Gen2)
- [ ] Firebase App Check enabled
- [ ] App icons and splash screens set

---

## Security

- [ ] **⚠️ ACTION REQUIRED — Google Cloud Console : restreindre les clés API**
  - Aller sur https://console.cloud.google.com → APIs & Services → Credentials
  - Clé Maps Android (`AIzaSyBm5...`) → Application restrictions → Android apps → ajouter le bundle ID `com.honeybyte.outalma_app`
  - Clé Maps iOS (`AIzaSyBm5...`) → Application restrictions → iOS apps → ajouter le bundle ID `com.honeybyte.outalma_app`
  - Clé Places (`AIzaSyA8L...`) → Application restrictions → IP addresses ou HTTP referrers selon usage serveur/client
  - Sans restriction, les clés exposées dans l'historique git peuvent être utilisées par des tiers et générer des frais
- [ ] Secrets GitHub configurés (`PLACES_API_KEY`, `MAPS_API_KEY`) ✅ fait
- [ ] `local.properties` et `Secrets.xcconfig` jamais commités ✅ gitignored
- [ ] `firebase_options.dart` — client-side IDs, sécurité assurée par les Firestore Rules (OK à commiter)
