# Outalma — Spec MVP

Marketplace de services à domicile (client ↔ provider), une seule app, France + Sénégal.
Cibles : Android, iOS, Web — même codebase Flutter.
Scope MVP : 100–1 000 users. Pas de paiement intégré.

---

## 0. Décisions produit (non négociables)

1. **Un compte, deux modes.** Un utilisateur peut être client et provider. Switch UI persistant façon Turo. L'`activeMode` est stocké sur le profil user.

2. **Machine d'état booking stricte.**
   ```
   requested → accepted    (provider: acceptBooking)
   requested → rejected    (provider: rejectBooking)
   requested → cancelled   (client OU provider: cancelBooking)
   accepted  → in_progress (provider: markInProgress)
   in_progress → done      (client: confirmDone)
   ```
   Pas d'annulation après accept en MVP. Pas d'autre transition directe.

3. **Chat booking-gated.** Pas de messagerie libre. Un chat est créé uniquement par `acceptBooking()`. Inaccessible avant et après annulation/rejet.

4. **Téléphone privé (BlaBlaCar).** Le numéro n'est jamais public. Il devient lisible pour les deux participants dès que le booking est `accepted`, et reste lisible jusqu'à `done`.

5. **Server-authoritative.** Toutes les transitions de statut passent par Cloud Functions. Le client ne peut jamais écrire `status` directement.

6. **Reviews bilatérales.** Après `done`, le client note le provider ET le provider note le client. Chaque booking génère au plus 2 reviews.

---

## 1. UX Pillars

- **Uber (simplicité)** : 3 étapes max pour booker — service → créneau + adresse + message → envoyer.
- **BlaBlaCar (confiance)** : profil + avis + contact unlock après accept + reporting.
- **Turo (switch mode)** : un switch clair "Mode Client / Mode Provider" dans l'app.
- **Map utile** : affichage distance + zone de service, pas de suivi live en MVP.

---

## 2. Modules MVP

### Client
- Auth + profil
- Browse / Search services (catégories, liste, filtre simple)
- Service detail + zone de service
- Créer une demande de booking (créneau + adresse + message libre)
- Suivi booking (timeline de statuts)
- Chat (après accept uniquement)
- Laisser un avis (après done)

### Provider
- Activation du mode provider (sans validation externe)
- CRUD services (photos, zone, prix)
- Inbox de demandes + accept/reject
- Marquer un booking en cours (in_progress)
- Gestion bookings (actifs + historique)
- Chat (par booking)
- Laisser un avis sur le client (après done)

### Admin (web — hors scope app mobile)
- Suspendre un provider ou un service
- Lire les bookings
- Supprimer un message (modération)
- Gérer les reports

---

## 3. Flows

### Flow client (happy path)
```
Browse/Search
  → Service detail
  → Booking request (message + créneau + adresse)
  → [CF] createBooking → status=requested
  → Attente réponse provider
  → [CF] acceptBooking → status=accepted + chat créé
  → Chat ouvert + contact déverrouillé
  → [CF] markInProgress → status=in_progress
  → [CF] confirmDone → status=done
  → Laisser un avis
```

### Flow provider
```
Inbox → Voir demande
  → acceptBooking() ou rejectBooking()
  → (si accept) Chat + coordonnées client visibles
  → Marquer "en cours" → markInProgress()
  → Client confirme done → status=done
  → Laisser un avis sur le client
```

---

## 4. Schéma Firestore

### `service_types/{categoryId}`
Collection de référence — définit les catégories de services autorisées. Document ID = valeur de `categoryId`.

| Champ | Type | Notes |
|---|---|---|
| `label` | String | Nom affiché (ex: "Ménage") |
| `active` | bool | Si `false`, la catégorie n'est plus proposable |
| `sortOrder` | int | Ordre d'affichage |
| `createdAt` | Timestamp | UTC |

### `users/{uid}`
| Champ | Type | Notes |
|---|---|---|
| `displayName` | String | Nom public |
| `email` | String | Sync depuis Firebase Auth |
| `photoPath` | String? | Chemin Firebase Storage (pas d'URL) |
| `phoneE164` | String? | Privé — jamais exposé publiquement |
| `country` | String | "FR" ou "SN" |
| `activeMode` | String | "client" ou "provider" |
| `pushToken` | String? | Token FCM pour les notifications |
| `createdAt` | Timestamp | UTC |

### `providers/{uid}`
Même UID que `users/{uid}`. Créé quand l'utilisateur active le mode provider.

| Champ | Type | Notes |
|---|---|---|
| `bio` | String? | Présentation courte |
| `serviceArea` | String? | Ville ou zone d'intervention |
| `active` | bool | Profil provider actif |
| `suspended` | bool | Mis par admin — désactive le provider |
| `createdAt` | Timestamp | UTC |

### `services/{serviceId}`
Lecture publique.

| Champ | Type | Notes |
|---|---|---|
| `providerId` | String | UID du provider |
| `categoryId` | String | Voir catégories ci-dessous |
| `title` | String | Titre du service |
| `description` | String? | Description complète |
| `photos` | List\<String\> | Chemins Firebase Storage |
| `priceType` | String | "hourly" ou "fixed" |
| `price` | int | En centimes |
| `published` | bool | Seuls les services publiés sont visibles |
| `serviceZones` | Array\<Map\> | Zones d'intervention `[{label, lat, lng, radiusKm}]` |
| `createdAt` | Timestamp | UTC |
| `updatedAt` | Timestamp | UTC |

**Catégories MVP (valeurs de `categoryId`) :**
- `menage` — Ménage & entretien
- `plomberie` — Plomberie
- `jardinage` — Jardinage & extérieur
- `electricite` — Électricité
- `peinture` — Peinture
- `bricolage` — Bricolage & montage
- `gardeEnfants` — Garde d'enfants

Les catégories sont contrôlées par la collection `service_types/`. Pas de catégorie libre — c'est l'admin qui définit les types de service disponibles.

### `bookings/{bookingId}`
Collection racine (pas de sous-collection).

| Champ | Type | Notes |
|---|---|---|
| `customerId` | String | UID du client |
| `providerId` | String | UID du provider |
| `serviceId` | String | Référence au service |
| `status` | String | Voir machine d'état section 0 |
| `requestMessage` | String | Message libre du client |
| `schedule` | Map? | Créneau souhaité (champ libre MVP) |
| `addressSnapshot` | Map? | Adresse du client au moment du booking |
| `chatId` | String? | Défini par `acceptBooking()` |
| `createdAt` | Timestamp | UTC |
| `acceptedAt` | Timestamp? | Défini par `acceptBooking()` |
| `rejectedAt` | Timestamp? | Défini par `rejectBooking()` |
| `cancelledAt` | Timestamp? | Défini par `cancelBooking()` |
| `startedAt` | Timestamp? | Défini par `markInProgress()` |
| `doneAt` | Timestamp? | Défini par `confirmDone()` |

### `chats/{chatId}`
Créé exclusivement par `acceptBooking()`. ID dérivé : `chat_{bookingId}`.

| Champ | Type | Notes |
|---|---|---|
| `bookingId` | String | Booking parent |
| `participantIds` | List\<String\> | [customerId, providerId] |
| `createdAt` | Timestamp | UTC |
| `lastMessageAt` | Timestamp? | Mis à jour à chaque message |

### `chats/{chatId}/messages/{messageId}`
| Champ | Type | Notes |
|---|---|---|
| `chatId` | String | Dénormalisé pour éviter les requêtes parent |
| `senderId` | String | UID de l'expéditeur |
| `type` | String | "text" ou "image" |
| `text` | String? | Présent si type=text |
| `mediaUrl` | String? | URL Storage si type=image |
| `createdAt` | Timestamp | UTC |

### `reviews/{reviewId}`
| Champ | Type | Notes |
|---|---|---|
| `bookingId` | String | Booking concerné |
| `reviewerId` | String | UID de l'auteur |
| `revieweeId` | String | UID de la personne notée |
| `reviewerRole` | String | "client" ou "provider" |
| `rating` | int | 1 à 5 |
| `comment` | String? | Texte libre |
| `createdAt` | Timestamp | UTC |

Un booking génère au plus 2 documents review (un par sens).

### `bookings/{bookingId}/phoneShares/{uid}`
| Champ | Type | Notes |
|---|---|---|
| `phone` | String | Format E164 |
| `createdAt` | Timestamp | UTC |

L'ID du document est le UID de l'utilisateur dont le numéro est partagé.
Lisible par les participants dès que `status ∈ {accepted, in_progress, done}`.

### `reports/{reportId}`
| Champ | Type | Notes |
|---|---|---|
| `reporterId` | String | UID du signaleur |
| `targetType` | String | "user", "service" ou "message" |
| `targetId` | String | ID de la ressource signalée |
| `reason` | String | Texte libre |
| `status` | String | "open", "resolved" ou "dismissed" |
| `createdAt` | Timestamp | UTC |

---

## 5. Modèle de sécurité

Deny-by-default. Règles complètes dans `firebase/firestore.rules`.

| Collection | Règle |
|---|---|
| `users` | Lecture/écriture = soi-même ou admin |
| `providers` | Lecture publique ; écriture = soi-même ou admin |
| `services` | Lecture publique ; écriture = provider owner ou admin |
| `bookings` | Lecture = participants ou admin ; **statut non modifiable par le client** — Cloud Functions seulement |
| `chats` | Lecture/écriture = participants ou admin ; création par Cloud Function uniquement |
| `chats/messages` | Lecture = participants ; création = participant authentifié (senderId = uid) |
| `phoneShares` | Lisible si `status ∈ {accepted, in_progress, done}` et participant |
| `reviews` | Lecture publique ; création = reviewer authentifié, une fois par sens par booking |
| `reports` | Création = tout utilisateur authentifié ; lecture/modération = admin |

---

## 6. Cloud Functions

### Callable (client → server)

| Fonction | Déclencheur | Préconditions | Effet |
|---|---|---|---|
| `createBooking(providerId, serviceId, requestMessage, schedule?, addressSnapshot?)` | Client | Auth requis | Crée booking status=requested |
| `acceptBooking(bookingId)` | Provider | status=requested, appelant=provider | status=accepted, crée chat, set chatId + acceptedAt |
| `rejectBooking(bookingId)` | Provider | status=requested, appelant=provider | status=rejected, set rejectedAt |
| `cancelBooking(bookingId)` | Client ou Provider | status=requested, appelant=participant | status=cancelled, set cancelledAt |
| `markInProgress(bookingId)` | Provider | status=accepted, appelant=provider | status=in_progress, set startedAt |
| `confirmDone(bookingId)` | Client | status=in_progress, appelant=client | status=done, set doneAt |
| `setAdminClaim(uid, admin)` | Admin | Appelant=admin | Pose ou retire le custom claim admin |

### Triggers Firestore

| Trigger | Événement | Effet |
|---|---|---|
| `onMessageCreate` | `chats/{chatId}/messages/{messageId}` créé | Notif push à l'autre participant ; met à jour `lastMessageAt` sur le chat |
| `onBookingStatusChange` | `bookings/{bookingId}` mis à jour (status change) | Notif push au participant concerné selon la transition |

### Admin callable

| Fonction | Effet |
|---|---|
| `suspendProvider(uid)` | Set `providers/{uid}.suspended=true` |
| `removeService(serviceId)` | Set `services/{serviceId}.published=false` |
| `deleteMessage(chatId, messageId)` | Supprime le message (modération) |

---

## 7. Stack technique

| Couche | Choix |
|---|---|
| App | Flutter (Android + iOS + Web) |
| State management | Riverpod |
| Navigation | GoRouter |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Functions Gen2) |
| Functions runtime | Node 20 / TypeScript |
| Admin | Web séparé (Next.js) — hors scope app mobile MVP |

---

## 8. Hors scope MVP

- Paiement intégré (Stripe, mobile money)
- Vérification d'identité (KYC)
- Géolocalisation temps réel
- IA et recommandations
- Abonnements premium
- Croissance, referrals, promotions
- Admin avancé (analytics, bulk actions)
- Multi-langue (français en priorité, wolof/anglais post-MVP)
