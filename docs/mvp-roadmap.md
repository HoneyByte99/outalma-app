# MVP Roadmap

Outalma MVP — France + Senegal, Android + iOS + Web.

Dernière mise à jour : 2026-04-04

---

## Phase 1 — Backend integrity (~95% done)

- [x] Align `BookingStatus` enum: `requested | accepted | in_progress | done | rejected | cancelled`
- [x] Complete `Booking` model: `customerId`, `providerId`, `requestMessage`, `scheduledAt`, `schedule`, `addressSnapshot`, `chatId`, timestamps
- [x] Complete `AppUser` model: `activeMode`, `country`, `phoneE164`, `pushToken`, `photoPath`
- [x] Complete `Service` model: `providerId`, `categoryId`, `photos`, `published`, `priceType`, `serviceZones`
- [x] Add `Chat` model + Firestore converter
- [x] Add `Provider` model + Firestore converter
- [x] Add `Review` model + Firestore converter
- [x] Add `PhoneShare` + `Report` models
- [x] Add `BlockedSlot` model
- [x] Remove redundant `fromJson` — converters are the single deserialization path
- [x] Implement `FirestoreUserRepository`
- [x] Implement `FirestoreBookingRepository`
- [x] Implement `FirestoreServiceRepository`
- [x] Implement `FirestoreChatRepository`
- [x] Cloud Functions: `createBooking`, `acceptBooking`, `rejectBooking`, `cancelBooking`, `markInProgress`, `confirmDone`
- [x] Cloud Functions: `setAdminClaim`
- [x] Cloud Functions trigger: `onBookingStatusChange` → push + in-app notification
- [x] Cloud Functions trigger: `onMessageCreate` → push + in-app notification (text/image/voice)
- [x] Cloud Functions scheduled: `sendBookingReminders` (24h + 1h avant scheduledAt)
- [x] Firestore rules: all collections secured
- [x] Storage rules: services photos, chat media, user avatars
- [ ] Serialization tests (BookingStatus roundtrip, Timestamp variants)
- [ ] Booking state machine unit tests

---

## Phase 2 — Auth + app shell (~90% done)

- [x] Design tokens: `OutalmaColors` with light/dark mode
- [x] GoRouter setup: all named routes declared, guarded by auth state
- [x] Riverpod: `authStateProvider`, `currentUserProvider`, stable UID pattern
- [x] Sign up (email)
- [x] Sign in
- [x] Mot de passe oublié (sendPasswordResetEmail)
- [x] Profile setup after signup (displayName, country, phone with country code picker)
- [x] Auth guard: redirect unauthenticated users to sign in
- [x] Mode switch UI (client <-> provider toggle, inline dans la home)
- [x] Bottom navigation shell
- [ ] Profile photo upload

---

## Phase 3 — Core client journey (~85% done)

- [x] Home page: catégories avec icônes, top services, location pill Uber Eats-style
- [x] Localisation: autocomplete Places API (New), rayon slider, favoris sauvegardés (SharedPreferences)
- [x] Filtrage par distance (Haversine) depuis la position choisie
- [x] Category browse + filter
- [x] Service detail page: photos, description, prix, zones sur carte
- [x] Booking request flow: date picker structuré (`scheduledAt`) + adresse autocomplete + message
- [x] Détection de conflits (bookings existants + créneaux bloqués)
- [x] Booking history: active + completed tabs
- [x] Mini calendrier client (TableCalendar 2 semaines, markers, filtre par jour)
- [x] Booking detail / status timeline
- [x] Annulation booking (status=requested uniquement)
- [ ] Service detail: affichage carte avec zones de service (Google Maps widget)
- [ ] Pagination sur les listes de services

---

## Phase 4 — Provider journey (~85% done)

- [x] Provider onboarding: activate provider mode (bio, zone)
- [x] Service CRUD: create, edit, publish/unpublish, multi-zones, photos
- [x] Provider inbox: list of booking requests + active bookings (tabs Demandes / En cours)
- [x] Accept / reject booking
- [x] Provider booking history
- [x] Calendrier provider (TableCalendar mois): markers bookings (bleu) + blocked slots (rouge)
- [x] Gestion créneaux bloqués (1-7 jours, raison, dates UTC noon)
- [x] Detail jour: bookings + blocked slots du jour sélectionné
- [x] Lien calendrier depuis l'inbox
- [ ] Provider dashboard / stats basiques

---

## Phase 5 — Chat + trust layer (~80% done)

- [x] Chat: accessible uniquement après booking accepted
- [x] Real-time message list + send
- [x] Image dans le chat (galerie + caméra, preview avant envoi avec caption)
- [x] Messages vocaux (enregistrement tap, stop/cancel, player avec progress bar)
- [x] Input bar WhatsApp-style: [galerie] [message [caméra]] [mic/send]
- [x] Contact unlock (phone visible après accept)
- [x] Review flow: bilateral — client reviews provider + provider reviews client après `done`
- [x] Push notifications: new message, booking status changes
- [x] In-app notifications: stockées dans Firestore, créées par Cloud Functions
- [x] Booking reminders (24h et 1h avant scheduledAt)
- [x] Chats list: tabs "En cours" / "Terminées" par statut booking
- [ ] Report flow (basic UI pour signaler un user/service/message)
- [ ] Fullscreen image viewer dans le chat (tap to zoom)

---

## Phase 6 — Hardening + release

- [x] Error states on critical screens (booking list, inbox, chat)
- [x] Loading states (skeleton loaders sur booking list)
- [x] Empty states avec messages et icônes utiles
- [x] Sign-out confirmation dialog redesigné
- [ ] Offline / no connection handling
- [ ] Performance: image caching, pagination on lists
- [ ] Firestore rules audit (all rules tested with 2 accounts)
- [ ] Coverage at 90%+ on domain, repositories, Cloud Functions, notifiers
- [ ] App store assets: icon, splash, store listings
- [ ] Release build passes on Android + iOS + Web
- [ ] Accessibility: Semantics labels sur les éléments interactifs
- [ ] Extract shared widgets (StatusChip, BookingCard, etc.)

---

## Admin panel (separate project — see `docs/admin/`)

- [ ] Phase 1: Fondations (auth admin, shell, dashboard)
- [ ] Phase 2: Modération (reports, suspension, suppression messages)
- [ ] Phase 3: Gestion des entités (users, providers, services)
- [ ] Phase 4: Bookings & configuration (catégories, rôles)
- [ ] Phase 5: Hardening

---

## Out of scope for MVP

- Payments (Stripe, mobile money)
- AI features
- Growth loops, referrals, promotions
- Premium subscriptions
- Multi-language UI (FR first, wolof/EN later)
- Advanced analytics / admin dashboards
