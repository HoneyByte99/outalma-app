# Admin Panel — Roadmap

---

## Phase 1 — Fondations (priorité haute)

Setup du projet et modération de base. L'objectif est d'avoir un outil fonctionnel pour gérer les premiers signalements.

- [ ] Créer le projet Flutter Web (`outalma-admin/`) avec path dependency vers le domain layer
- [ ] Auth admin : login + vérification custom claim `admin`/`moderator`
- [ ] Guard de route : redirection si pas admin/moderator
- [ ] Shell : sidebar navigation + layout desktop
- [ ] Cloud Function `setModeratorClaim(uid, moderator)`
- [ ] Dashboard : compteurs de base (bookings actifs, reports ouverts, providers, services)

---

## Phase 2 — Modération (priorité haute)

Le coeur du besoin admin au lancement.

- [ ] Liste des signalements (reports) avec filtres par statut et type
- [ ] Fiche report : détail + lien vers la cible (user/service/message)
- [ ] Actions sur report : résoudre, rejeter, avec notes
- [ ] Cloud Function `resolveReport(reportId, action, notes?)`
- [ ] Cloud Function `suspendProvider(uid, reason?)`
- [ ] Cloud Function `removeService(serviceId)` (unpublish)
- [ ] Cloud Function `deleteMessage(chatId, messageId)`
- [ ] Lecture des messages d'un chat signalé
- [ ] Audit log : collection `admin_logs` + écriture automatique à chaque action

---

## Phase 3 — Gestion des entités (priorité moyenne)

Visibilité complète sur les données de la plateforme.

- [ ] Liste users paginée + recherche
- [ ] Fiche user (profil, bookings, reviews, reports)
- [ ] Liste providers paginée + filtre (actifs/suspendus)
- [ ] Fiche provider (bio, services, bookings, reviews)
- [ ] Actions provider : suspendre, dé-suspendre
- [ ] Cloud Function `unsuspendProvider(uid)`
- [ ] Liste services paginée + filtre par catégorie et statut
- [ ] Fiche service (détails, photos, zones, bookings liés)
- [ ] Action service : masquer / republier

---

## Phase 4 — Bookings & configuration (priorité moyenne)

- [ ] Liste bookings paginée + filtres (statut, date, provider, client)
- [ ] Fiche booking : timeline, chat, reviews
- [ ] CRUD catégories de services (`service_types/`)
- [ ] Gestion des rôles : promouvoir/révoquer admin et moderator
- [ ] Firestore rules : ajouter claim `moderator` aux règles existantes

---

## Phase 5 — Hardening (avant mise en prod)

- [ ] Tests unitaires sur les Cloud Functions admin
- [ ] Firestore rules tests pour les accès admin/moderator
- [ ] Audit de sécurité : vérifier qu'aucune action n'est possible sans claim
- [ ] Gestion d'erreurs et feedback utilisateur sur toutes les actions
- [ ] Responsive basique (tablette)
- [ ] Documentation déploiement (Firebase Hosting)

---

## Hors scope admin MVP

- Analytics avancées (graphiques, tendances)
- Export CSV
- Système de tickets support
- Gestion paiements
- Bulk actions
- Multi-langue
