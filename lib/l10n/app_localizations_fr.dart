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
  String get navDashboard => 'Dashboard';

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
  String homeGreeting(String name) {
    return 'Bonjour $name';
  }

  @override
  String get homeGreetingNoName => 'Bonjour';

  @override
  String get homeSearchPrompt => 'Que recherchez-vous ?';

  @override
  String get categoryAll => 'Tout';

  @override
  String get servicesEmpty => 'Aucun service disponible\npour le moment';

  @override
  String get modeClient => 'Client';

  @override
  String get modeProvider => 'Prestataire';

  @override
  String get modeClientActivated => 'Mode client activé';

  @override
  String get modeProviderActivated => 'Mode prestataire activé';

  @override
  String get locationTitle => 'Localisation';

  @override
  String get locationAllFrance => 'Toute la France';

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
  String profileErrorUpload(String error) {
    return 'Erreur : $error';
  }

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
  String get profileActive => 'Profil actif';

  @override
  String get profileInactive => 'Profil inactif';

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
  String get bookingContact => 'Contact';

  @override
  String get bookingPhoneNotShared => 'Numéro non encore partagé';

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
  String get bookingReviewSent => 'Avis envoyé — merci !';

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
  String get bookingCancelError => 'Impossible d\'annuler. Réessayez.';

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
  String get bookingStep2Title => 'Date et heure souhaitées';

  @override
  String get bookingStep2Subtitle => 'Sélectionnez un créneau (optionnel).';

  @override
  String get bookingStep2PickDate => 'Choisir une date';

  @override
  String get bookingStep2PickTime => 'Choisir une heure';

  @override
  String get bookingStep3Title => 'Adresse d\'intervention';

  @override
  String get bookingStep3Subtitle =>
      'Où souhaitez-vous que le prestataire intervienne ? (optionnel)';

  @override
  String get bookingStep3Hint => 'Ex: 12 rue de la Paix, Paris 75001';

  @override
  String get bookingBack => 'Retour';

  @override
  String get bookingContinue => 'Continuer';

  @override
  String get bookingSend => 'Envoyer la demande';

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
  String get inboxTabRequests => 'Demandes';

  @override
  String get inboxTabActive => 'En cours';

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
  String get inboxLoadError => 'Impossible de charger les données.';

  @override
  String get inboxOpenChat => 'Ouvrir le chat';

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
  String get onboardingHeadline => 'Proposez vos services';

  @override
  String get onboardingBody =>
      'Créez votre profil prestataire en quelques secondes. Vous pourrez ensuite publier vos services et recevoir des demandes.';

  @override
  String get onboardingBio => 'Présentation (optionnel)';

  @override
  String get onboardingBioHint =>
      'Ex: Plombier avec 10 ans d\'expérience, disponible en région parisienne…';

  @override
  String get onboardingZone => 'Zone d\'intervention (optionnel)';

  @override
  String get onboardingZoneHint => 'Ex: Paris et banlieue, Île-de-France…';

  @override
  String get onboardingActivate => 'Activer mon profil prestataire';

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
  String get serviceFormSaveError => 'Impossible d\'enregistrer. Réessayez.';

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
  String get chatVoiceError => 'Impossible d\'envoyer le vocal.';

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
}
