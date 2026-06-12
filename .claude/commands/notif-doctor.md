# /notif-doctor — Notification delivery health check

When the user runs `/notif-doctor`, produce a notification-delivery health
report from live Firestore data and Cloud Functions logs.

**Privacy rule (non-negotiable): never output emails, names, phone numbers or
any PII. Identify users by uid only.**

## Background

`NotificationService.initialize()` writes a `notifDebug` map on
`users/{uid}` at each app foreground (step, platform, authStatus,
apnsPresent, fcmTokenPresent, fcmError, ts). A device can receive pushes only
if `users/{uid}.pushToken` is set. Known failure mode: iOS devices whose
launch-time APNs registration failed once (fix: SceneDelegate re-registration,
commit f9b2c4f — needs build ≥ 1.0.0+23 on the device).

## Steps

1. **Query device states** with the Firebase MCP tools
   (`firestore_query_collection` on `users`):
   - users where `notifDebug.step` IN
     `["getToken_threw", "token_null", "apns_polled", "permission_resolved", "token_saved"]`
     (limit ~50). Do NOT add an `order` clause — there is no composite index
     for step+ts and diagnostics must not add prod indexes; sort by
     `notifDebug.ts` yourself after fetching;
   - users where `notifDebug.authStatus` EQUAL
     `"AuthorizationStatus.denied"` (permission refused — app banner should
     be guiding them, not a bug).
   Skip seeded accounts (`_seeded == true` or uid starting with `seed_`).

2. **Classify each real user** (uid only):
   - `OK` — pushToken present;
   - `STUCK_APNS` — iOS, authStatus authorized, apnsPresent false or
     fcmError contains `apns-token-not-set`, and NO pushToken → the bug the
     SceneDelegate fix addresses; these should heal after the fixed build;
   - `PERMISSION_DENIED` — authStatus denied/notDetermined → user-side,
     not a code bug;
   - `OTHER` — anything else (inspect fcmError).

3. **Check the send pipeline** with `functions_get_logs` (min_severity
   WARNING, last 48h) for the notification-sending functions (e.g.
   `onMessageCreate`, `onBookingStatusChange`): count `messaging/registration-token-not-registered`,
   `invalid-argument` and other send errors.

4. **Report** (anonymized):
   - counts per category + uid list for STUCK_APNS and OTHER;
   - distribution of `notifDebug.step` and most recent `ts` per stuck device
     (a stale ts means the user has not opened the app since the fix);
   - send-pipeline error summary from the logs;
   - verdict: is delivery healthy? did previously-stuck devices heal since
     the last build? name (uid) who to watch.
   - Track healing across runs: compare against the baseline noted in the
     auto-memory file `notif-apns-bug-2026-06-12` and update that memory with
     the new state.

5. If everything is healthy across two consecutive runs after the fixed
   build ships, recommend removing the `_writeDebug` diagnostics from
   `NotificationService` (they were added only for this investigation).
