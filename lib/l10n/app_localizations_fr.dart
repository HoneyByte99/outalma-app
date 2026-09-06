// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navHome => 'Accueil';

  @override
  String get navBookings => 'Réservations';

  @override
  String get navChats => 'Chats';

  @override
  String get navProfile => 'Profil';

  @override
  String get navDashboard => 'Accueil';

  @override
  String get navMissions => 'Missions';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get tooltipNotifications => 'Notifications';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeSystem => 'Système';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get confirm => 'Confirmer';

  @override
  String get retry => 'Réessayer';

  @override
  String get back => 'Retour';

  @override
  String get errorGeneral => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get errorLoading => 'Erreur de chargement';

  @override
  String get errorNetwork => 'Erreur de connexion';

  @override
  String get signInWelcome => 'Bon retour !';

  @override
  String get signInSubtitle => 'Connectez-vous pour accéder à vos services.';

  @override
  String get signInEmailHint => 'Adresse email';

  @override
  String get signInPasswordHint => 'Mot de passe';

  @override
  String get signInForgotPassword => 'Mot de passe oublié ?';

  @override
  String get signInForgotEnterEmail =>
      'Saisissez votre email pour réinitialiser.';

  @override
  String get signInForgotEmailSent => 'Email de réinitialisation envoyé.';

  @override
  String get signInForgotEmailError =>
      'Impossible d\'envoyer l\'email. Vérifiez l\'adresse.';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get signInNoAccount => 'Pas de compte ? ';

  @override
  String get signInRegister => 'S\'inscrire';

  @override
  String get signInErrorEmptyFields => 'Veuillez remplir tous les champs.';

  @override
  String get authErrorInvalidCredential => 'Email ou mot de passe incorrect.';

  @override
  String get authErrorAccountDisabled => 'Ce compte est désactivé.';

  @override
  String get authErrorTooManyRequests =>
      'Trop de tentatives. Réessayez plus tard.';

  @override
  String get authErrorSignInFailed =>
      'Connexion échouée. Vérifiez vos informations.';

  @override
  String get signUpTitle => 'Créez votre compte';

  @override
  String get signUpSubtitle =>
      'Rejoignez Outalma et accédez à des services à domicile.';

  @override
  String get signUpNameHint => 'Votre nom complet';

  @override
  String get signUpPasswordHint => 'Mot de passe (min. 6 caractères)';

  @override
  String get signUpPasswordConfirmHint => 'Confirmer le mot de passe';

  @override
  String get signUpShowPassword => 'Afficher le mot de passe';

  @override
  String get signUpHidePassword => 'Masquer le mot de passe';

  @override
  String get signUpErrorPasswordMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get emailVerifyBanner => 'Vérifiez votre adresse email.';

  @override
  String get emailVerifyResend => 'Renvoyer';

  @override
  String get emailVerifySent => 'Email de vérification envoyé.';

  @override
  String get emailVerifyError => 'Envoi impossible. Réessayez plus tard.';

  @override
  String get signUpButton => 'Créer un compte';

  @override
  String get signUpHaveAccount => 'Déjà un compte ? ';

  @override
  String get signUpSignIn => 'Se connecter';

  @override
  String get signUpErrorEmptyFields =>
      'Veuillez remplir tous les champs obligatoires.';

  @override
  String get signUpErrorPasswordTooShort =>
      'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String get signUpGenderLabel => 'Vous êtes';

  @override
  String get signUpGenderRequired =>
      'Veuillez indiquer si vous êtes un homme ou une femme.';

  @override
  String get genderMale => 'Homme';

  @override
  String get genderFemale => 'Femme';

  @override
  String get authErrorEmailAlreadyInUse => 'Cet email est déjà utilisé.';

  @override
  String get authErrorInvalidEmail => 'Adresse email invalide.';

  @override
  String get authErrorWeakPassword =>
      'Mot de passe trop faible (min. 6 caractères).';

  @override
  String get authErrorSignUpFailed =>
      'Inscription échouée. Vérifiez vos informations.';

  @override
  String get authErrorPhoneTaken => 'Ce numéro de téléphone est déjà utilisé.';

  @override
  String get authErrorInvalidOtp => 'Code invalide ou expiré.';

  @override
  String get authErrorOtpSend => 'Impossible d\'envoyer le code. Réessayez.';

  @override
  String get phoneOtpSendCode => 'Recevoir le code';

  @override
  String get phoneOtpVerify => 'Vérifier';

  @override
  String get phoneOtpHint => 'Code à 6 chiffres';

  @override
  String get phoneOtpResend => 'Renvoyer le code';

  @override
  String get phoneOtpEditNumber => 'Modifier le numéro';

  @override
  String phoneOtpSentTo(String phone) {
    return 'Code envoyé au $phone';
  }

  @override
  String get phoneOtpNoAccount =>
      'Aucun compte trouvé pour ce numéro. Inscrivez-vous d\'abord.';

  @override
  String get signUpVerificationNotice =>
      'À la création du compte, un email de vérification sera envoyé. Cliquez sur le lien dans votre boîte mail pour confirmer votre adresse.';

  @override
  String get signUpVerificationResent => 'Email de vérification renvoyé.';

  @override
  String homeGreeting(String name) {
    return 'Bonjour $name';
  }

  @override
  String get homeGreetingNoName => 'Bonjour';

  @override
  String get homeSearchPrompt => 'Que recherchez-vous ?';

  @override
  String get homeSearchHint => 'Rechercher un service…';

  @override
  String homeSearchEmpty(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get categoryAll => 'Tout';

  @override
  String get categoryMenage => 'Ménage';

  @override
  String get categoryPlomberie => 'Plomberie';

  @override
  String get categoryJardinage => 'Jardinage';

  @override
  String get categoryElectricite => 'Électricité';

  @override
  String get categoryPeinture => 'Peinture';

  @override
  String get categoryBricolage => 'Bricolage';

  @override
  String get categoryGardeEnfants => 'Garde d\'enfants';

  @override
  String get categoryCuisine => 'Cuisine';

  @override
  String get categoryRepassage => 'Repassage';

  @override
  String get servicesEmpty => 'Aucun service disponible\npour le moment';

  @override
  String homeCategoryEmpty(String category) {
    return 'Aucune fiche « $category »\npour le moment';
  }

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get modeClient => 'Client';

  @override
  String get modeProvider => 'Prestataire';

  @override
  String get modeClientActivated => 'Mode client activé';

  @override
  String get modeProviderActivated => 'Mode prestataire activé';

  @override
  String get modeBadgeTapToSwitch => 'Toucher pour changer de mode';

  @override
  String get verifiedBadgeLabel => 'Profil vérifié';

  @override
  String get serviceZonesLabel => 'Zones d\'intervention';

  @override
  String get serviceViewOnMap => 'Voir sur le plan';

  @override
  String get reportDetailsLabel => 'Détails (facultatif)';

  @override
  String get reportDetailsHint =>
      'Ajoutez des informations qui aideront notre équipe de modération…';

  @override
  String get dashboardStatsUpcomingWeek => 'À venir cette semaine';

  @override
  String get dashboardStatsThisMonth => 'Réservations ce mois';

  @override
  String get dashboardStatsAcceptanceRate => 'Taux d\'acceptation';

  @override
  String get locationTitle => 'Localisation';

  @override
  String get locationAllAreas => 'Tout le Sénégal';

  @override
  String get locationValidate => 'Valider';

  @override
  String get locationUseMyPosition => 'Utiliser ma position';

  @override
  String get locationPermissionDenied => 'Accès à la localisation refusé';

  @override
  String get locationServiceDisabled =>
      'Activez la localisation dans les paramètres';

  @override
  String get locationGeoError => 'Impossible d\'obtenir votre position';

  @override
  String get locationSearchHint => 'Ville ou adresse';

  @override
  String get locationSaveTooltip => 'Enregistrer cette adresse';

  @override
  String get locationRadius => 'Rayon';

  @override
  String get locationAddressName => 'Nom de l\'adresse';

  @override
  String get locationAddressHint => 'Ex: Maison, Bureau…';

  @override
  String get locationMyAddresses => 'Mes adresses';

  @override
  String locationSaved(String name) {
    return '\"$name\" enregistré';
  }

  @override
  String get profileTitle => 'Profil & Paramètres';

  @override
  String get profileMyReviews => 'Mes avis';

  @override
  String get profileActiveMode => 'Mode actif';

  @override
  String get profileInformation => 'Informations';

  @override
  String get profileAppearance => 'Apparence';

  @override
  String get profileAccount => 'Compte';

  @override
  String get profileErrorUpload =>
      'Impossible d\'importer la photo. Réessayez.';

  @override
  String get profileSaved => 'Profil mis à jour.';

  @override
  String get profileSaveError => 'Impossible de sauvegarder. Réessayez.';

  @override
  String get profileLanguage => 'Langue';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldFullName => 'Nom complet';

  @override
  String get fieldPhone => 'Numéro de téléphone';

  @override
  String get fieldRequired => 'Champ requis';

  @override
  String get fieldCountry => 'Pays';

  @override
  String get modeClientSubtitle => 'Réserver des services';

  @override
  String get modeProviderSubtitle => 'Gérer mes missions';

  @override
  String get modeSwitchError => 'Impossible de changer de mode. Réessayez.';

  @override
  String get signOutTitle => 'Se déconnecter ?';

  @override
  String get signOutContent =>
      'Vous devrez saisir vos identifiants pour vous reconnecter.';

  @override
  String get signOutButton => 'Déconnexion';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get reviewsEmpty => 'Aucun avis reçu pour le moment';

  @override
  String get reviewsTitle => 'Avis';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avis',
      one: '1 avis',
      zero: 'Aucun avis',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String get dashboardMyServices => 'Mes services';

  @override
  String get dashboardAdd => 'Ajouter';

  @override
  String get dashboardActivateTitle => 'Activez votre profil';

  @override
  String get dashboardActivateBody =>
      'Quelques infos pour commencer à recevoir des demandes.';

  @override
  String get dashboardActivateButton => 'Commencer';

  @override
  String get dashboardCompleteProfileTitle => 'Complétez votre profil';

  @override
  String get dashboardCompleteProfileBody =>
      'Ajoutez votre bio et votre zone d\'intervention pour rassurer les clients.';

  @override
  String get hubFallbackName => 'Mon profil';

  @override
  String get hubEditProfile => 'Modifier le profil';

  @override
  String get hubAvailable => 'Disponible';

  @override
  String get hubPaused => 'En pause';

  @override
  String get hubAvailableSub => 'Les clients peuvent vous réserver';

  @override
  String get hubPausedSub => 'Vos annonces sont masquées';

  @override
  String get hubNoServicesHint => 'Publiez une annonce pour devenir disponible';

  @override
  String get hubSemanticsOn => 'Disponible. Appuyez pour mettre en pause.';

  @override
  String get hubSemanticsOff => 'En pause. Appuyez pour redevenir disponible.';

  @override
  String get hubResumed => 'Vous êtes de nouveau disponible';

  @override
  String get hubToggleError =>
      'Impossible de mettre à jour votre disponibilité. Réessayez.';

  @override
  String get hubPauseTitle => 'Mettre en pause ?';

  @override
  String hubPauseBody(int count) {
    return 'Vos $count annonces seront masquées aux clients. Réactivez quand vous voulez.';
  }

  @override
  String get hubPauseBodyNoCount =>
      'Vos annonces seront masquées aux clients. Réactivez quand vous voulez.';

  @override
  String get hubPauseCta => 'Mettre en pause';

  @override
  String get serviceMaskedPaused => 'En pause';

  @override
  String get dashboardServicesError => 'Impossible de charger vos services.';

  @override
  String get serviceEmptyTitle => 'Aucun service publié';

  @override
  String get serviceEmptyBody =>
      'Créez votre premier service pour commencer\nà recevoir des demandes.';

  @override
  String get serviceCreate => 'Créer un service';

  @override
  String get published => 'Publié';

  @override
  String get notPublished => 'Non publié';

  @override
  String get serviceStatusPending => 'En attente de validation';

  @override
  String get serviceStatusRejected => 'Refusé';

  @override
  String get serviceActive => 'En ligne';

  @override
  String get serviceInactive => 'Hors ligne';

  @override
  String serviceToggleActivate(String title) {
    return 'Mettre $title en ligne';
  }

  @override
  String serviceToggleDeactivate(String title) {
    return 'Mettre $title hors ligne';
  }

  @override
  String get serviceDelete => 'Supprimer';

  @override
  String get serviceDeleteTitle => 'Supprimer ce service ?';

  @override
  String get serviceDeleteBody =>
      'Cette annonce sera définitivement supprimée.';

  @override
  String get serviceDeleted => 'Service supprimé';

  @override
  String get ratingNew => 'Nouveau';

  @override
  String ratingFromClients(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '· $count avis de clients',
      one: '· 1 avis de client',
    );
    return '$_temp0';
  }

  @override
  String ratingFloorHintClients(int count) {
    return '· moins de $count avis de clients';
  }

  @override
  String ratingFloorHint(int count) {
    return '· moins de $count avis';
  }

  @override
  String get reviewsAllReceived => 'Tous les avis reçus';

  @override
  String get tooltipProviderProfile => 'Mon profil prestataire';

  @override
  String get bookingsTitle => 'Mes réservations';

  @override
  String get tabActive => 'En cours';

  @override
  String get tabDone => 'Terminées';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusAccepted => 'Acceptée';

  @override
  String get statusInProgress => 'En cours';

  @override
  String get statusDone => 'Terminée';

  @override
  String get statusRejected => 'Refusée';

  @override
  String get statusCancelled => 'Annulée';

  @override
  String get bookingsActiveEmpty => 'Aucune réservation en cours';

  @override
  String get bookingsDoneEmpty => 'Aucune réservation terminée';

  @override
  String get bookingNoDateToday => 'Aucune réservation ce jour';

  @override
  String get bookingNoUpcoming => 'Aucune réservation à venir';

  @override
  String bookingRequestedAt(String date) {
    return 'Demande du $date';
  }

  @override
  String bookingScheduledAt(String datetime) {
    return 'Prévu : $datetime';
  }

  @override
  String get bookingDetailTitle => 'Détail de la réservation';

  @override
  String get bookingService => 'Service';

  @override
  String get bookingMessage => 'Message';

  @override
  String get bookingNoMessage => 'Aucun message';

  @override
  String get bookingSchedule => 'Créneau';

  @override
  String get bookingScheduleUnspecified => 'Non précisé';

  @override
  String get bookingAddress => 'Adresse';

  @override
  String get bookingAddressUnspecified => 'Non précisée';

  @override
  String bookingDistanceEstimate(String km) {
    return 'Distance estimée : ~$km km';
  }

  @override
  String serviceZoneWithDistance(String label, String km) {
    return '$label · $km km';
  }

  @override
  String serviceZoneWithMore(String label, int count) {
    return '$label +$count';
  }

  @override
  String serviceZoneDistancePart(String km) {
    return '· $km km';
  }

  @override
  String serviceZoneMorePart(int count) {
    return '+$count';
  }

  @override
  String get bookingOpenDirections => 'Itinéraire';

  @override
  String get bookingContact => 'Contact';

  @override
  String get bookingPhoneNotShared => 'Numéro non encore partagé';

  @override
  String get bookingCallAction => 'Appeler';

  @override
  String get bookingWhatsappAction => 'WhatsApp';

  @override
  String get bookingPhoneCopied => 'Numéro copié';

  @override
  String get bookingAddPhoneInProfile =>
      'Ajoutez votre numéro dans votre profil pour le partager.';

  @override
  String get bookingPhoneShared => 'Votre numéro est partagé';

  @override
  String bookingSharePhone(String phone) {
    return 'Partager mon numéro ($phone)';
  }

  @override
  String get bookingSharePhoneError => 'Impossible de partager le numéro.';

  @override
  String get bookingOpenChat => 'Accéder au chat';

  @override
  String get bookingReviewSent => 'Avis envoyé, merci !';

  @override
  String get bookingLeaveReview => 'Laisser un avis';

  @override
  String get bookingTimeline => 'Suivi';

  @override
  String get timelineRequestSent => 'Demande envoyée';

  @override
  String get timelineAccepted => 'Demande acceptée';

  @override
  String get timelineRejected => 'Demande refusée';

  @override
  String get timelineInProgress => 'Service en cours';

  @override
  String get timelineCancelled => 'Annulée';

  @override
  String get timelineDone => 'Terminé';

  @override
  String get timelinePendingResponse => 'En attente de réponse';

  @override
  String get timelineUpcoming => 'Service à venir';

  @override
  String get bookingNotFound => 'Réservation introuvable';

  @override
  String get bookingTitle => 'Réservation';

  @override
  String get bookingReport => 'Signaler';

  @override
  String get bookingViewProviderProfile => 'Voir le profil';

  @override
  String get bookingViewClientReviews => 'Voir les avis';

  @override
  String get providerProfileUnavailable => 'Profil indisponible';

  @override
  String get bookingAccept => 'Accepter';

  @override
  String get bookingReject => 'Refuser';

  @override
  String get bookingAccepted => 'Demande acceptée';

  @override
  String get bookingRejected => 'Demande refusée';

  @override
  String get bookingAcceptError => 'Erreur lors de l\'acceptation.';

  @override
  String get bookingRejectError => 'Erreur lors du refus.';

  @override
  String get bookingStartService => 'Démarrer le service';

  @override
  String get bookingServiceStarted => 'Service démarré';

  @override
  String get bookingStartError => 'Erreur lors du démarrage.';

  @override
  String get bookingCancelTitle => 'Annuler la demande ?';

  @override
  String get bookingCancelContent => 'Cette action est irréversible.';

  @override
  String get bookingCancelYes => 'Oui, annuler';

  @override
  String get bookingCancelNo => 'Non';

  @override
  String get bookingCancelButton => 'Annuler la demande';

  @override
  String get bookingCancelReasonHint => 'Motif (facultatif)';

  @override
  String get bookingCancelError => 'Impossible d\'annuler. Réessayez.';

  @override
  String get bookingCancelSuccess => 'Demande annulée.';

  @override
  String get bookingConfirmDoneTitle => 'Confirmer la fin ?';

  @override
  String get bookingConfirmDoneContent =>
      'En confirmant, le service sera marqué comme terminé. Vous pourrez ensuite laisser un avis.';

  @override
  String get bookingConfirmDoneButton => 'Confirmer la fin du service';

  @override
  String get bookingDoneSuccess => 'Service terminé !';

  @override
  String get bookingDoneError => 'Erreur lors de la confirmation.';

  @override
  String get bookingRequestTitle => 'Demander ce service';

  @override
  String get bookingStep1Title => 'Décrivez votre besoin';

  @override
  String get bookingStep1Subtitle =>
      'Donnez des détails pour aider le prestataire à comprendre votre demande.';

  @override
  String get bookingStep1Hint =>
      'Ex: J\'ai besoin d\'un nettoyage complet de mon appartement…';

  @override
  String bookingDefaultMessage(String serviceTitle) {
    return 'Bonjour, je suis intéressé(e) par votre service « $serviceTitle ». Pouvez-vous me contacter pour convenir d\'un rendez-vous ? Merci !';
  }

  @override
  String get bookingStep2Title => 'Date et heure souhaitées';

  @override
  String get bookingStep2Subtitle => 'Sélectionnez un créneau (optionnel).';

  @override
  String get bookingStep2PickDate => 'Choisir une date';

  @override
  String get bookingStep2PickTime => 'Choisir une heure';

  @override
  String get bookingPickSlot => 'Choisir un créneau disponible';

  @override
  String get bookingNoSlots =>
      'Aucun créneau libre ce jour-là. Essayez une autre date.';

  @override
  String get bookingProviderUnavailable =>
      'Ce prestataire est indisponible pour le moment.';

  @override
  String get bookingAddressNotInSenegal =>
      'La prestation doit se situer au Sénégal. Choisissez une adresse au Sénégal.';

  @override
  String bookingAddressOutsideZones(String zones) {
    return 'Ce prestataire n\'intervient pas à cette adresse. Zones couvertes : $zones.';
  }

  @override
  String get bookingSaveAddress => 'Enregistrer cette adresse';

  @override
  String get marketplaceDisclaimer =>
      'Outalma met uniquement en relation des clients et des prestataires indépendants. Tout accord et paiement se fait directement entre vous, hors de l\'application et sous votre responsabilité. Vérifiez toujours à qui vous avez affaire.';

  @override
  String get bookingStep3Title => 'Adresse d\'intervention';

  @override
  String get bookingStep3Subtitle =>
      'Où souhaitez-vous que le prestataire intervienne ?';

  @override
  String get bookingStep3Hint => 'Ex: Rue 10, Point E, Dakar';

  @override
  String get bookingAddressRequiredHint =>
      'L\'adresse est requise : le prestataire se déplace toujours pour intervenir.';

  @override
  String get bookingAddressNotResolved =>
      'Adresse introuvable. Choisissez une suggestion dans la liste ou utilisez votre position.';

  @override
  String get bookingBack => 'Retour';

  @override
  String get bookingContinue => 'Continuer';

  @override
  String get bookingSend => 'Envoyer la demande';

  @override
  String get bookingVoiceMessageLabel => 'Message vocal';

  @override
  String get chatPhotoMessageLabel => 'Photo';

  @override
  String get bookingRecordPrompt => 'Appuyez pour enregistrer';

  @override
  String get bookingDeleteRecording => 'Supprimer l\'enregistrement';

  @override
  String get bookingVoicePermissionDenied =>
      'Permission micro refusée. Vérifiez les réglages.';

  @override
  String get bookingVoiceUploadFailed =>
      'Échec de l\'envoi du message vocal. Réessayez.';

  @override
  String get bookingVoicePlayLabel => 'Lecture';

  @override
  String get bookingVoiceStopLabel => 'Stop';

  @override
  String get bookingSentSuccess => 'Demande envoyée avec succès ✓';

  @override
  String get bookingConflictBusy =>
      'Le prestataire a déjà un RDV prévu à cette heure.';

  @override
  String get bookingConflictUnavailableDay =>
      'Le prestataire est indisponible ce jour.';

  @override
  String get bookingConflictUnavailableSlot =>
      'Le prestataire est indisponible sur ce créneau.';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get chatEmpty => 'Aucun chat actif';

  @override
  String get chatEmptySubtitle =>
      'Les conversations démarrent après\nl\'acceptation d\'une réservation.';

  @override
  String get chatActiveEmpty => 'Aucune conversation en cours';

  @override
  String get chatDoneEmpty => 'Aucune conversation terminée';

  @override
  String get chatStartConversation => 'Démarrez la conversation';

  @override
  String get chatYou => 'Vous : ';

  @override
  String get chatLoadError => 'Impossible de charger les messages.';

  @override
  String get chatConversation => 'Conversation';

  @override
  String get chatTyping => 'Écrivez un message…';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatErrorSend => 'Impossible d\'envoyer.';

  @override
  String get chatTabActive => 'En cours';

  @override
  String get chatTabDone => 'Terminées';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsReadAll => 'Tout lire';

  @override
  String get notificationTargetGone => 'Ce contenu n\'existe plus.';

  @override
  String notificationsUnreadCount(int count) {
    return '$count non lues';
  }

  @override
  String get notificationsEmpty => 'Aucune notification';

  @override
  String get notificationsEmptySubtitle =>
      'Vous serez notifié ici lorsque\nquelque chose se passe.';

  @override
  String get notificationsError => 'Impossible de charger les notifications.';

  @override
  String get notificationTimeNow => 'A l\'instant';

  @override
  String notificationTimeMinutes(int count) {
    return 'Il y a $count min';
  }

  @override
  String notificationTimeHours(int count) {
    return 'Il y a $count h';
  }

  @override
  String get notificationTimeYesterday => 'Hier';

  @override
  String notificationTimeDays(int count) {
    return 'Il y a $count j';
  }

  @override
  String get inboxTitle => 'Missions';

  @override
  String get inboxCalendarTooltip => 'Mon calendrier';

  @override
  String get calendarFullDay => 'Journée entière';

  @override
  String get calendarLegendBooking => 'Rendez-vous';

  @override
  String get calendarLegendBlocked => 'Indisponibilité';

  @override
  String get calendarServiceFallback => 'Service';

  @override
  String get calendarDeleteSlotTitle => 'Supprimer ce blocage ?';

  @override
  String get calendarDeleteSlotBody => 'Ce créneau redeviendra réservable.';

  @override
  String get calendarDeleteSlotConfirm => 'Supprimer';

  @override
  String get inboxTabRequests => 'Demandes';

  @override
  String get inboxTabActive => 'En cours';

  @override
  String get inboxTabCompleted => 'Terminées';

  @override
  String get inboxEmptyRequests => 'Aucune demande en attente';

  @override
  String get inboxEmptyRequestsSubtitle =>
      'Les nouvelles demandes clients apparaîtront ici.';

  @override
  String get inboxEmptyActive => 'Aucune mission en cours';

  @override
  String get inboxEmptyActiveSubtitle =>
      'Les missions acceptées apparaîtront ici.';

  @override
  String get inboxEmptyCompleted => 'Aucune mission terminée';

  @override
  String get inboxEmptyCompletedSubtitle =>
      'Les missions terminées, refusées ou annulées apparaissent ici.';

  @override
  String get inboxLoadError => 'Impossible de charger les données.';

  @override
  String get inboxOpenChat => 'Ouvrir le chat';

  @override
  String get inboxMoreDetails => 'Plus de détails';

  @override
  String get reviewTitle => 'Laisser un avis';

  @override
  String get reviewEvaluateProvider => 'Évaluez le prestataire';

  @override
  String get reviewEvaluateClient => 'Évaluez le client';

  @override
  String get reviewHelp => 'Votre avis aide la communauté à faire confiance.';

  @override
  String get reviewRating => 'Note';

  @override
  String get reviewComment => 'Commentaire (optionnel)';

  @override
  String get reviewCommentHint => 'Partagez votre expérience…';

  @override
  String get reviewSubmit => 'Envoyer l\'avis';

  @override
  String get reviewError => 'Impossible d\'envoyer l\'avis.';

  @override
  String get reviewBookingNotFound => 'Réservation introuvable.';

  @override
  String get reviewOnlyAfterDone =>
      'Avis disponible uniquement après la fin du service.';

  @override
  String get reportTitle => 'Signaler';

  @override
  String get reportQuestion => 'Pourquoi signalez-vous ?';

  @override
  String get reportSubtitle =>
      'Votre signalement est anonyme et sera examiné par notre équipe.';

  @override
  String get reportSubmit => 'Envoyer le signalement';

  @override
  String get reportSuccess => 'Signalement envoyé. Merci.';

  @override
  String get reportError => 'Impossible d\'envoyer le signalement.';

  @override
  String get reportReason1 => 'Comportement inapproprié';

  @override
  String get reportReason2 => 'Faux profil ou arnaque';

  @override
  String get reportReason3 => 'Service non réalisé';

  @override
  String get reportReason4 => 'Contenu offensant';

  @override
  String get reportReason5 => 'Harcèlement';

  @override
  String get reportReason6 => 'Autre';

  @override
  String get serviceDescription => 'Description';

  @override
  String get serviceProviderLabel => 'Prestataire';

  @override
  String get serviceViewProfile => 'Voir le profil';

  @override
  String servicePhotoCounter(int current, int total) {
    return 'Photo $current sur $total';
  }

  @override
  String get serviceBook => 'Demander ce service';

  @override
  String get serviceEditListing => 'Modifier cette annonce';

  @override
  String get serviceNotFound => 'Service introuvable';

  @override
  String get seeMore => 'Voir plus';

  @override
  String get seeLess => 'Voir moins';

  @override
  String get onboardingTitle => 'Devenir prestataire';

  @override
  String get onboardingEditTitle => 'Modifier mon profil';

  @override
  String get onboardingHeadline => 'Proposez vos services';

  @override
  String get onboardingEditHeadline => 'Votre profil prestataire';

  @override
  String get onboardingBody =>
      'Créez votre profil prestataire en quelques secondes. Vous pourrez ensuite publier vos services et recevoir des demandes.';

  @override
  String get onboardingEditBody =>
      'Mettez à jour votre présentation et vos horaires de travail.';

  @override
  String get onboardingBio => 'Présentation (optionnel)';

  @override
  String get onboardingBioHint =>
      'Ex: Plombier avec 10 ans d\'expérience, disponible à Dakar…';

  @override
  String get onboardingActivate => 'Activer mon profil prestataire';

  @override
  String get onboardingSave => 'Enregistrer';

  @override
  String get onboardingHours => 'Horaires de travail';

  @override
  String get onboardingHoursHint =>
      'Les clients ne peuvent réserver qu\'à l\'intérieur de ce créneau.';

  @override
  String get onboardingHoursStart => 'De';

  @override
  String get onboardingHoursEnd => 'À';

  @override
  String get onboardingError => 'Impossible d\'activer le profil. Réessayez.';

  @override
  String get serviceFormCreateTitle => 'Nouveau service';

  @override
  String get serviceFormEditTitle => 'Modifier le service';

  @override
  String get serviceFormTitleLabel => 'Titre du service';

  @override
  String get serviceFormTitleHint => 'Ex: Nettoyage complet d\'appartement';

  @override
  String get serviceFormTitleRequired => 'Titre requis';

  @override
  String get serviceFormCategory => 'Catégorie';

  @override
  String get serviceFormDescription => 'Description (optionnel)';

  @override
  String get serviceFormDescriptionHint => 'Décrivez ce que vous proposez…';

  @override
  String get serviceFormPrice => 'Tarif';

  @override
  String get serviceFormPriceRequired => 'Requis';

  @override
  String get serviceFormPriceInvalid => 'Invalide';

  @override
  String get serviceFormZones => 'Zones d\'intervention *';

  @override
  String get serviceFormZonesRequired =>
      'Ajoutez au moins une zone d\'intervention.';

  @override
  String get serviceFormPublish => 'Publier ce service';

  @override
  String get serviceFormPublishSubtitle => 'Visible par les clients';

  @override
  String get serviceFormSave => 'Enregistrer';

  @override
  String get serviceFormCreate => 'Créer le service';

  @override
  String get serviceFormPhotoError =>
      'Impossible d\'importer la photo. Réessayez.';

  @override
  String get serviceFormPhotoAdd => 'Ajouter une photo (optionnel)';

  @override
  String serviceFormPhotoMax(int max) {
    return 'Vous pouvez ajouter jusqu\'à $max photos.';
  }

  @override
  String serviceFormPhotoCount(int count, int max) {
    return '$count photo(s) sur $max';
  }

  @override
  String get serviceFormSaveError => 'Impossible d\'enregistrer. Réessayez.';

  @override
  String get serviceFormPublishNeedsProfile =>
      'Complétez votre profil prestataire avant de publier. Vous pouvez l\'enregistrer en brouillon pour l\'instant.';

  @override
  String get zoneAddTitle => 'Ajouter une zone';

  @override
  String get zoneEditTitle => 'Modifier la zone';

  @override
  String get zoneAddressHint => 'Ville ou adresse';

  @override
  String get zoneSelectError => 'Sélectionnez une adresse dans les suggestions';

  @override
  String get zoneLocateError => 'Impossible de localiser cette adresse.';

  @override
  String get zoneConnectionError => 'Connexion requise pour ajouter une zone.';

  @override
  String get zoneRadius => 'Rayon d\'intervention';

  @override
  String get zoneNone => 'Aucune zone ajoutée';

  @override
  String get zoneAdd => 'Ajouter une zone';

  @override
  String get priceHourly => 'par heure';

  @override
  String get priceFixed => 'forfait';

  @override
  String get priceDaily => 'par jour';

  @override
  String get priceMonthly => 'par mois';

  @override
  String get priceUnitHourly => '/h';

  @override
  String get priceUnitDaily => '/jour';

  @override
  String get priceUnitMonthly => '/mois';

  @override
  String get serviceFormBillingMode => 'Mode de facturation';

  @override
  String get serviceFormExtraTasks => 'Tâches supplémentaires couvertes';

  @override
  String get serviceFormExtraTasksSubtitle =>
      'Jusqu\'à trois tâches en plus de la tâche principale';

  @override
  String get serviceFormExtraTasksMax =>
      'Trois tâches supplémentaires au maximum.';

  @override
  String serviceFormPriceRange(String min, String max) {
    return 'Fourchette autorisée : $min à $max F CFA';
  }

  @override
  String serviceFormPriceOutOfRange(String min, String max) {
    return 'Le tarif doit être compris entre $min et $max F CFA.';
  }

  @override
  String get serviceFormPriceMonthlyMin => 'Minimum mensuel';

  @override
  String get serviceFormPriceMonthlyMax => 'Maximum mensuel';

  @override
  String get serviceFormMonthlyMaxBelowMin =>
      'Le maximum doit être supérieur ou égal au minimum.';

  @override
  String get serviceFormPricingUnavailable =>
      'La grille tarifaire n\'est pas disponible. Réessayez.';

  @override
  String get photoAdd => 'Ajouter une photo (optionnel)';

  @override
  String zoneRadiusLabel(String radius) {
    return 'Rayon : $radius';
  }

  @override
  String get zoneValidate => 'Valider';

  @override
  String get zoneModify => 'Modifier';

  @override
  String get phoneAuthTitle => 'Numéro de téléphone';

  @override
  String get phoneAuthSubtitle =>
      'Entrez votre numéro pour recevoir un code de vérification par SMS.';

  @override
  String get phoneAuthButton => 'Envoyer le code';

  @override
  String get phoneAuthWithNumber => 'Continuer avec un numéro de téléphone';

  @override
  String get phoneAuthOrWith => 'ou';

  @override
  String get phoneAuthWebUnsupported =>
      'La connexion par téléphone n\'est disponible que sur l\'application mobile.';

  @override
  String get otpTitle => 'Code de vérification';

  @override
  String otpSubtitle(String phone) {
    return 'Un code a été envoyé au $phone';
  }

  @override
  String get otpHint => 'Code à 6 chiffres';

  @override
  String get otpVerify => 'Vérifier';

  @override
  String otpResendIn(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String get otpResend => 'Renvoyer le code';

  @override
  String get otpError => 'Code incorrect. Réessayez.';

  @override
  String get otpPhoneError =>
      'Impossible d\'envoyer le code. Vérifiez le numéro.';

  @override
  String get phoneNameTitle => 'Votre prénom et nom';

  @override
  String get phoneNameSubtitle =>
      'Ce nom sera visible par les autres utilisateurs.';

  @override
  String get phoneNameHint => 'Prénom et nom';

  @override
  String get phoneNameButton => 'Continuer';

  @override
  String get phoneNameError => 'Impossible de sauvegarder. Réessayez.';

  @override
  String get langSystem => 'Système (appareil)';

  @override
  String get langFrench => 'Français';

  @override
  String get langEnglish => 'Anglais';

  @override
  String get switchModeTitle => 'Choisir un mode';

  @override
  String get switchModeHeading => 'Votre mode actif';

  @override
  String get switchModeDescription =>
      'Passez du mode client au mode prestataire à tout moment.';

  @override
  String get switchModeThemeDescription =>
      'Choisissez le thème de l\'application.';

  @override
  String get themeSystemSubtitle => 'Suit les préférences de votre appareil';

  @override
  String get themeLightSubtitle => 'Toujours en mode clair';

  @override
  String get themeDarkSubtitle => 'Toujours en mode sombre';

  @override
  String get chatRecording => 'Enregistrement en cours…';

  @override
  String get chatSubtitle => 'Coordonnez les détails du service ici.';

  @override
  String get chatMicError => 'Impossible d\'activer le micro.';

  @override
  String get chatMicPermission =>
      'Autorisez l\'accès au micro pour envoyer un vocal.';

  @override
  String get notifDisabledBanner =>
      'Activez les notifications pour ne rien manquer.';

  @override
  String get notifEnableAction => 'Activer';

  @override
  String get micEnableAction => 'Réglages';

  @override
  String get bookingVoiceMessage => 'Message vocal';

  @override
  String get chatMissionEndedBanner =>
      'Mission terminée. Conversation en lecture seule.';

  @override
  String get chatVoiceError => 'Impossible d\'envoyer le vocal.';

  @override
  String get chatVoiceSending => 'Envoi du message vocal…';

  @override
  String get chatFileError => 'Impossible d\'envoyer le fichier.';

  @override
  String get chatAddCaption => 'Ajouter un message…';

  @override
  String get chatGallery => 'Galerie';

  @override
  String get reviewsLabel => 'Avis';

  @override
  String get servicesOffered => 'Services proposés';

  @override
  String get bookingAddressLabel => 'Adresse d\'intervention';

  @override
  String get introSlide1Title => 'Bienvenue sur Outalma';

  @override
  String get introSlide1Body =>
      'Trouvez les meilleurs prestataires de services près de chez vous, rapidement et en toute confiance.';

  @override
  String get introSlide2Title => 'Réservez en un instant';

  @override
  String get introSlide2Body =>
      'Sélectionnez un service, choisissez un créneau et confirmez en quelques tapotements.';

  @override
  String get introSlide3Title => 'Suivez en temps réel';

  @override
  String get introSlide3Body =>
      'Restez informé à chaque étape : confirmation, déplacement et fin de prestation.';

  @override
  String get introSlide4Title => 'Prêt à commencer';

  @override
  String get introSlide4Body =>
      'En continuant, vous acceptez nos conditions d\'utilisation et notre politique de confidentialité.';

  @override
  String get introTermsAccept => 'J\'accepte les conditions d\'utilisation';

  @override
  String get introNext => 'Suivant';

  @override
  String get introGetStarted => 'Commencer';

  @override
  String get introTermsRequired =>
      'Veuillez accepter les conditions pour continuer.';

  @override
  String get legalReadTerms => 'Lire les conditions d\'utilisation';

  @override
  String get legalReadPrivacy => 'Lire la politique de confidentialité';

  @override
  String get legalTermsTitle => 'Conditions d\'utilisation';

  @override
  String get legalPrivacyTitle => 'Politique de confidentialité';

  @override
  String get introSkip => 'Passer';

  @override
  String get authTabEmail => 'Mail';

  @override
  String get authTabPhone => 'Téléphone';

  @override
  String get locationMyPosition => 'Ma position';

  @override
  String get chatUnsupportedFormat => 'Format non supporté';

  @override
  String get chatHoldToRecord => 'Maintenez pour enregistrer';

  @override
  String get chatSlideToCancel => 'Glisser pour annuler';

  @override
  String get chatReleaseToCancel => 'Relâchez pour annuler';

  @override
  String get chatTakePhoto => 'Photo';

  @override
  String get legalSection => 'Légal';

  @override
  String get accountExportData => 'Exporter mes données';

  @override
  String get accountRequestExport => 'Demander une exportation de mes données';

  @override
  String get exportRequestTitle => 'Demander une exportation';

  @override
  String get exportRequestBody =>
      'Nous préparerons vos données et vous les enverrons par email. Confirmez l\'adresse ci-dessous.';

  @override
  String get exportRequestEmail => 'Adresse email';

  @override
  String get exportRequestSend => 'Envoyer la demande';

  @override
  String get exportRequestSent =>
      'Demande envoyée. Vous recevrez vos données par email.';

  @override
  String get accountDeleteTitle => 'Supprimer mon compte';

  @override
  String get accountDeleteWarning =>
      'Cette action est définitive et irréversible. Votre profil, vos services et vos informations personnelles seront supprimés.';

  @override
  String get accountDeleteConfirm => 'Supprimer définitivement';

  @override
  String get accountDeleted => 'Votre compte a été supprimé.';

  @override
  String get blockUser => 'Bloquer cet utilisateur';

  @override
  String get unblockUser => 'Débloquer cet utilisateur';

  @override
  String get blockUserConfirm =>
      'Bloquer cet utilisateur ? Vous ne verrez plus ses messages et il ne pourra plus vous contacter.';

  @override
  String get userBlocked => 'Utilisateur bloqué';

  @override
  String get userUnblocked => 'Utilisateur débloqué';

  @override
  String get chatBlockedBanner =>
      'Vous avez bloqué cet utilisateur. Débloquez-le pour échanger à nouveau.';

  @override
  String get blockedUsersTitle => 'Comptes bloqués';

  @override
  String get blockedUsersEmpty => 'Vous n\'avez bloqué personne.';

  @override
  String get blockedUsersEmptyHint =>
      'Vous pouvez bloquer quelqu\'un depuis une conversation.';

  @override
  String get blockedUserUnknown => 'Utilisateur';

  @override
  String get bookingModeText => 'Texte';

  @override
  String get bookingModeVoice => 'Vocal';

  @override
  String reviewStarLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count étoile$_temp0';
  }

  @override
  String get chatReply => 'Répondre';

  @override
  String get chatCopy => 'Copier';

  @override
  String get chatCopied => 'Copié';

  @override
  String get chatDelete => 'Supprimer';

  @override
  String get chatReportMessage => 'Signaler ce message';

  @override
  String get chatDeletedMessage => 'Message supprimé';

  @override
  String get chatReplyingTo => 'Réponse à';

  @override
  String get chatEdit => 'Modifier';

  @override
  String get chatEditing => 'Modifier le message';

  @override
  String get chatEdited => 'modifié';

  @override
  String get chatDateToday => 'Aujourd\'hui';

  @override
  String get chatDateYesterday => 'Hier';

  @override
  String get chatLoadOlder => 'Afficher les messages plus anciens';

  @override
  String get zoneSheetEditTitle => 'Modifier la zone';

  @override
  String get zoneSheetAddTitle => 'Ajouter une zone';

  @override
  String get zoneCityOrAddress => 'Ville ou adresse';

  @override
  String get zoneEdit => 'Modifier';

  @override
  String get serviceFormPhotoRemove => 'Supprimer la photo';

  @override
  String get serviceFormPhotoRemoved => 'Photo supprimée';

  @override
  String get serviceFormPhotoUndo => 'Annuler';

  @override
  String get trustVerifiedLabel => 'Profil vérifié';

  @override
  String get trustPendingLabel => 'Vérification en cours';

  @override
  String get trustUnverifiedLabel => 'Identité non vérifiée';

  @override
  String get identityCaptureRectoTitle => 'Recto de la pièce';

  @override
  String get identityCaptureVersoTitle => 'Verso de la pièce';

  @override
  String get identityCaptureRectoInstruction =>
      'Placez le recto de votre carte dans le cadre, bien à plat et lisible.';

  @override
  String get identityCaptureVersoInstruction =>
      'Placez le verso de votre carte dans le cadre, bien à plat et lisible.';

  @override
  String get identityCaptureButton => 'Prendre la photo';

  @override
  String get identityCaptureRetake => 'Reprendre';

  @override
  String get identityCaptureUse => 'Utiliser cette photo';

  @override
  String get identityCaptureBlurry =>
      'Photo trop floue. Stabilisez l\'appareil et rapprochez le document.';

  @override
  String get identityCaptureNoText =>
      'Aucun texte lisible détecté. Cadrez bien votre carte d\'identité dans le repère.';

  @override
  String get identityCaptureSendAnyway =>
      'Envoyer quand même, un humain relira';

  @override
  String get identityCaptureAutoHint => 'La photo se prend toute seule.';

  @override
  String get identityCaptureSearching => 'Placez la carte dans le repère.';

  @override
  String get identityCaptureFlipCard => 'Retournez la carte.';

  @override
  String get identityCaptureMoving => 'Tenez la carte immobile.';

  @override
  String get identityCaptureHoldStill => 'Restez immobile, la photo arrive.';

  @override
  String get identityCaptureRefused => 'Photo non retenue. Recadrez la carte.';

  @override
  String get identityCaptureManualHint =>
      'Vous pouvez aussi prendre la photo vous-même.';

  @override
  String get identityCaptureNoDocument =>
      'Placez votre carte d\'identité dans le cadre.';

  @override
  String get identityCaptureTooSmall => 'Rapprochez la carte.';

  @override
  String get identityCaptureTooClose => 'Éloignez un peu la carte.';

  @override
  String identityStepProgress(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get identityPermissionDeniedTitle => 'Caméra non autorisée';

  @override
  String get identityPermissionDeniedBody =>
      'Outalma a besoin de la caméra pour photographier votre pièce d\'identité. Autorisez l\'accès à la caméra pour continuer.';

  @override
  String get identityOpenSettings => 'Ouvrir les réglages';

  @override
  String get identityCameraUnavailableTitle => 'Caméra indisponible';

  @override
  String get identityCameraUnavailableBody =>
      'Aucune caméra utilisable sur cet appareil. Le parcours de vérification se fait depuis un téléphone.';

  @override
  String get identityRetry => 'Réessayer';

  @override
  String get identitySelfieTitle => 'Selfie de vérification';

  @override
  String get identityLivenessWaitingFace =>
      'Placez votre visage dans le cadre.';

  @override
  String get identityLivenessMultipleFaces =>
      'Un seul visage doit être visible.';

  @override
  String get identityLivenessTurnHead =>
      'Tournez lentement la tête sur le côté.';

  @override
  String get identityLivenessReturnToFront =>
      'Revenez maintenant face à l\'objectif.';

  @override
  String get identityLivenessReady => 'Ne bougez plus.';

  @override
  String get identityLivenessExpired => 'Le défi a expiré. On recommence.';

  @override
  String get identityLivenessRetryDifferent =>
      'On recommence : tournez lentement la tête sur le côté, puis revenez face à l\'objectif.';

  @override
  String get identityLivenessFaceGuideLabel =>
      'Démonstration du mouvement à faire avec la tête.';

  @override
  String get identityLivenessSupportTitle => 'Besoin d\'aide ?';

  @override
  String get identityLivenessSupportBody =>
      'Le défi n\'a pas abouti après plusieurs essais. Contactez le support pour finaliser votre vérification.';

  @override
  String get identityContactSupport => 'Contacter le support';

  @override
  String get identityRecapTitle => 'Vérifiez vos photos';

  @override
  String get identityRecapBody =>
      'Ces trois images vont être envoyées pour vérification.';

  @override
  String get identityRecapConfirm => 'Envoyer pour vérification';

  @override
  String get identityDepositUploading => 'Envoi de vos photos…';

  @override
  String get identityDepositSubmitting => 'Finalisation…';

  @override
  String get identityDepositSuccessTitle => 'Photos envoyées';

  @override
  String get identityDepositSuccessBody =>
      'Votre dossier est en cours d\'examen. Vous serez notifié de la décision.';

  @override
  String get identityDepositAlreadySubmitted =>
      'Ce dépôt a déjà été enregistré.';

  @override
  String get identityErrorBatchInvalid =>
      'L\'envoi n\'est pas allé au bout. Reprenez vos photos.';

  @override
  String get identityErrorObjectsMissing =>
      'Vos photos ne sont pas arrivées. Reprenez la capture.';

  @override
  String get identityErrorBatchStale =>
      'Vos photos ont trop attendu. Reprenez la capture.';

  @override
  String get identityErrorAccountMissing =>
      'Session expirée. Reconnectez-vous.';

  @override
  String get identityErrorPendingExists =>
      'Un dossier est déjà en cours de vérification.';

  @override
  String get identityErrorAlreadyVerified =>
      'Votre identité est déjà vérifiée.';

  @override
  String get identityErrorRateLimited =>
      'Trop de dépôts récents. Réessayez plus tard.';

  @override
  String identityErrorRateLimitedWithDelay(String duration) {
    return 'Trop de dépôts récents. Réessayez dans $duration.';
  }

  @override
  String get identityErrorStorageDenied =>
      'L\'envoi a été refusé. Reprenez vos photos.';

  @override
  String get identityErrorNetwork =>
      'Connexion interrompue. Vous pouvez reprendre.';

  @override
  String get identityErrorUnknown => 'Une erreur est survenue. Réessayez.';

  @override
  String identityDurationHours(int hours) {
    return '$hours h';
  }

  @override
  String identityDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get identityDone => 'Terminé';

  @override
  String get identityGuideTitle => 'Vérifier votre identité';

  @override
  String get identityGuideStepRecto => 'Recto';

  @override
  String get identityGuideStepVerso => 'Verso';

  @override
  String get identityGuideStepSelfie => 'Selfie';

  @override
  String get identityGuideWhy =>
      'Un profil vérifié inspire confiance aux clients. Le badge montre que vous êtes bien la personne annoncée.';

  @override
  String get identityGuideNext =>
      'Un membre de notre équipe examine votre dossier sous 48 heures. Vous pouvez continuer à proposer vos services pendant ce temps.';

  @override
  String get identityGuideHave =>
      'Munissez-vous de votre carte d\'identité CEDEAO, dans un endroit éclairé. Prévoyez deux minutes. Vos photos ne sont pas conservées sur le téléphone.';

  @override
  String get identityGuideStart => 'Commencer';

  @override
  String get identityGuideConsentHint => 'Cochez la case pour continuer';

  @override
  String get identityGuideMention1 =>
      'Nous collectons une photo du recto et du verso de votre carte d\'identité, et un selfie.';

  @override
  String get identityGuideMention2 =>
      'Elles servent uniquement à vérifier que vous êtes bien la personne qui propose ses services sur Outalma.';

  @override
  String get identityGuideMention3 =>
      'Seules les personnes habilitées de l\'équipe Outalma peuvent les consulter. Aucun client, aucun autre prestataire n\'y a accès.';

  @override
  String get identityGuideMention4 =>
      'Elles sont conservées jusqu\'à la suppression de votre compte.';

  @override
  String get identityGuideMention5 =>
      'Vous pouvez supprimer votre compte à tout moment depuis vos réglages.';

  @override
  String get identityGuideMention6 =>
      'Nous répondons sous 48 heures. Vous pouvez continuer à proposer vos services pendant ce temps.';

  @override
  String get identityConsentCheckbox =>
      'J\'ai lu ce qui précède et j\'accepte d\'envoyer ma pièce d\'identité et mon selfie à Outalma pour vérification.';

  @override
  String get identityConsentTermsLink => 'Lire les conditions d\'utilisation';

  @override
  String get identityStatusTitle => 'Vérification d\'identité';

  @override
  String get identityStatusNoneBody =>
      'Obtenez le badge « Profil vérifié » pour que les clients vous fassent confiance avant de réserver.';

  @override
  String get identityStatusStartCta => 'Vérifier mon identité';

  @override
  String get identityStatusRestartCta => 'Recommencer';

  @override
  String identityStatusPendingBody(String date) {
    return 'Déposé le $date, réponse sous 48 heures. Vous recevrez une notification de la décision.';
  }

  @override
  String get identityStatusPendingBodyNoDate =>
      'Votre dossier est en cours d\'examen, réponse sous 48 heures. Vous recevrez une notification de la décision.';

  @override
  String identityStatusVerifiedBody(String date) {
    return 'Vérifié depuis le $date.';
  }

  @override
  String get identityStatusVerifiedBodyNoDate => 'Votre profil est vérifié.';

  @override
  String get identityStatusRejectedTitle => 'Vérification refusée';

  @override
  String get identityStatusRevokedTitle => 'Vérification retirée';

  @override
  String get identityStatusPriorityNote =>
      'Votre prochain dossier sera traité en priorité.';

  @override
  String get identityStatusNoReason =>
      'Aucun motif n\'a été indiqué. Vous pouvez recommencer.';

  @override
  String get identityStatusUnavailable => 'État indisponible';

  @override
  String get identityWebOnlyMobile =>
      'La vérification d\'identité se fait depuis l\'application mobile Outalma.';

  @override
  String get identityWebBack => 'Retour';

  @override
  String identitySupportReference(String reference) {
    return 'Votre référence : $reference';
  }

  @override
  String get hubIdentityVerifiedSub => 'Votre profil est vérifié';

  @override
  String get hubIdentityPendingSub => 'Réponse sous 48 heures';

  @override
  String get hubIdentityVerifyCta => 'Vérifier mon identité';

  @override
  String get hubIdentityVerifySub => 'Obtenez le badge « Profil vérifié »';

  @override
  String get hubIdentityActionRequiredSub =>
      'Action requise : recommencez la vérification';

  @override
  String get profileIdentitySection => 'Vérification d\'identité';

  @override
  String get calendarFormatMonth => 'Mois';

  @override
  String get calendarFormatTwoWeeks => '2 sem.';

  @override
  String get serviceSeeReviews => 'Voir les avis';

  @override
  String get homeGuestGreeting =>
      'Trouvez un prestataire de confiance près de chez vous';

  @override
  String get guestSignIn => 'Se connecter';

  @override
  String get authPromptBenefits =>
      'Un compte vous permet de réserver, d\'échanger avec votre prestataire et de suivre vos demandes.';

  @override
  String get authPromptKeepBrowsing => 'Continuer sans compte';

  @override
  String get bookingRequiresLogin => 'Créez un compte pour réserver ce service';

  @override
  String get guestLockedSectionLogin =>
      'Connectez-vous pour ouvrir cette section';

  @override
  String get introContinueAsGuest => 'Explorer sans compte';

  @override
  String get introAlreadyHaveAccount => 'J\'ai déjà un compte';

  @override
  String get avatarSheetTitle => 'Photo de profil';

  @override
  String get avatarPreviewLabel => 'Aperçu';

  @override
  String get avatarImportPhoto => 'Importer une photo';

  @override
  String get avatarRemove => 'Retirer, revenir aux initiales';

  @override
  String get avatarSkinToneLabel => 'Teinte de peau';

  @override
  String get avatarSectionAnimals => 'Animaux';

  @override
  String get avatarErrorSave =>
      'Impossible d\'enregistrer votre choix. Réessayez.';

  @override
  String get profileChangeAvatarA11y => 'Changer la photo de profil';

  @override
  String avatarItemLabel(int index, int total) {
    return 'Avatar $index sur $total';
  }

  @override
  String avatarAnimalLabel(int index, int total) {
    return 'Animal $index sur $total';
  }

  @override
  String avatarSkinToneItem(int index, int total) {
    return 'Teinte de peau $index sur $total';
  }

  @override
  String get avatarSheetClose => 'Fermer';
}
