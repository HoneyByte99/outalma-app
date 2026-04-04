# Canonical Domain Model

This file is the single source of truth for all Dart models, Firestore field names,
TypeScript types, and Firestore rule assumptions. Any divergence between layers must
be resolved by aligning to this document.

Last updated: 2026-04-04

---

## BookingStatus

Canonical string values (stored as-is in Firestore):

```
requested   → client created, awaiting provider response
accepted    → provider accepted, chat unlocked
in_progress → service underway
done        → service completed, review unlocked
rejected    → provider rejected
cancelled   → cancelled by client or provider
```

State machine:
```
requested → accepted → in_progress → done
requested → rejected
requested → cancelled
```

No cancellation after `accepted` in MVP.

These names must match exactly across:
- Dart enum values
- Firestore document `status` field
- TypeScript `BookingStatus` type
- Firestore security rules checks
- UI label mapping

---

## AppUser

Firestore collection: `users/{uid}`

| Field | Type | Notes |
|---|---|---|
| `id` | String | Firebase Auth UID (document ID) |
| `displayName` | String | Public display name |
| `photoPath` | String? | Firebase Storage path (not URL) |
| `email` | String | From Firebase Auth |
| `phoneE164` | String? | Private — never exposed publicly |
| `country` | String | "FR" or "SN" |
| `activeMode` | String | "client" or "provider" — the current UI switch state |
| `pushToken` | String? | FCM token for notifications |
| `createdAt` | Timestamp | UTC |

`activeMode` is the Turo-style switch. It is separate from whether the user has an
active provider profile. A user can be `activeMode=provider` only if `providers/{uid}` exists
and `active=true`.

---

## Provider

Firestore collection: `providers/{uid}` (same UID as users/{uid})

| Field | Type | Notes |
|---|---|---|
| `uid` | String | Document ID, same as users/{uid} |
| `bio` | String? | Short description of the provider |
| `serviceArea` | String? | City or zone description |
| `active` | bool | Whether provider profile is active |
| `suspended` | bool | Set by admin — overrides active |
| `createdAt` | Timestamp | When provider profile was activated |

---

## BlockedSlot

Firestore collection: `providers/{uid}/blocked_slots/{slotId}`

| Field | Type | Notes |
|---|---|---|
| `id` | String | Document ID |
| `date` | Timestamp | Start of blocked period (stored as UTC noon to prevent timezone day-shift) |
| `endDate` | Timestamp? | End of blocked period. If null = entire day blocked |
| `reason` | String? | Optional reason ("Congé", "RDV perso"...) |
| `createdAt` | Timestamp | UTC |

---

## Service

Firestore collection: `services/{serviceId}` (public read)

| Field | Type | Notes |
|---|---|---|
| `id` | String | Document ID |
| `providerId` | String | UID of the owner (matches `providers/{uid}`) |
| `categoryId` | String | References a category label |
| `title` | String | Service title |
| `description` | String? | Full description |
| `photos` | List\<String\> | Firebase Storage paths |
| `priceType` | String | "hourly" or "fixed" |
| `price` | int | Price in smallest currency unit (centimes) |
| `published` | bool | Only published services are discoverable |
| `serviceZones` | List\<Map\> | `[{label, lat, lng, radiusKm}]` — intervention zones |
| `createdAt` | Timestamp | UTC |
| `updatedAt` | Timestamp | UTC |

`ownerId` is NOT used — the field is `providerId` for consistency with bookings.

### ServiceZone (value object, not a Firestore collection)

| Field | Type | Notes |
|---|---|---|
| `label` | String | Human-readable zone name (city, neighborhood) |
| `latitude` | double | Latitude |
| `longitude` | double | Longitude |
| `radiusKm` | double | Radius in kilometers |

---

## Booking

Firestore collection: `bookings/{bookingId}` (top-level, not subcollection)

| Field | Type | Notes |
|---|---|---|
| `id` | String | Document ID |
| `customerId` | String | UID of the client |
| `providerId` | String | UID of the provider |
| `serviceId` | String | Reference to the service |
| `status` | String | See BookingStatus above |
| `requestMessage` | String | Free-text message from client |
| `scheduledAt` | Timestamp? | Structured date/time for the appointment (preferred) |
| `schedule` | Map? | Legacy slot info (freeform, kept for backwards compat) |
| `addressSnapshot` | Map? | Client address at time of booking |
| `chatId` | String? | Set by `acceptBooking()` Cloud Function |
| `reminded24h` | bool | Flag for 24h reminder (set by sendBookingReminders) |
| `reminded1h` | bool | Flag for 1h reminder (set by sendBookingReminders) |
| `createdAt` | Timestamp | UTC |
| `acceptedAt` | Timestamp? | UTC — set by acceptBooking() |
| `rejectedAt` | Timestamp? | UTC — set by rejectBooking() |
| `cancelledAt` | Timestamp? | UTC — set by cancelBooking() |
| `startedAt` | Timestamp? | UTC — set by markInProgress() |
| `doneAt` | Timestamp? | UTC — set by confirmDone() |

`userId` is NOT used — fields are `customerId` and `providerId`.
`updatedAt` is NOT used — individual transition timestamps are used instead.

---

## Chat

Firestore collection: `chats/{chatId}`

| Field | Type | Notes |
|---|---|---|
| `id` | String | Document ID, derived as `chat_{bookingId}` |
| `bookingId` | String | The booking this chat belongs to |
| `participantIds` | List\<String\> | [customerId, providerId] |
| `customerId` | String | Denormalized for queries |
| `providerId` | String | Denormalized for queries |
| `createdAt` | Timestamp | Set by acceptBooking() |
| `lastMessageAt` | Timestamp? | Updated on each new message |

Chat documents are created exclusively by the `acceptBooking()` Cloud Function.
Clients cannot create chat documents directly.

---

## ChatMessage

Firestore collection: `chats/{chatId}/messages/{messageId}`

| Field | Type | Notes |
|---|---|---|
| `id` | String | Document ID |
| `chatId` | String | Parent chat ID |
| `senderId` | String | UID of the sender |
| `type` | String | "text", "image", or "voice" |
| `text` | String? | Present when type=text, or as caption for images |
| `mediaUrl` | String? | Present when type=image or type=voice (Storage URL) |
| `createdAt` | Timestamp | UTC — use `createdAt` not `sentAt` |

Firestore rules: message create requires `text OR mediaUrl` (not both mandatory).

Field name is `createdAt` (not `sentAt`) — aligns with all other collections.

---

## Review

Firestore collection: `reviews/{reviewId}`

| Field | Type | Notes |
|---|---|---|
| `id` | String | Document ID |
| `bookingId` | String | Booking this review belongs to |
| `reviewerId` | String | UID of the author |
| `revieweeId` | String | UID of the person being reviewed |
| `reviewerRole` | String | "client" or "provider" |
| `rating` | int | 1 to 5 |
| `comment` | String? | Free text |
| `createdAt` | Timestamp | UTC |

Reviews are bilateral: after `done`, both the client and provider can leave a review.
One review per (bookingId, reviewerRole) pair — enforced by rules.

---

## PhoneShare

Firestore collection: `bookings/{bookingId}/phoneShares/{uid}`

| Field | Type | Notes |
|---|---|---|
| `phone` | String | E164 format |
| `createdAt` | Timestamp | UTC |

Document ID is the UID of the user whose phone is shared.
Readable only when booking status is `accepted` or beyond.

---

## Report

Firestore collection: `reports/{reportId}`

| Field | Type | Notes |
|---|---|---|
| `id` | String | Document ID |
| `reporterId` | String | UID of the reporting user |
| `targetType` | String | "user", "service", "message" |
| `targetId` | String | ID of the reported resource |
| `reason` | String | Free text |
| `status` | String | "open", "resolved", "dismissed" |
| `createdAt` | Timestamp | UTC |

---

## Notification

Firestore collection: `notifications/{uid}/items/{notifId}`

| Field | Type | Notes |
|---|---|---|
| `type` | String | See notification types below |
| `title` | String | Notification title |
| `body` | String | Notification body |
| `bookingId` | String? | Related booking |
| `chatId` | String? | Related chat |
| `read` | bool | Read flag |
| `createdAt` | Timestamp | UTC |

Notification types: `new_message`, `booking_accepted`, `booking_rejected`, `booking_in_progress`, `booking_done`, `booking_reminder`

---

## Enums summary

```
BookingStatus : requested | accepted | in_progress | done | rejected | cancelled
UserRole      : customer | provider | admin   (technical auth role, not UI mode)
ActiveMode    : client | provider              (UI switch — stored on AppUser)
MessageType   : text | image | voice | system
PriceType     : hourly | fixed
Country       : FR | SN
ReviewerRole  : client | provider
TargetType    : user | service | message       (for reports)
ReportStatus  : open | resolved | dismissed
CategoryId    : menage | plomberie | jardinage | electricite | peinture | bricolage | gardeEnfants
```

---

## PhoneShare access rule

PhoneShare documents are readable by booking participants when:
```
booking.status ∈ { accepted, in_progress, done }
```
Not when: `requested`, `rejected`, `cancelled`.
