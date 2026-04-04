# Outalma — Admin & Moderation Panel

Panel web séparé de l'app mobile, destiné à la gestion et la modération de la plateforme.

---

## 0. Pourquoi un panel séparé

- **Contexte d'usage différent** : l'admin travaille sur desktop avec tableaux, filtres, bulk actions. L'app mobile est optimisée pour clients et prestataires en mouvement.
- **Sécurité** : le code admin (suspension, suppression, lecture de signalements) ne doit pas être dans le bundle téléchargé par les utilisateurs.
- **UX incompatible** : dashboard admin ≠ mobile-first marketplace.

---

## 1. Architecture technique

| Aspect | Choix |
|--------|-------|
| Framework | Flutter Web (projet séparé dans le monorepo) |
| Auth | Firebase Auth — même projet Firebase (`outalmaservice-d1e59`) |
| Autorisation | Custom claims Firebase (`admin: true`, `moderator: true`) |
| Backend | Mêmes Cloud Functions que l'app mobile + fonctions admin dédiées |
| State management | Riverpod |
| Navigation | GoRouter |

### Pourquoi Flutter Web (pas Next.js)

- Réutilisation des modèles domain (Dart), enums, converters
- Même Firebase SDK, même auth, même Firestore
- Zéro duplication de la logique métier
- Pour un MVP admin simple, Flutter Web suffit largement
- Si le besoin évolue vers un dashboard très riche (analytics, charts complexes), on pourra migrer vers Next.js plus tard

### Structure du projet

```
outalma-admin/          ← nouveau projet Flutter Web
  lib/
    src/
      domain/           ← partagé via path dependency ou copie
      data/
      application/
      features/
        dashboard/
        bookings/
        users/
        services/
        reports/
        moderation/
```

Alternative : package Dart partagé dans un monorepo pour le domain layer.

---

## 2. Rôles et permissions

### Deux rôles admin pour le MVP

| Rôle | Custom claim | Accès |
|------|-------------|-------|
| **admin** | `admin: true` | Accès total : suspendre, supprimer, gérer rôles, voir stats, configurer catégories |
| **moderator** | `moderator: true` | Sous-ensemble : lire signalements, modérer messages, suspendre temporairement un provider/service |

### Matrice de permissions

| Action | admin | moderator |
|--------|:-----:|:---------:|
| Voir dashboard / stats | x | x |
| Lire tous les bookings | x | x |
| Lire tous les users | x | x |
| Lire tous les services | x | x |
| Lire les signalements | x | x |
| Résoudre / rejeter un signalement | x | x |
| Suspendre un provider | x | x |
| Dé-suspendre un provider | x | - |
| Masquer un service (`published=false`) | x | x |
| Republier un service | x | - |
| Supprimer un message (modération) | x | x |
| Gérer les catégories de services | x | - |
| Attribuer le rôle admin | x | - |
| Attribuer le rôle moderator | x | - |
| Révoquer un rôle | x | - |
| Voir les logs d'actions admin | x | - |

### Attribution des rôles

- **Bootstrapping** : le premier admin est créé manuellement via Firebase Console (custom claim `admin: true` sur le UID fondateur).
- **Ensuite** : un admin peut promouvoir d'autres users via `setAdminClaim()` (déjà implémenté) et un nouveau `setModeratorClaim()`.

---

## 3. Fonctionnalités MVP

### 3.1 Dashboard

Vue d'ensemble rapide :
- Nombre de bookings actifs (requested + accepted + in_progress)
- Nombre de signalements ouverts
- Nombre de providers actifs
- Nombre de services publiés
- Bookings récents (dernières 24h)

### 3.2 Gestion des utilisateurs

- Liste paginée des users (recherche par nom, email)
- Fiche user : profil, mode actif, bookings, reviews, signalements
- Actions : voir profil provider associé, suspendre/dé-suspendre

### 3.3 Gestion des providers

- Liste paginée des providers (actifs, suspendus, tous)
- Fiche provider : bio, zone, services, bookings, reviews, signalements
- Actions : suspendre, dé-suspendre, voir services

### 3.4 Gestion des services

- Liste paginée (par catégorie, par statut published/unpublished)
- Fiche service : détails, photos, zones, bookings liés
- Actions : masquer (unpublish), republier

### 3.5 Gestion des bookings

- Liste paginée avec filtres (par statut, par date, par provider, par client)
- Fiche booking : timeline complète, chat associé, reviews
- Lecture seule — les transitions restent server-authoritative
- Exception : un admin peut annuler un booking litigieux via `cancelBooking()` (le bypass admin est déjà en place dans les Cloud Functions)

### 3.6 Modération des signalements

- Liste des reports ouverts (triés par date)
- Fiche report : type (user/service/message), cible, raison, auteur
- Actions : résoudre, rejeter, prendre action (suspendre le provider, masquer le service, supprimer le message)
- Historique des reports résolus

### 3.7 Modération du chat

- Accès en lecture aux conversations signalées
- Suppression de messages individuels via `deleteMessage()`
- Aucun accès aux conversations non signalées (vie privée)

### 3.8 Gestion des catégories

- CRUD sur `service_types/{categoryId}`
- Activer/désactiver une catégorie
- Modifier l'ordre d'affichage

---

## 4. Cloud Functions admin (existantes + à ajouter)

### Existantes

| Fonction | Statut |
|----------|--------|
| `setAdminClaim(uid, admin)` | Déployée |
| `cancelBooking(bookingId)` | Déployée (bypass admin intégré) |
| `acceptBooking(bookingId)` | Déployée (bypass admin intégré) |
| `rejectBooking(bookingId)` | Déployée (bypass admin intégré) |
| `markInProgress(bookingId)` | Déployée (bypass admin intégré) |
| `confirmDone(bookingId)` | Déployée (bypass admin intégré) |

### À ajouter

| Fonction | Effet |
|----------|-------|
| `setModeratorClaim(uid, moderator)` | Pose ou retire le custom claim `moderator` |
| `suspendProvider(uid, reason?)` | Set `providers/{uid}.suspended=true`, unpublish tous ses services |
| `unsuspendProvider(uid)` | Set `providers/{uid}.suspended=false` |
| `removeService(serviceId)` | Set `services/{serviceId}.published=false` |
| `deleteMessage(chatId, messageId)` | Supprime le message (soft delete ou hard delete) |
| `resolveReport(reportId, action, notes?)` | Marque le report comme résolu + log l'action prise |

---

## 5. Firestore rules — ajouts nécessaires

Les rules actuelles vérifient `request.auth.token.admin == true` pour :
- Lecture/écriture sur `users`, `providers`, `services`, `bookings`
- Lecture/modération sur `reports`

À ajouter :
- Vérification du claim `moderator` pour les actions de modération
- Rule helper : `isAdminOrModerator()` = `request.auth.token.admin == true || request.auth.token.moderator == true`
- `reports` : lecture et update par admin OU moderator
- `chats/messages` : suppression par admin OU moderator (uniquement pour les chats signalés, enforced côté function)

---

## 6. Sécurité

- **Deny-by-default** : le panel admin ne peut rien faire que les Cloud Functions ne permettent pas.
- **Audit trail** : chaque action admin/mod est loggée (collection `admin_logs/{logId}`) avec : `actorUid`, `action`, `targetType`, `targetId`, `timestamp`, `notes`.
- **Pas d'accès direct Firestore** : toutes les mutations passent par Cloud Functions pour garantir la cohérence.
- **Lectures directes** : les lectures Firestore sont autorisées pour admin/moderator via les rules (pas besoin de passer par des functions pour lire).
- **Session** : Firebase Auth standard, custom claims vérifiés côté client ET côté rules/functions.

---

## 7. UX du panel

### Navigation

```
Sidebar:
  - Dashboard
  - Utilisateurs
  - Providers
  - Services
  - Bookings
  - Signalements
  - Catégories (admin only)
  - Paramètres (admin only)
```

### Principes

- Desktop-first (responsive mais pas mobile-optimized)
- Tableaux avec pagination, tri, recherche
- Fiches détaillées en slide-over ou page dédiée
- Actions destructives avec confirmation
- Feedback clair sur chaque action (snackbar succès/erreur)

---

## 8. Hors scope admin MVP

- Analytics avancées (graphiques, tendances, cohortes)
- Export CSV / rapports
- Système de tickets support
- Gestion des paiements / factures
- Gestion des promotions / coupons
- Bulk actions (suspension en masse, etc.)
- Notifications push depuis l'admin
- Multi-langue admin (français uniquement)
