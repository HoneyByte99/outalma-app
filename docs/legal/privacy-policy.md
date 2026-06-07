# Politique de confidentialité d'Outalma Service

_Dernière mise à jour : 16 mai 2026_

La présente politique décrit comment **KAYZEN TECHNOLOGY** (« nous », « notre »), éditeur de l'application Outalma Service, collecte, utilise et protège vos données personnelles lorsque vous utilisez notre application mobile et notre site web (ensemble, « l'Application »). Outalma Service est une place de marché de services pour des utilisateurs basés en France et au Sénégal. Un même compte peut agir comme **client** (réservation de services) et comme **prestataire** (offre de services).

Nous nous engageons à respecter le Règlement Général sur la Protection des Données (UE 2016/679, « RGPD »), la loi française « Informatique et Libertés », ainsi que la **loi sénégalaise n° 2008-12 du 25 janvier 2008** sur la protection des données à caractère personnel.

---

## 1. Identité du responsable de traitement

Le responsable de traitement est :

- **Raison sociale** : KAYZEN TECHNOLOGY
- **Forme juridique / immatriculation** : [à compléter avant publication]
- **Adresse du siège social** : [à compléter avant publication]
- **Email de contact** : contact@outalma.com
- **Délégué à la protection des données (DPO)** : non désigné à ce jour

---

## 2. Données que nous collectons

Nous limitons la collecte aux données nécessaires au fonctionnement du service.

### 2.1 Données d'identité
- Prénom, nom, pseudo affiché
- Photo de profil (facultative)
- Date de naissance (vérification d'âge minimum)

### 2.2 Données de contact
- Adresse email
- Numéro de téléphone (format international E.164)

> Votre numéro de téléphone n'est **jamais affiché publiquement**. Il n'est rendu visible qu'entre un client et un prestataire **après l'acceptation d'une réservation**, afin de faciliter la coordination du service (modèle inspiré de BlaBlaCar).

### 2.3 Contenu utilisateur
- Fiches de services publiées (titre, description, tarifs, photos)
- Messages échangés dans le chat (texte, images, messages vocaux) entre participants d'une réservation
- Avis et notes laissés après une prestation

### 2.4 Données de localisation
- Adresse ou zone d'intervention déclarée
- Position approximative pour la recherche de prestataires à proximité (via Google Maps / Places). La géolocalisation précise n'est utilisée qu'avec votre consentement explicite via les permissions du système d'exploitation.

### 2.5 Données techniques
- Identifiant utilisateur Firebase
- Modèle d'appareil, version du système d'exploitation, version de l'Application
- Jetons de notification push (Firebase Cloud Messaging)
- Journaux de plantage anonymisés (Firebase Crashlytics)
- Adresse IP (transitoirement, lors des appels aux services backend)

---

## 3. Finalités du traitement

Vos données sont utilisées pour :

1. **Authentification** : créer et sécuriser votre compte via email (lien magique) ou téléphone (code OTP).
2. **Fourniture du service** : publier des offres, rechercher, réserver, échanger via le chat, gérer les avis.
3. **Communication** : vous envoyer les notifications liées à vos réservations, messages, ou modifications de votre compte.
4. **Sécurité** : détecter les fraudes, les abus, les comptes multiples ou les comportements interdits par nos CGU.
5. **Amélioration du service** : corriger les bugs (via Crashlytics) et améliorer l'ergonomie. Nous n'utilisons **aucun outil d'analyse comportementale tiers**.
6. **Conformité légale** : répondre à une obligation légale, réglementaire, ou à une réquisition judiciaire.

---

## 4. Bases légales (RGPD Article 6)

| Finalité | Base légale |
|---|---|
| Création de compte et exécution des réservations | Exécution d'un contrat (Art. 6.1.b) |
| Sécurité, prévention de la fraude | Intérêt légitime (Art. 6.1.f) |
| Notifications push | Consentement (Art. 6.1.a), révocable depuis les réglages |
| Géolocalisation précise | Consentement (Art. 6.1.a) |
| Crashlytics (diagnostic technique) | Intérêt légitime (Art. 6.1.f) |
| Conservation comptable et fiscale éventuelle | Obligation légale (Art. 6.1.c) |

Au Sénégal, ces traitements reposent sur les bases prévues aux articles 33 et suivants de la loi n° 2008-12 (consentement, exécution contractuelle, intérêt légitime, obligation légale).

---

## 5. Sous-traitants et destinataires

Nous ne **vendons jamais** vos données. Nous ne diffusons **aucune publicité** dans l'Application. Vos données ne sont partagées qu'avec les sous-traitants techniques strictement nécessaires :

| Sous-traitant | Rôle | Localisation des serveurs |
|---|---|---|
| **Google / Firebase** (Auth, Firestore, Cloud Functions, Storage, Cloud Messaging, Crashlytics) | Hébergement, authentification, base de données, stockage de fichiers, notifications, rapports de crash | Union européenne (région `europe-west`) avec opérations Google globales |
| **Twilio Verify** | Envoi des codes OTP par SMS | États-Unis, Irlande |
| **Google Maps Platform / Places API** | Cartographie, recherche d'adresses, calcul de distance | Opérations Google globales |

Les autres destinataires sont les **utilisateurs eux-mêmes** : les informations publiques d'un profil (prénom, photo, services proposés, avis) sont visibles par les autres utilisateurs. Le numéro de téléphone n'est partagé qu'entre les deux participants d'une réservation acceptée.

---

## 6. Durée de conservation

| Donnée | Durée |
|---|---|
| Compte actif | Tant que le compte existe |
| Compte inactif (aucune connexion) | 3 ans après la dernière activité, puis suppression ou anonymisation |
| Messages de chat | 2 ans après la fin de la réservation associée |
| Historique des réservations | 5 ans (justification en cas de litige) |
| Rapports de crash (Crashlytics) | 90 jours |
| Données de facturation (le cas échéant) | 10 ans (obligation comptable) |

Vous pouvez à tout moment demander la suppression de votre compte depuis l'Application. Les données seront effacées sauf obligation légale de conservation.

---

## 7. Vos droits

Conformément au RGPD et à la loi sénégalaise n° 2008-12, vous disposez des droits suivants :

- **Accès** : obtenir une copie de vos données
- **Rectification** : corriger des données inexactes
- **Effacement** (« droit à l'oubli »)
- **Portabilité** : recevoir vos données dans un format structuré
- **Opposition** au traitement fondé sur l'intérêt légitime
- **Limitation** du traitement
- **Retrait du consentement** à tout moment (sans effet rétroactif)
- **Définir des directives** sur le sort de vos données après votre décès

Pour exercer ces droits, écrivez-nous à : **contact@outalma.com**. Une réponse vous sera apportée dans un délai d'**un mois**. Une preuve d'identité peut être demandée en cas de doute raisonnable.

---

## 8. Transferts hors Union européenne

Certains sous-traitants (Google, Twilio) sont susceptibles de traiter vos données en dehors de l'Union européenne, notamment aux États-Unis. Ces transferts sont encadrés par :

- l'adhésion au **EU-US Data Privacy Framework (DPF)** lorsque l'entreprise y est certifiée,
- les **Clauses Contractuelles Types** adoptées par la Commission européenne (décision 2021/914),
- des mesures de sécurité techniques complémentaires (chiffrement en transit et au repos).

Pour les utilisateurs sénégalais, les transferts internationaux respectent les articles 49 et suivants de la loi n° 2008-12 et requièrent un niveau de protection adéquat.

---

## 9. Sécurité des données

Nous mettons en œuvre des mesures techniques et organisationnelles raisonnables :

- Chiffrement TLS pour toutes les communications client / serveur
- Chiffrement au repos des données stockées chez Firebase
- Authentification forte (lien magique ou code OTP, sans mot de passe à mémoriser)
- Règles de sécurité Firestore et Storage limitant l'accès aux seules personnes autorisées
- Journaux d'accès et alertes en cas d'activité suspecte
- Accès restreint aux données aux seuls membres de l'équipe qui en ont besoin

Aucun système n'étant infaillible, nous nous engageons à vous notifier toute violation de données susceptible d'engendrer un risque élevé pour vos droits, dans les **72 heures** après en avoir pris connaissance, conformément à l'article 33 du RGPD.

---

## 10. Cookies et traceurs (site web)

La version web d'Outalma utilise uniquement :

- des **cookies strictement nécessaires** au fonctionnement (session, authentification, préférences linguistiques),
- les cookies techniques posés par Firebase Hosting et Firebase Auth.

Nous n'utilisons **aucun cookie publicitaire, aucun pixel de suivi, aucun traceur analytique tiers** au-delà de Firebase Crashlytics (qui ne pose pas de cookie côté navigateur).

Aucun bandeau de consentement n'est donc requis pour les cookies non-essentiels, puisque nous n'en posons pas. Vous pouvez à tout moment supprimer les cookies depuis les réglages de votre navigateur.

---

## 11. Données des mineurs

L'Application est réservée aux personnes âgées d'au moins **16 ans**. Nous ne collectons pas sciemment de données concernant des mineurs de moins de 16 ans. Si vous pensez qu'un mineur de moins de 16 ans nous a transmis des données, contactez-nous : nous procéderons à la suppression du compte concerné.

---

## 12. Modification de la politique

Cette politique peut être amenée à évoluer (nouvelles fonctionnalités, changement de sous-traitant, évolution légale). Toute modification substantielle vous sera notifiée dans l'Application et/ou par email, au moins **15 jours avant** son entrée en vigueur, afin de vous permettre d'exercer vos droits.

La date en haut de ce document indique toujours la version en vigueur.

---

## 13. Contact et réclamation

Pour toute question relative à vos données personnelles :

- **Email** : contact@outalma.com
- **Adresse postale** : KAYZEN TECHNOLOGY [adresse à compléter avant publication]

Si vous estimez que vos droits ne sont pas respectés, vous pouvez introduire une réclamation auprès de :

- **France** : Commission Nationale de l'Informatique et des Libertés (CNIL), 3 place de Fontenoy, TSA 80715, 75334 Paris Cedex 07. Site : [www.cnil.fr](https://www.cnil.fr)
- **Sénégal** : Commission des Données Personnelles (CDP), Immeuble Y2K, 1er étage, Rond-Point OMVS, Dakar. Site : [www.cdp.sn](https://www.cdp.sn)

---

## 14. Date d'effet

Cette politique est en vigueur depuis le **16 mai 2026**.
