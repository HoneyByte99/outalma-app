# Known gaps — logic inconsistency audit (2026-06-12)

Full-codebase audit of client/provider logic asymmetries (Flutter, Cloud Functions,
Firestore rules). Items are grouped in priority-ordered batches. Remove items as
they are fixed; re-date the file when a new audit replaces it.

In flight on 2026-06-12 (do not re-report): blocked-users management page
(`lib/src/features/profile/blocked_users_page.dart`, staged in a parallel session).
Already shipped: notifications split by Client/Provider tabs (9d0713d).

## Batch 1 — Provider journey is incomplete (P0, MVP-critical)

1. **Provider can never see done/cancelled/rejected bookings.**
   `BookingListPage` is already mode-aware with an Active/Done split
   (`lib/src/features/booking/booking_list_page.dart:96`), but the router redirect
   sends any `/bookings` access back to the provider dashboard while in provider
   mode (`lib/src/app/router.dart:150`), and the provider shell has no tab for it
   (`lib/src/app/app_shell.dart`, branches `[2, 3, 4, 5]`). The provider inbox only
   shows `requested` + `accepted/in_progress`. Fix is small: expose the existing
   screen in provider mode.
2. **Consequence: the provider can almost never review the client.** The review
   entry point exists in booking detail for both roles, but the provider's only
   path to a `done` booking is the "booking done" notification deep-link. Same for
   re-reading the chat of a finished booking.
3. **Provider→client reviews are written but displayed nowhere.** When a provider
   receives a request they see zero trust signal about the client (no rating, no
   reviews) — `booking_detail_page.dart` only links to the provider profile for the
   client side. Clients see the provider's full public profile before booking.

## Batch 2 — Blocking is inconsistent between chat and booking (P0, needs a product decision)

4. **A blocked client can still book the provider who blocked them.**
   `createBooking` (`functions/src/index.ts:238`) has no block check and the
   provider receives the "new booking" push. If accepted, `acceptBooking` creates a
   chat in which neither party can write, because `notBlockedPair`
   (`firebase/firestore.rules:186`) refuses messages between blocked pairs:
   accepted booking + dead chat. Decide: reject at `createBooking` server-side, or
   allow and lift the chat block for that pair — current state is neither.
5. **A blocked user can leave a review** (`firebase/firestore.rules:291`, no block
   check on review create).
6. **Services of a blocked provider remain discoverable/bookable** in home search.
   Product decision; must end up consistent with item 4.
   - Non-gap (verified): pushes for chat messages from blocked users cannot happen —
     message creation is already denied by rules, so `onMessageCreate` never fires.

## Batch 3 — Missing notifications (P1)

7. **Service approve/reject by moderation never notifies the provider** —
   `approveService`/`rejectService` call neither `sendPushToUsers` nor
   `createNotification`. A rejected provider never learns why.
8. **No notification when a review is received** (no trigger on `reviews/`), in
   either direction. Breaks the marketplace feedback loop.
9. **24h/1h booking reminders have no deep-link** — push payload carries no
   `bookingId` (`functions/src/index.ts:947`); tapping opens nothing useful.
10. Minor: report push to staff has no in-app counterpart; ban/suspension produce
    no notification to the affected user; global
    `unreadNotificationsCountProvider` is not split per mode (inconsistent with
    the Client/Provider tabs); `/booking/:id` and `/chat/:id` deep-links do not
    switch `activeMode` to match the notification audience.

## Batch 4 — Booking lifecycle UI holes (P2)

11. **A service can be published without a completed/active provider profile**
    (`lib/src/features/provider/service_form_page.dart:214` writes
    `published: true` with no onboarding check). Should be enforced server-side
    (rules or function), not only in UI.
12. Cancellation UX: at `requested` only the client has a cancel button (invariants
    allow both parties); after acceptance, cancel is hidden behind an app-bar icon
    for both roles.
13. No chat shortcut on `done` booking cards (detail page has one, list does not).

## Batch 5 — Contract debt / hygiene (P3, quick)

14. `_bookingToFirestore` omits `cancelReason`/`cancelledBy` (latent: clients never
    write bookings today).
15. `_providerToFirestore` serializes `suspended`, which rules forbid on client
    writes (latent permission error).
16. `categoryId` is not validated in Cloud Functions; Dart silently falls back to
    `menage` on unknown values.

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
