# Known gaps - logic inconsistency audit (2026-06-12)

Full-codebase audit of client/provider logic asymmetries (Flutter, Cloud Functions,
Firestore rules). Items are removed as they are fixed; re-date the file when a new
audit replaces it.

## Resolved 2026-06-12 (✅ deployed)

The provider-journey plan (Batches 1-5 below) was implemented and the
**Firestore rules + Cloud Functions were deployed to `outalmaservice-d1e59` on
2026-06-12** (build `1.0.0+23` to TestFlight). Server-authoritative behaviour is
live.

- **Batch 1 - Provider journey.** Provider inbox now has a Completed tab
  (`providerCompletedBookingsProvider`) listing done/rejected/cancelled bookings;
  this unlocks the provider→client review flow (shared `BookingDetailPage`, review
  section is bilateral). A `RatingSummary` widget surfaces the client's rating +
  review count on inbox cards and on the booking detail (provider viewer).
- **Batch 2 - Blocking = coupure totale.** `createBooking` refuses a blocked pair
  (either direction); the `reviews` create rule refuses a blocked pair;
  `discoverableServicesProvider` hides a blocked provider's services from search.
- **Batch 3 - Notifications.** `approveService`/`rejectService` notify the provider
  (audience: provider); new `onReviewCreated` trigger notifies the reviewee;
  booking reminders carry a `{type, bookingId}` push payload; `suspendProvider`
  notifies the provider; tapping a notification switches `activeMode` to the
  notification's audience before navigating.
- **Batch 4 - Booking/service UI.** A service can only be published with an active,
  non-suspended provider profile (services rule `publishAllowed()` + a friendly
  client-side guard). Inbox cards show a chat shortcut for any booking with a chat
  (active or completed).
- **Batch 5 - Contract debt.** `_providerToFirestore` no longer rewrites moderation
  fields on update (create vs update split); `_bookingToFirestore` now serializes
  `cancelReason`/`cancelledBy`.

### Round 2 - field-testing feedback (2026-06-12, deployed with the above)

- **Reservation safety (server).** `createBooking` now rejects an address outside
  the service's intervention zones (haversine), and rejects a slot overlapping
  (±60 min) an existing non-terminal booking. Services rule whitelists `categoryId`
  to the 7 catalogue categories (also closes the old #16).
- **Working hours + free slots.** `ProviderProfile.workingHourStart/End` (default
  8-18); the client booking step offers only free slots (working hours − blocked −
  booked − past) as chips instead of a free time picker. No more 4am requests.
- **Lazy onboarding.** Dashboard shows a non-blocking "complete your profile" nudge
  when bio/serviceArea are missing (instead of a blocking "activate" on a missing
  doc) - fixes "I can accept missions but the app says activate your profile".
- **Service cards.** Moderation `status` is read into the model and shown as an
  icon+colour badge (pending/rejected/online/offline). Inbox CTA "Open chat" →
  "More details". Lingering photo-removed snackbar fixed (cleared on dispose).
- **Chat images** bounded to 1024×1024 @ q80 on every platform.
- **Trust.** MarketplaceDisclaimer at booking, service detail and onboarding.
- **a11y.** Icon-first category chips.
- **RGPD.** Self-service export replaced by a `requestDataExport` request
  (`data_export_requests` collection, admin-fulfilled by email).

## Guest browsing + PII-free public profiles (2026-07-01)

Removes the login-first wall so visitors can explore before committing, without
exposing any PII. Rules + Cloud Functions in this batch must be deployed
(`firebase deploy`) and existing users backfilled before the client build ships.

- **Public projection.** New world-readable `public_profiles/{uid}` holding ONLY
  `{ displayName, photoPath?, country?, phoneVerified }` (no email/phone). Written
  exclusively by Cloud Functions: `mirrorPublicProfile` (onWrite of `users`, with
  delete + skip-unchanged) and `backfillPublicProfiles` (admin one-shot). Rule:
  `read: if true; write: if false`.
- **Guest reads.** Service cards, the public provider profile (header + reviews),
  and reviewer names now resolve display info from `publicProfileByIdProvider`
  instead of the `users` doc, so they render for signed-out visitors. `reviews`
  read opened to `if true` (trust signal, no PII); `users` stays signed-in only.
- **Guest routing.** `RouterNotifier` allows a guest on `/home`, `/service/:id`,
  `/provider-profile/:id`, `/reviews/:uid`, `/legal`; everything else → `/sign-in`.
- **Login-gated actions.** Booking (service-detail CTA) and switching to provider
  mode (ModeBadge) prompt sign-in for guests instead of proceeding.
- **Deploy checklist:** deploy rules + functions, then call `backfillPublicProfiles`
  once (admin) so pre-existing providers/reviewers have a projection.

## Still open

- **#12 (P2, minor) Cancellation UX.** At `requested` the provider terminates via
  *reject* and the client via *cancel* (both terminal - adequate). After acceptance,
  cancel for either role is an app-bar icon rather than a primary button. Acceptable
  for MVP; revisit if users miss it.
- **Wolof locale (P2).** App is FR/EN only. Icon-first affordances were added for
  low-literacy users, but a `wo` locale needs real translation content from a Wolof
  speaker (not machine output) - left for a dedicated translation pass.
- **Admin export fulfilment (P2).** `requestDataExport` files the request;
  compiling + emailing the export from the admin dashboard (and the email provider
  wiring) is still to be built on the admin side.

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
