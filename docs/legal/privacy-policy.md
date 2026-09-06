# Politique de confidentialité d'Outalma Service

Dernière mise à jour : 6 septembre 2026

La présente politique décrit comment **KAYZEN TECHNOLOGY** (« nous », « notre »), éditeur de l'application Outalma Service, collecte, utilise et protège vos données personnelles lorsque vous utilisez notre application mobile et notre site web (ensemble, « l'Application »). Outalma Service est une place de marché de services destinée aux utilisateurs basés au Sénégal. Un même compte peut agir comme **client** (réservation de services) et comme **prestataire** (offre de services).

Nous nous engageons à respecter la **loi sénégalaise n° 2008-12 du 25 janvier 2008** sur la protection des données à caractère personnel.


## 1. Identité du responsable de traitement

Le responsable de traitement est :

- **Raison sociale** : KAYZEN TECHNOLOGY
- **Forme juridique / immatriculation** : [à compléter avant publication]
- **Adresse du siège social** : [à compléter avant publication]
- **Email de contact** : contact@outalma.com
- **Délégué à la protection des données (DPO)** : non désigné à ce jour


## 2. Données que nous collectons

Nous limitons la collecte aux données nécessaires au fonctionnement du service.

### 2.1 Données d'identité
- Prénom, nom, pseudo affiché
- Photo de profil (facultative)
- Date de naissance (vérification d'âge minimum)

### 2.2 Données de contact
- Adresse email
- Numéro de téléphone (format international E.164)

Votre numéro de téléphone n'est **jamais affiché publiquement**. Il n'est rendu visible qu'entre un client et un prestataire **après l'acceptation d'une réservation**, afin de faciliter la coordination du service (modèle inspiré de BlaBlaCar).

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


## 3. Finalités du traitement

Vos données sont utilisées pour :

1. **Authentification** : créer et sécuriser votre compte via email (lien magique) ou téléphone (code OTP).
2. **Fourniture du service** : publier des offres, rechercher, réserver, échanger via le chat, gérer les avis.
3. **Communication** : vous envoyer les notifications liées à vos réservations, messages, ou modifications de votre compte.
4. **Sécurité** : détecter les fraudes, les abus, les comptes multiples ou les comportements interdits par nos CGU.
5. **Amélioration du service** : corriger les bugs (via Crashlytics) et améliorer l'ergonomie. Nous n'utilisons **aucun outil d'analyse comportementale tiers**.
6. **Conformité légale** : répondre à une obligation légale, réglementaire, ou à une réquisition judiciaire.


## 4. Fondements du traitement (loi n° 2008-12)

La loi sénégalaise n° 2008-12 pose comme principe que le traitement de vos données est légitime lorsque vous y avez consenti. Son article 33 admet qu'il soit dérogé à cette exigence de consentement lorsque le traitement est nécessaire au respect d'une obligation légale, à l'exécution d'une mission d'intérêt public, à l'exécution d'un contrat auquel vous êtes partie, ou à la sauvegarde de vos intérêts ou de vos droits et libertés fondamentaux.

| Finalité | Fondement |
|---|---|
| Création de compte et exécution des réservations | Exécution du contrat auquel vous êtes partie (art. 33-3) |
| Notifications push | Consentement, révocable à tout moment depuis les réglages |
| Géolocalisation précise | Consentement, recueilli via les permissions du système d'exploitation |
| Sécurité, prévention de la fraude | Nécessaire au bon fonctionnement du service et à la protection des utilisateurs contre les usages abusifs de la plateforme |
| Crashlytics (diagnostic technique) | Nécessaire au bon fonctionnement du service |
| Conservation comptable et fiscale éventuelle | Obligation légale (art. 33-1) |


## 5. Sous-traitants et destinataires

Nous ne **vendons jamais** vos données. Nous ne diffusons **aucune publicité** dans l'Application. Vos données ne sont partagées qu'avec les sous-traitants techniques strictement nécessaires :

| Sous-traitant | Rôle | Localisation des serveurs |
|---|---|---|
| **Google / Firebase** (Auth, Firestore, Cloud Functions, Storage, Cloud Messaging, Crashlytics) | Hébergement, authentification, base de données, stockage de fichiers, notifications, rapports de crash | Union européenne (région `europe-west`) avec opérations Google globales |
| **Twilio Verify** | Envoi des codes OTP par SMS | États-Unis, Irlande |
| **Google Maps Platform / Places API** | Cartographie, recherche d'adresses, calcul de distance | Opérations Google globales |

Les autres destinataires sont les **utilisateurs eux-mêmes** : les informations publiques d'un profil (prénom, photo, services proposés, avis) sont visibles par les autres utilisateurs. Le numéro de téléphone n'est partagé qu'entre les deux participants d'une réservation acceptée.


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


## 7. Vos droits

Conformément à la loi sénégalaise n° 2008-12, vous disposez des droits suivants :

- **Information** : être informé, avant ou lors de la collecte, de l'identité du responsable du traitement, des finalités, des destinataires et de la durée de conservation de vos données (art. 58 à 61)
- **Accès** : obtenir la confirmation qu'un traitement vous concernant existe, et une copie de vos données (art. 62 à 65)
- **Opposition** : vous opposer, pour des motifs légitimes, à un traitement vous concernant, notamment à la communication de vos données à des tiers à des fins de prospection ; ce droit ne s'applique pas lorsque le traitement répond à une obligation légale (art. 68)
- **Rectification et suppression** : demander que soient rectifiées, complétées, mises à jour, verrouillées ou supprimées les données inexactes, incomplètes, périmées, ou dont la collecte, l'utilisation, la communication ou la conservation est interdite (art. 69)

Pour exercer ces droits, écrivez-nous à : **contact@outalma.com**. L'article 69 de la loi n° 2008-12 impose un délai de réponse d'**un (1) mois** pour les demandes de rectification ; nous appliquons ce même délai à l'ensemble de ces demandes. Une preuve d'identité peut être demandée en cas de doute raisonnable.


## 8. Transferts de données hors du Sénégal

Certains sous-traitants (Google, Twilio) sont susceptibles de traiter vos données hors du Sénégal, notamment dans l'Union européenne et aux États-Unis (voir la Section 5).

Conformément à la loi n° 2008-12, un tel transfert n'est possible que si l'État de destination assure un niveau de protection suffisant de la vie privée et des droits fondamentaux des personnes concernées (art. 49). À défaut, le transfert reste possible s'il est ponctuel, non massif, et que la personne concernée y a expressément consenti, ou dans l'un des cas prévus à l'article 50, ou encore sur autorisation de la Commission des Données Personnelles lorsque le responsable du traitement offre des garanties suffisantes (art. 51).

Nous appliquons des mesures de sécurité techniques complémentaires (chiffrement en transit et au repos) à l'ensemble de ces transferts.

**[à vérifier avant publication]** : la démarche préalable auprès de la Commission des Données Personnelles prévue à l'article 49 pour ces transferts (information préalable, ou selon le cas demande d'autorisation au titre de l'article 51) n'a pas été confirmée comme accomplie à ce jour.


## 9. Sécurité des données

Nous mettons en œuvre des mesures techniques et organisationnelles raisonnables :

- Chiffrement TLS pour toutes les communications client / serveur
- Chiffrement au repos des données stockées chez Firebase
- Authentification forte (lien magique ou code OTP, sans mot de passe à mémoriser)
- Règles de sécurité Firestore et Storage limitant l'accès aux seules personnes autorisées
- Journaux d'accès et alertes en cas d'activité suspecte
- Accès restreint aux données aux seuls membres de l'équipe qui en ont besoin

Comme aucun système n'est infaillible, nous prenons l'engagement contractuel (la loi n° 2008-12 ne fixe pas de délai chiffré en la matière) de vous notifier toute violation de données susceptible d'engendrer un risque élevé pour vos droits, dans les **72 heures** après en avoir pris connaissance.


## 10. Cookies et traceurs (site web)

La version web d'Outalma utilise uniquement :

- des **cookies strictement nécessaires** au fonctionnement (session, authentification, préférences linguistiques),
- les cookies techniques posés par Firebase Hosting et Firebase Auth.

Nous n'utilisons **aucun cookie publicitaire, aucun pixel de suivi, aucun traceur analytique tiers** au-delà de Firebase Crashlytics (qui ne pose pas de cookie côté navigateur).

Aucun bandeau de consentement n'est donc requis pour les cookies non-essentiels, puisque nous n'en posons pas. Vous pouvez à tout moment supprimer les cookies depuis les réglages de votre navigateur.


## 11. Données des mineurs

L'Application est réservée aux personnes âgées d'au moins **16 ans**. Nous ne collectons pas sciemment de données concernant des mineurs de moins de 16 ans. Si vous pensez qu'un mineur de moins de 16 ans nous a transmis des données, contactez-nous : nous procéderons à la suppression du compte concerné.


## 12. Modification de la politique

Cette politique peut être amenée à évoluer (nouvelles fonctionnalités, changement de sous-traitant, évolution légale). Toute modification substantielle vous sera notifiée dans l'Application et/ou par email, au moins **15 jours avant** son entrée en vigueur, afin de vous permettre d'exercer vos droits.

La date en haut de ce document indique toujours la version en vigueur.


## 13. Contact et réclamation

Pour toute question relative à vos données personnelles :

- **Email** : contact@outalma.com
- **Adresse postale** : KAYZEN TECHNOLOGY [adresse à compléter avant publication]

Si vous estimez que vos droits ne sont pas respectés, vous pouvez introduire une réclamation auprès de la **Commission des Données Personnelles (CDP)** : Complexe SICAP, Point E, 1er étage, Immeuble A, Avenue Cheikh Anta Diop x Canal IV, Dakar, Sénégal. Site : [www.cdp.sn](https://www.cdp.sn)


## 14. Date d'effet

Cette politique est en vigueur depuis le **6 septembre 2026**.


## 15. Langue faisant foi

Cette politique est rédigée en français et en anglais. En cas de divergence ou d'incohérence entre les deux versions, la **version française prévaut** ; la version anglaise est fournie à titre d'information.
