# Authentication — Production Flow

> Status: **production-ready** (mai 2026, après élimination du workaround email-derived et du password classique).

## Overview

Outalma supports two authentication paths:

| Path | Identifier | Backend |
|---|---|---|
| **Email + magic link** | Email | Firebase Auth `sendSignInLinkToEmail` + Universal/App Links |
| **Phone + OTP** | E.164 phone number | Twilio Verify (via 3 Cloud Functions) |

Both paths share the same Firestore `users/{uid}` document and the same `AuthState` machine. The active path is chosen by the user in the sign-in / sign-up tabs.

## Phone OTP — server-side contract

Three callable Cloud Functions form the canonical pipeline:

### `requestPhoneOtp({ phone, channel? })`
- Validates `phone` is in E.164 format.
- Calls Twilio Verify `Verifications` endpoint on `sms` (default) or `call` channel.
- Returns `{ sentAt, channel }`. Throws `unavailable` on Twilio failure.
- **No authentication required** — anyone with a phone number can trigger an OTP.
  Rate limiting and abuse protection rely on Twilio's per-number quotas.

### `verifyPhoneOtpAndSignIn({ phone, code })`
- Validates `phone` (E.164) and `code` (4-8 digits).
- Calls Twilio `VerificationCheck`. Throws `permission-denied` if invalid/expired.
- Looks up the Outalma user by `phoneE164` in Firestore.
  - **No user found** → returns `{ newUser: true, phoneE164 }`. The client routes to sign-up.
  - **User found** → links phone to Firebase Auth user (idempotent), mints a **custom token**, returns `{ newUser: false, customToken, uid }`. The client signs in via `signInWithCustomToken`.

### `verifyPhoneOtpAndSignUp({ phone, code, displayName, country })`
- Validates `phone`, `code`, `displayName`, and `country` (`FR` or `SN`).
- Calls Twilio `VerificationCheck`. Throws `permission-denied` if invalid.
- Asserts the phone is **not already taken**. Throws `already-exists` otherwise.
- Creates the Firebase Auth user via `createUser({ phoneNumber, displayName })` — **no fake email, no password**.
- Creates the matching Firestore `users/{uid}` doc with:
  ```json
  {
    "displayName": "...",
    "email": "",
    "phoneE164": "+33...",
    "country": "FR" | "SN",
    "activeMode": "client",
    "createdAt": <Timestamp>
  }
  ```
- Mints a custom token; the client signs in via `signInWithCustomToken`.

All three functions use **`firebase-admin`** which bypasses Firestore rules — uniqueness checks and account creation are server-authoritative.

## Client-side flow

### Sign-up (phone)
1. Step 1 — user types name + phone, taps "Recevoir le code".
2. App calls `requestPhoneOtp(phone)`.
3. Step 2 — Twilio sends SMS. User enters the code.
4. App calls `verifyPhoneOtpAndSignUp({ phone, code, displayName, country })`.
5. On success: custom token → `signInWithCustomToken` → `authStateChanges` fires → router redirects to `/home`.

### Sign-in (phone)
1. Step 1 — user types phone, taps "Recevoir le code".
2. App calls `requestPhoneOtp(phone)`.
3. Step 2 — user enters the code.
4. App calls `verifyPhoneOtpAndSignIn({ phone, code })`.
5. If `newUser: false` → custom token → signed in.
6. If `newUser: true` → toast "Aucun compte trouvé" + redirect to sign-up.

### Country detection
Best-effort from the E.164 prefix:
- `+33...` → `FR`
- `+221...` → `SN`
- Anything else → `FR` (sensible default for the marketplace's main market). User can change country in profile.

## What is **not** allowed

- No phone change from the profile screen. Phone is set at signup and read-only afterwards. A dedicated OTP-verified phone change flow will be added later.
- No `isPhoneTaken` query from the client. Uniqueness is enforced exclusively by `verifyPhoneOtpAndSignUp` server-side.
- No fake-email derivation. Phone-based accounts have `email = ''` in Firestore and rely on `phoneNumber` as the canonical Firebase Auth identifier.

## Provider choice

Twilio Verify is the production OTP provider. Rationale:
- Works uniformly on iOS, Android, and Web — no APNs / no reCAPTCHA friction.
- SMS + Voice fallback ready (just toggle `channel: 'call'`).
- Server-side integration is simple HTTP, well-documented.

The OTP Lab (`/otp-lab` in debug builds) keeps a Firebase Phone Auth path for benchmarking, but Firebase Phone Auth is **not** wired to the production sign-in / sign-up flow.

## Observability

- Cloud Functions log every Twilio failure with `logger.error('Twilio … failed', { status, json })`.
- Firebase Auth records account creation; Firestore records the user doc creation timestamp.
- Twilio console lists every verification attempt (sandbox / production).

## Rotating Twilio credentials

Stored as Firebase secrets — never in code or repo:
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_VERIFY_SERVICE_SID`

Rotation:
```bash
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase deploy --only functions:requestPhoneOtp,functions:verifyPhoneOtpAndSignIn,functions:verifyPhoneOtpAndSignUp
```

## Future work

- Dedicated "change phone" flow: prompt OTP on the new number + verify ownership of the current one.
- WhatsApp channel as a cheaper alternative to SMS in Senegal — to evaluate during Phase 3 deliverability tests.
- Phase 3 deliverability tests (FR + SN, real numbers) to confirm Twilio is the right provider or trigger a switch to Vonage.

---

# Email Magic Link — Production Flow

## Overview

The email path is **passwordless**: users receive a one-time sign-in link in their inbox. Clicking it opens the app (via Universal Links on iOS / App Links on Android) and signs them in automatically. No password ever stored.

## Required Firebase Console setup (one-time)

These must be configured by an admin in Firebase Console before the flow works end-to-end:

1. **Authentication → Sign-in method → Email/Password** : ensure provider is enabled. **Toggle "Email link (passwordless sign-in)" ON.**
2. **Authentication → Settings → Authorized domains** : ensure `outalmaservice-d1e59.firebaseapp.com` and `outalmaservice-d1e59.web.app` are listed (added by default).
3. **Authentication → Templates → Email address sign-in** : customise sender display name to `Outalma`, subject to e.g. `Connectez-vous à Outalma`. Body text can be lightly customised; the link itself is auto-generated.

## Native setup (already done in repo)

- **iOS** : `ios/Runner/Runner.entitlements` declares Associated Domains for `applinks:outalmaservice-d1e59.firebaseapp.com` and `applinks:outalmaservice-d1e59.web.app`. The Xcode project references the entitlements file via `CODE_SIGN_ENTITLEMENTS`. Firebase auto-hosts the `apple-app-site-association` file at those domains, so no extra hosting setup is needed.
- **Android** : intent filter in `AndroidManifest.xml` declares `autoVerify="true"` for the same two hosts. Firebase auto-hosts `assetlinks.json`.

## Client flow

### Sign-up (email)
1. Step 1 — user types name + email, taps "Recevoir le lien".
2. App calls `AuthNotifier.requestEmailMagicLink(email, displayName, country)`. The notifier:
   - calls Firebase `sendSignInLinkToEmail` with `ActionCodeSettings` pointing at `https://outalmaservice-d1e59.firebaseapp.com/__/auth/links` and `handleCodeInApp: true`,
   - stores `email`, `displayName`, `country` in SharedPreferences so the link-handling step can recover them.
3. Step 2 — UI shows "Lien envoyé à xyz@..., ouvrez votre boîte mail".
4. User taps the link inside the email. The OS routes it to the Outalma app via Universal/App Links.
5. App's `OutalmaServiceApp` listens for incoming `Uri` via the `app_links` package and calls `AuthNotifier.completeEmailMagicLink(uri)`.
6. The notifier validates the link, signs in via `signInWithEmailLink(email, link)`, and — for first-time sign-ins — creates the Firestore user doc using the stashed displayName/country.
7. `authStateChanges` fires → router redirects to `/home`.

### Sign-in (email)
Same as sign-up, except no name/country are stashed. The link signs the user into the existing account.

## Cross-device caveat

Magic links must be opened **on the device that requested them** because the email address is stashed locally in SharedPreferences (Firebase API requirement). If the user requests the link on their phone but clicks it on a desktop, the desktop browser cannot complete the flow — the user must reopen the email on the phone.

A future hardening step could store the pending email server-side (keyed by an unguessable token in the link) and let the app fetch it.

## Limitations of the Firebase-native template

The email body is Firebase's standard template — we can customise:
- Sender display name (set to "Outalma")
- Subject line
- The `from` address suffix
- The body text (limited rich-text editor in Firebase Console)

For a fully branded HTML email, we would need to send the email ourselves (e.g. via SendGrid) using `admin.auth().generateSignInWithEmailLink(...)`. Out of scope for the current MVP.
