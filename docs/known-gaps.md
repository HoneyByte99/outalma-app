# Known gaps — logic inconsistency audit (2026-06-12)

Full-codebase audit of client/provider logic asymmetries (Flutter, Cloud Functions,
Firestore rules). Items are removed as they are fixed; re-date the file when a new
audit replaces it.

## Resolved 2026-06-12 (⚠️ server side needs deploy)

The provider-journey plan (Batches 1–5 below) was implemented. Code is on `main`;
the **Firestore rules + Cloud Functions changes are not yet deployed** — run
`firebase deploy --only firestore:rules,functions` and ship a build.

- **Batch 1 — Provider journey.** Provider inbox now has a Completed tab
  (`providerCompletedBookingsProvider`) listing done/rejected/cancelled bookings;
  this unlocks the provider→client review flow (shared `BookingDetailPage`, review
  section is bilateral). A `RatingSummary` widget surfaces the client's rating +
  review count on inbox cards and on the booking detail (provider viewer).
- **Batch 2 — Blocking = coupure totale.** `createBooking` refuses a blocked pair
  (either direction); the `reviews` create rule refuses a blocked pair;
  `discoverableServicesProvider` hides a blocked provider's services from search.
- **Batch 3 — Notifications.** `approveService`/`rejectService` notify the provider
  (audience: provider); new `onReviewCreated` trigger notifies the reviewee;
  booking reminders carry a `{type, bookingId}` push payload; `suspendProvider`
  notifies the provider; tapping a notification switches `activeMode` to the
  notification's audience before navigating.
- **Batch 4 — Booking/service UI.** A service can only be published with an active,
  non-suspended provider profile (services rule `publishAllowed()` + a friendly
  client-side guard). Inbox cards show a chat shortcut for any booking with a chat
  (active or completed).
- **Batch 5 — Contract debt.** `_providerToFirestore` no longer rewrites moderation
  fields on update (create vs update split); `_bookingToFirestore` now serializes
  `cancelReason`/`cancelledBy`.

## Still open

- **#12 (P2, minor) Cancellation UX.** At `requested` the provider terminates via
  *reject* and the client via *cancel* (both terminal — adequate). After acceptance,
  cancel for either role is an app-bar icon rather than a primary button. Acceptable
  for MVP; revisit if users miss it.
- **#16 (P3) `categoryId` not validated server-side.** A client could write a service
  with an arbitrary `categoryId`; Dart falls back to `menage` on unknown values (no
  crash, data-quality only). Left as-is for MVP — a hard-coded enum check in rules is
  brittle; revisit if a typed category registry lands.

## Verified healthy (no need to re-audit)

- Booking state machine aligned across Dart / TypeScript / rules / docs.
- Phone share correctly gated to `accepted/in_progress/done`.
- Chat becomes read-only after `done`; chat only created by `acceptBooking`.
- Review duplicate prevention (deterministic `{bookingId}_{reviewerId}` id) and
  `done`-only window are server-enforced and symmetric.
- Account deletion (RGPD) cleans both modes' data.
- Booking lifecycle notifications (requested/accepted/rejected/cancelled/
  in_progress/done) are complete, push + in-app, with correct tab audience.
- All "Critical known risks" from the pre-rewrite CLAUDE.md (model/enum
  mismatches, missing repositories, no navigation, no notifications) are fixed.
