# Booking Invariants

## Canonical statuses

```
requested   → client created, awaiting provider
accepted    → provider accepted, chat unlocked
in_progress → service underway
done        → service completed, reviews unlocked
rejected    → provider rejected
cancelled   → cancelled before accept
```

## State machine

```
requested → accepted     (provider: acceptBooking)
requested   → rejected     (provider: rejectBooking)
requested   → cancelled    (client OR provider: cancelBooking)
accepted    → in_progress  (provider: markInProgress)
accepted    → cancelled    (client OR provider: cancelBooking, with reason)
in_progress → done         (client: confirmDone)
in_progress → cancelled    (client OR provider: cancelBooking, with reason)
```

No other transitions are valid. A booking may be cancelled by either party
while it is still active (requested, accepted or in_progress); cancellation
after acceptance records `cancelReason` + `cancelledBy`. `done`, `rejected`
and `cancelled` are terminal.

## Rules

- Client creates booking requests via `createBooking()`.
- Provider accepts or rejects via `acceptBooking()` / `rejectBooking()`.
- Either party can cancel via `cancelBooking()` while status ∈ {requested, accepted, in_progress}; an optional reason is stored.
- Provider triggers `in_progress` via `markInProgress()`.
- Client confirms completion via `confirmDone()`.
- Chat is created only by `acceptBooking()` (never exists for a booking cancelled/rejected while still `requested`). If a booking is cancelled AFTER acceptance, the chat remains readable to participants as history.
- Phone number (PhoneShare) is readable by participants when `status ∈ {accepted, in_progress, done}`.
- Reviews are bilateral: after `done`, both client and provider can leave a review.
- All status transitions are server-authoritative (Cloud Functions only).
- Dart, Firestore documents, Firestore rules, and TypeScript must use identical status strings.

## Non-negotiable

If any booking contract is ambiguous between layers, stop and align to
`docs/domain-model-canonical.md` before building further.
