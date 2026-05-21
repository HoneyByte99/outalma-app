# Auth security review — 2026-05

Scope: Phone-OTP + email magic-link overhaul (callable functions, Flutter notifier, pages, deep-link handler, mobile entitlements, Firestore rules).

Reviewed files (absolute paths):
- `/Users/amathba/clawd/projects/outalma/outalma-app/functions/src/auth_phone.ts`
- `/Users/amathba/clawd/projects/outalma/outalma-app/functions/src/otp_twilio.ts`
- `/Users/amathba/clawd/projects/outalma/outalma-app/functions/src/index.ts`
- `/Users/amathba/clawd/projects/outalma/outalma-app/lib/src/application/auth/auth_notifier.dart`
- `/Users/amathba/clawd/projects/outalma/outalma-app/lib/src/features/auth/sign_in_page.dart`
- `/Users/amathba/clawd/projects/outalma/outalma-app/lib/src/features/auth/sign_up_page.dart`
- `/Users/amathba/clawd/projects/outalma/outalma-app/lib/src/app/app.dart`
- `/Users/amathba/clawd/projects/outalma/outalma-app/ios/Runner/Runner.entitlements`
- `/Users/amathba/clawd/projects/outalma/outalma-app/android/app/src/main/AndroidManifest.xml`
- `/Users/amathba/clawd/projects/outalma/outalma-app/firebase/firestore.rules`
- `/Users/amathba/clawd/projects/outalma/outalma-app/lib/src/data/repositories/firestore_user_repository.dart`
- `/Users/amathba/clawd/projects/outalma/outalma-app/.gitignore` / `functions/.gitignore`

Verdict: **NOT production-ready**. Two critical issues (C1, C2) enable account takeover with no exotic capability. Several high-severity issues around rate limiting, enumeration, and abandoned/legacy endpoints. Recommend blocking TestFlight on C1+C2+H1.

---

## 1. Critical findings (must fix before TestFlight)

### C1 — Firestore `users` update/create rule lets anyone claim any phone number (account takeover)

**Where:** `firebase/firestore.rules`, lines 35–40.

```
match /users/{uid} {
  allow read: if signedIn();
  allow create: if isAdmin() || isSelf(uid);
  allow update: if isAdmin() || isSelf(uid);
  allow delete: if isAdmin();
}
```

`allow create` and `allow update` have **zero field-level constraints**. A signed-in user can write *any* value into their own `users/{uid}` document, including `phoneE164`. Sign-in by phone resolves uid via `findUserUidByPhone()` in `functions/src/auth_phone.ts:164-173`, which runs:

```
db().collection('users').where('phoneE164', '==', phone).limit(1).get()
```

with no tie-break ordering and no Auth-side phone verification.

**Exploit (account takeover):**
1. Attacker signs up via email magic link with throwaway email → has signed-in session with `users/A` doc owned by them.
2. From Flutter (or any client SDK call), attacker writes `phoneE164: '+33VICTIMNUM'` onto `users/A`. Rule allows it.
3. Victim later signs in via OTP with their real phone `+33VICTIMNUM`. Twilio approves the real OTP (victim controls the SIM).
4. `verifyPhoneOtpAndSignIn` calls `findUserUidByPhone('+33VICTIMNUM')`, which returns *attacker’s* `uid = A` (because no ordering — Firestore returns whichever first matches, possibly the attacker’s if the victim doesn’t yet have a phone-attached doc, or non-deterministically if both exist).
5. Server mints a custom token for uid `A` and returns it to the victim’s app. Victim is now signed into the attacker’s account.

Step 4 is even worse for victims that **never** signed up by phone (only email): there is no competing doc, so the attacker’s doc is the only match. Victim's first OTP sign-in attempt sends them straight into the attacker’s account, which has the attacker’s email, services, bookings, chats, etc.

**Fix (defence in depth):**
- In Firestore rules for `users/{uid}`, forbid client writes to `phoneE164`, `email`, `createdAt`, `id`, `activeMode` (mode switch already goes via app). Example:
  ```
  allow update: if isAdmin() || (
    isSelf(uid)
    && request.resource.data.phoneE164 == resource.data.phoneE164
    && request.resource.data.email == resource.data.email
    && request.resource.data.createdAt == resource.data.createdAt
    && request.resource.data.id == resource.data.id
  );
  allow create: if isAdmin() || (
    isSelf(uid)
    && request.resource.data.id == uid
    && !('phoneE164' in request.resource.data)
  );
  ```
- Better: make `phoneE164` writable only by Cloud Functions (Admin SDK bypasses rules). Move the field write in `verifyPhoneOtpAndSignUp` to a server-only collection or guard the field explicitly. The Flutter `_resolveState` (`auth_notifier.dart:88-98`) currently constructs `AppUser` with `phoneE164: firebaseUser.phoneNumber` and calls `userRepo.upsert(appUser)` on first sign-in — this *will* break once you tighten the rules. Fix that path by either (a) skipping client-side user-doc creation for OTP signups (server already creates the doc in `verifyPhoneOtpAndSignUp:284-292`) or (b) excluding phoneE164 from client upserts.
- Also enforce uid==id at create time so a user cannot stuff a `id` mismatching the doc path.

---

### C2 — `verifyPhoneOtpAndSignIn` cross-binds Firebase Auth phone numbers without verifying the existing Auth user’s identity

**Where:** `functions/src/auth_phone.ts:218-238`.

```
const uid = await findUserUidByPhone(phone);
...
await admin.auth().updateUser(uid, { phoneNumber: phone });
```

Three problems compound:

1. The uid comes from a Firestore lookup that, per C1, is attacker-controllable.
2. `updateUser({phoneNumber})` will *overwrite* whatever phone number Firebase Auth currently has on that uid. If a uid was originally provisioned via email magic link and never touched phone auth, this silently attaches a phone to that account.
3. If the phone was already linked to a *different* Auth user, Firebase Auth throws `auth/phone-number-already-exists`. The error is caught at line 227 and only `logger.warn`’d — the flow continues and still returns a custom token. So the inconsistency is hidden from monitoring.

**Exploit:** combined with C1, attacker not only steals the Firestore-side identity but also gets a real Firebase Auth user with a verified `phoneNumber` field that they never owned. This will appear legitimate in Auth console and to any downstream services that trust `firebaseUser.phoneNumber`.

**Fix:**
- Resolve uid only via a **Firebase-Auth-side lookup**, not via the Firestore mirror. `admin.auth().getUserByPhoneNumber(phone)` is server-authoritative and reflects Firebase’s uniqueness guarantee.
- Fall back to creating a new account (or the `newUser: true` branch) if no Auth user has the phone. Stop trusting `users.phoneE164` as the source of truth for identity resolution.
- If updateUser fails, do **not** mint a custom token — return `failed-precondition` and log loudly.

---

## 2. High (should fix soon)

### H1 — No rate limiting on `requestPhoneOtp` (SMS billing DoS + targeted-victim spam)

**Where:** `functions/src/auth_phone.ts:187-201`. The function is `onCall` without auth requirement (`request.auth` not checked) and without any per-IP / per-phone throttle.

Twilio Verify enforces some defaults (default ~5 sends/phone/10min, deliverable-rate limits), but:
- The same caller can request OTPs for *thousands of different phones* in a loop. Twilio bills you per attempt. France SMS is ~€0.07/SMS, Senegal ~€0.10. A small VPS can burn through €10k/day.
- Twilio's per-number rate limit doesn't stop **targeted harassment**: 5 SMS every 10 min, indefinitely, to a victim's phone, costs the attacker nothing (only your wallet).
- App Check is not configured on the callable (no `enforceAppCheck: true`).

**Exploit:** `curl` the callable endpoint with random E.164 numbers in a loop. Each call costs you a Twilio SMS.

**Fix (minimum viable):**
- Add `enforceAppCheck: true` to the `onCall` options and roll out App Check (Play Integrity / DeviceCheck/AppAttest) before TestFlight.
- Add a Firestore-backed rate limit on `(ip, phone)` and `phone`-only:
  - max 3 requests per phone per 15 minutes
  - max 30 requests per IP per hour
  - reject obviously synthetic numbers (e.g. all-zero suffix)
- Track total daily SMS spend with a Cloud-Function-managed counter; trip the breaker when the daily budget is exceeded.
- Set Twilio Verify’s service-level rate limits explicitly via the dashboard.

### H2 — Phone enumeration via timing/response shape on `verifyPhoneOtpAndSignIn`

**Where:** `functions/src/auth_phone.ts:212-241`.

The function returns `{ newUser: true, phoneE164 }` for phones unknown to Outalma vs `{ newUser: false, customToken, uid }` for known phones. While this requires a valid OTP, **the attacker is also the phone owner** (they just typed in their *own* phone with the question "is this person on Outalma?"). The current shape lets anyone discover whether any number they control (or can briefly use, e.g. burner) has an Outalma account.

Less of a concern than email enumeration but still a leak. More relevant: even without a valid OTP, the **latency differs** between known/unknown phones (the known branch does one extra `updateUser` + `createCustomToken`; the unknown branch is a no-op after the lookup). With Twilio's rate-limited but observable check endpoint, timing oracle is possible for the case where attacker can submit OTP attempts (e.g. they got the SMS).

**Fix:**
- In the unknown branch, mirror the latency: do a dummy `createCustomToken` against a sentinel uid, then drop the token before returning.
- Consider returning a uniform `{ status: 'ok' }` and force a follow-up `whoami`-style call once the client has signed in — though that's more invasive.

### H3 — `verifyPhoneOtpAndSignUp` race: two devices, same phone, both pass

**Where:** `functions/src/auth_phone.ts:248-301`.

The check-then-create sequence is:
```
await twilioCheckVerification(phone, code);
if (await isPhoneTakenByOtherUid(phone, null)) throw 'already-exists';
const created = await auth.createUser({ phoneNumber: phone, ... });
await db().collection('users').doc(uid).set({ ... phoneE164: phone ... });
```

Two parallel requests with the same phone (e.g. user double-taps "Verify"):
- Both can pass `isPhoneTakenByOtherUid` (no doc exists yet).
- `admin.auth().createUser({phoneNumber})` enforces uniqueness in Auth, so one will throw `auth/phone-number-already-exists`. That's the safety net.
- But: in the loser path the Twilio code has already been consumed, the error message is generic ("OTP verification failed" would be incorrect — it’ll bubble up as an uncaught Firebase error). The user gets a confusing 500.

Less severe than C1 but the failure mode is ugly and the Firestore mirror could end up inconsistent if a concurrent attacker pre-creates the `users` doc via C1 between the check and the create.

**Fix:**
- Wrap the verify→create flow in a Firestore transaction that touches a `phoneLocks/{phone}` doc (uniqueness via doc id) before calling Twilio.
- Catch `auth/phone-number-already-exists` from `createUser` and rethrow as `HttpsError('already-exists', 'Phone number already registered')` so the client surfaces a clean error.

### H4 — Legacy `sendOtpTwilio` / `verifyOtpTwilio` are exported in production

**Where:** `functions/src/index.ts:23` exports these from `otp_twilio.ts`. The header comment says “Not deployed by default … behind feature flags” but the unconditional `export` means the deploy *will* publish them. They share **all** the C1/C2/H1/H2 problems of the canonical functions plus an additional surprise: `verifyOtpTwilio` returns the same `newUser: true` payload structure but the response shape *includes* `verificationSid` and other Twilio internals that the canonical function omits.

Having two parallel sign-in paths roughly doubles the attack surface and creates a confusing audit trail.

**Fix:** Remove the export, or wrap it in a `if (process.env.OUTALMA_OTP_LAB === '1')` guard before exporting. There should be exactly one production sign-in path.

### H5 — Email-magic-link signups can land in Firestore with empty/missing displayName and country `FR` regardless of locale

**Where:** `auth_notifier.dart:310-352` (`completeEmailMagicLink`) and `_resolveState:80-109`.

When the user is created on first sign-in by email magic link:
- `displayName` reads from SharedPreferences (`pendingName`); if the prefs slot is empty (user cleared app data, opened the link on another device, or signed in to the link on a fresh install) the doc is written with `displayName: ''`.
- `country` defaults to `'FR'` with no relation to the user's actual locale or phone (which they don't have).
- The fallback path in `_resolveState:88-98` also unconditionally writes `country: 'FR'` and `activeMode: ActiveMode.client` for any orphan Firebase user.

This is not exploitable per se, but it creates accounts the user cannot recover (no name) and silently pretends every email signup is French. Combined with C1, a user can later "fix" their own country / display name without re-auth — which is fine — but `phoneE164` is also writable, see C1.

**Fix:** if `pendingName.isEmpty`, abort the magic-link sign-in and prompt the user to restart sign-up. Display the email on the link screen so the user can confirm they're on the right device.

### H6 — Email magic-link continue URL is the default Firebase Hosting domain — no allow-list / app-side validation

**Where:** `auth_notifier.dart:30-31`, `ios/Runner/Runner.entitlements:7-8`, `android/.../AndroidManifest.xml:34-37`.

The continue URL is `https://outalmaservice-d1e59.firebaseapp.com/__/auth/links`. The associated domains and Android intent filter accept any HTTPS link on `outalmaservice-d1e59.firebaseapp.com` or `.web.app`. `_handleIncomingLink` (`app.dart:56-80`) accepts any URI and only filters via `auth.isSignInWithEmailLink(link)`.

Firebase’s `isSignInWithEmailLink` verifies the signature and oobCode, so a malicious actor cannot forge a sign-in link they didn’t themselves request. The remaining risk is more subtle: if you ever change the project ID or add a second project, the wildcard host match means any subdomain on those hosts can fire the app, and the app will pass the URI verbatim into `signInWithEmailLink` — Firebase Auth will reject foreign-project links, but the user-visible failure is opaque.

**Fix:**
- Restrict the Android intent filter `<data>` with an `android:pathPrefix="/__/auth/links"` so only the Firebase Auth link path opens the app.
- Same with iOS Associated Domains: use `applinks:outalmaservice-d1e59.firebaseapp.com?mode=oobCode` (Apple ASD path-component syntax is limited; at minimum verify in `_handleIncomingLink` that `uri.path.startsWith('/__/auth/links')`).
- In `_handleIncomingLink`, log + drop links whose host is not exactly your two allow-listed hosts.

### H7 — `service-account.json` exists on disk in two locations; no test that they are git-untracked

**Where:**
- `/Users/amathba/clawd/projects/outalma/outalma-app/scripts/service-account.json` (mode `-rw-r--r--`, world-readable on the machine)
- `/Users/amathba/clawd/projects/outalma/outalma-app/functions/scripts/service-account.json` (mode `-rw-------`, OK)
- Root `.gitignore` has `**/service-account*.json` so they *should* be ignored, but `functions/.gitignore` has only `lib/`, `node_modules/`, `*.log`, `.firebase/` — if a maintainer ever runs git from inside `functions/` with a different toolchain, no defence in depth.

**Fix:**
- `chmod 600 scripts/service-account.json` immediately.
- Add `**/service-account*.json`, `**/*firebase-adminsdk*.json`, `.env`, `.env.*` to `functions/.gitignore` explicitly.
- Run a CI grep that fails the build if any tracked file matches those patterns. Sample:
  ```
  git ls-files | grep -E '(service-account|firebase-adminsdk|\.env$)' && exit 1 || exit 0
  ```
- Confirm via `git log --all -- '**/service-account*.json'` that no historical commit ever contained the file. (I could not run git from this review — verify manually.)

---

## 3. Medium (track, fix in Phase 4)

### M1 — `displayName` validation is too permissive

**Where:** `functions/src/auth_phone.ts:62-74, 256-260`.

`assertNonEmptyString(... 'displayName', 80)` accepts any Unicode including control characters, RTL overrides, zero-width joiners, HTML, JS, emoji-bombs. While Firestore stores it safely and Flutter Text widgets escape HTML, the value also flows into:
- Push notifications (Firebase Cloud Messaging — limited risk)
- The provider profile (rendered in webviews, marketing emails, admin panel)
- `user_roles.displayName` (admin panel — likely raw HTML somewhere)

**Fix:** strip control chars (`\p{Cc}` / `\p{Cf}`), forbid newlines, NFC-normalize, enforce min length 2.

### M2 — `country` whitelist is FR/SN-only but the phone-prefix mapper accepts +212/+213/+216/+225/etc

**Where:** `lib/src/features/shared/phone_field.dart:23-43` lists ~22 countries; `auth_phone.ts:76-83` only accepts `FR` or `SN`; `sign_up_page.dart:28-31` maps everything except `+221` → `FR`.

A user with a `+225` (Côte d'Ivoire) phone signs up as `country: 'FR'`. Not a security issue but breaks downstream logic that treats `country` as ground truth (compliance, AML, GDPR data residency).

**Fix:** either expand the whitelist to all listed dial codes, or restrict the picker to FR/SN until the marketplace launches in more countries. Don’t silently coerce.

### M3 — `_resolveState` swallows all errors as "unauthenticated"

**Where:** `auth_notifier.dart:105-108`.

Any exception in `getById` or `upsert` (rules denial, network, deserialization bug) results in `AuthUnauthenticated`. The user will be silently kicked back to the sign-in screen and lose any chance to retry. Adversarial side: a malicious Firestore write that triggers a deserialization error in `AppUser.fromJson` could be used as a "kick this user offline" primitive — minor, but ugly UX. Should at least surface a recoverable error state and log to Crashlytics.

### M4 — `assertCode` allows 4-digit codes, but Twilio Verify defaults to 6

**Where:** `functions/src/auth_phone.ts:51-60`.

Regex `^\d{4,8}$` is more permissive than Twilio's actual codes (typically 6 digits). Allowing 4 makes online brute-force easier: 10⁴ space, with Twilio's default 5 attempts/code, attacker has ~0.05% chance per code cycle, which over many cycles becomes meaningful if request-OTP is unrate-limited (H1). Tighten to `^\d{6}$`.

### M5 — `logSession` writes geolocation from a third-party (`ipapi.co`) inside the callable hot path

**Where:** `functions/src/index.ts:911-928` (outside auth scope but called from `_resolveState`).

Failures fall through (`try/catch`), but the inline fetch adds tail latency on every sign-in and exposes user IP to a third-party that has no DPA on file. Not a P0, but for GDPR posture you want this off the critical path and either (a) self-hosted IP→country lookup (MaxMind), or (b) async via Pub/Sub.

### M6 — Custom-token claims include `phoneE164` and `provider`

**Where:** `functions/src/auth_phone.ts:235-238, 294-297`.

These propagate into the user's ID token (claims size limit is 1000 bytes; you're fine here). Risk is minimal but the `phoneE164` claim now travels in every API call and is exposed to any client that introspects the ID token. Unnecessary — the SDK exposes `firebaseUser.phoneNumber` once `updateUser` runs. Drop the claims to reduce surface.

### M7 — Pending magic-link state in SharedPreferences is not bound to email

**Where:** `auth_notifier.dart:18-20, 314-321`.

If user requests a link for `alice@x` then clicks an old link for `bob@x` that arrives later, the client will sign in as `bob@x` (Firebase verifies the oobCode) but stamp `displayName/country` from `alice`'s pending prefs. Edge case but real on shared/family devices.

**Fix:** key the prefs by lowercased email, or include a one-time nonce that the link must match.

---

## 4. Low / nits

- **L1** — `auth_phone.ts:78`: the comment "Extend as the marketplace grows" — leaves an obvious TODO. Either expand or remove the comment so reviewers don't assume it’s in flight.
- **L2** — `assertPhone` regex `^\+[1-9]\d{6,14}$` — E.164 allows 1–15 total digits including country code (so `\d{6,14}` for the tail is correct since the leading digit is captured separately) — fine, but the min is loose. Phone numbers under 8 digits are likely typos.
- **L3** — `auth_phone.ts:282-291`: Firestore user doc write uses `Timestamp.now()` rather than `FieldValue.serverTimestamp()`. Switch for consistency with the rest of the codebase and to avoid client-clock-skew records.
- **L4** — `auth_notifier.dart:160-164`: `signInWithCustomToken` happens *after* the response is parsed, no error handling around it. If Auth is temporarily unavailable, the user sees a generic error and the OTP code is already consumed.
- **L5** — `sign_in_page.dart:60-66`: email is validated only by `contains('@')`. Use a proper RFC-5322 lite regex or even just `value.contains(RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$'))`.
- **L6** — `auth_notifier.dart:135-170`: the `permission-denied` → `InvalidOtpException` mapping is fragile — any other server-side permission error becomes "invalid OTP" in the UI. Use a specific HttpsError detail field instead of the code.
- **L7** — Android intent filter uses `autoVerify="true"` (good) but I did not find an `assetlinks.json` reference in this review. Confirm it's deployed at `https://outalmaservice-d1e59.firebaseapp.com/.well-known/assetlinks.json`.
- **L8** — Two parallel functions (`requestPhoneOtp` vs `sendOtpTwilio`) both define `defineSecret('TWILIO_AUTH_TOKEN')` at module top-level. Works, but creates two `Secret` instances pointing at the same secret; harmless, but the codebase only needs one.

---

## 5. Good practices observed

- Phone uniqueness check in `verifyPhoneOtpAndSignUp` exists at the server (`isPhoneTakenByOtherUid`) — the *idea* is right even if (H3) the implementation has a race window.
- Twilio creds are managed via `defineSecret` (Cloud Secrets Manager) rather than plain env vars — correct and rotatable.
- Custom tokens are minted server-side with the uid derived from a server-side phone lookup — the right shape, even if the lookup source is wrong (C2).
- `signInWithEmailLink` enforced via `isSignInWithEmailLink` *before* attempting sign-in (`app.dart:60`) — prevents accidental sign-in from arbitrary deep links.
- Pending magic-link state is cleared after success (`auth_notifier.dart:349-351`) — avoids stale-state bugs across sessions.
- Firestore rules: bookings, chats, reviews, notifications, admin_logs, user_sessions are tightly locked down. `chats/{chatId}` is server-write-only — correct. `notifications` allows owners only the `read` field — correct.
- `revokeUserSessions` callable exists for admin remediation (`functions/src/index.ts:862-880`) — critical for post-incident response after fixing C1/C2.
- iOS entitlements are minimal — only `associated-domains`, no broad URL schemes, no keychain sharing, no aps-environment surprises.
- Android manifest doesn’t over-claim permissions (no SMS read, no contacts).
- Root `.gitignore` correctly globs `**/service-account*.json`, `**/*firebase-adminsdk*.json`, `secrets/`, `.env*` (with `!.env.example`).
- Twilio responses are correctly parsed and the `status === 'approved' && valid === true` double-check is applied (`auth_phone.ts:151-157`).

---

## 6. Priority fix order

1. **C1** — tighten `users/{uid}` rules so `phoneE164`, `email`, `id`, `createdAt`, `activeMode` are server-only (or at minimum immutable from client).
2. **C2** — resolve uid via `admin.auth().getUserByPhoneNumber` in `verifyPhoneOtpAndSignIn`; treat `updateUser` failures as fatal.
3. **H1** — App Check + Firestore-backed per-phone/per-IP rate limit on `requestPhoneOtp`.
4. **H4** — remove `sendOtpTwilio` / `verifyOtpTwilio` exports.
5. **H3** — wrap signup in a transaction on `phoneLocks/{phone}`.
6. Everything else can land in Phase 4.

Once C1+C2+H1 are fixed, the auth surface is materially safe for TestFlight. Without them, anyone with the app can hijack an arbitrary user's account.
