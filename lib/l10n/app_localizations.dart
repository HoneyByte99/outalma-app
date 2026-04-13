import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get navBookings;

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get navMissions;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @tooltipNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tooltipNotifications;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @errorGeneral.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get errorGeneral;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading error'**
  String get errorLoading;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get errorNetwork;

  /// No description provided for @signInWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get signInWelcome;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your services.'**
  String get signInSubtitle;

  /// No description provided for @signInEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get signInEmailHint;

  /// No description provided for @signInPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPasswordHint;

  /// No description provided for @signInForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgotPassword;

  /// No description provided for @signInForgotEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset your password.'**
  String get signInForgotEnterEmail;

  /// No description provided for @signInForgotEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Reset email sent.'**
  String get signInForgotEmailSent;

  /// No description provided for @signInForgotEmailError.
  ///
  /// In en, this message translates to:
  /// **'Could not send email. Check the address.'**
  String get signInForgotEmailError;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @signInNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account? '**
  String get signInNoAccount;

  /// No description provided for @signInRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signInRegister;

  /// No description provided for @signInErrorEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get signInErrorEmptyFields;

  /// No description provided for @authErrorInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorInvalidCredential;

  /// No description provided for @authErrorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authErrorAccountDisabled;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Check your credentials.'**
  String get authErrorSignInFailed;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join Outalma and access home services.'**
  String get signUpSubtitle;

  /// No description provided for @signUpNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get signUpNameHint;

  /// No description provided for @signUpPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password (min. 6 characters)'**
  String get signUpPasswordHint;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpButton;

  /// No description provided for @signUpHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get signUpHaveAccount;

  /// No description provided for @signUpSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signUpSignIn;

  /// No description provided for @signUpErrorEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get signUpErrorEmptyFields;

  /// No description provided for @signUpErrorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get signUpErrorPasswordTooShort;

  /// No description provided for @authErrorEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get authErrorEmailAlreadyInUse;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password too weak (min. 6 characters).'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Check your information.'**
  String get authErrorSignUpFailed;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingNoName.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get homeGreetingNoName;

  /// No description provided for @homeSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'What are you looking for?'**
  String get homeSearchPrompt;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @servicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No services available\nright now'**
  String get servicesEmpty;

  /// No description provided for @modeClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get modeClient;

  /// No description provided for @modeProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get modeProvider;

  /// No description provided for @modeClientActivated.
  ///
  /// In en, this message translates to:
  /// **'Client mode activated'**
  String get modeClientActivated;

  /// No description provided for @modeProviderActivated.
  ///
  /// In en, this message translates to:
  /// **'Provider mode activated'**
  String get modeProviderActivated;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationTitle;

  /// No description provided for @locationAllFrance.
  ///
  /// In en, this message translates to:
  /// **'All of France'**
  String get locationAllFrance;

  /// No description provided for @locationValidate.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get locationValidate;

  /// No description provided for @locationUseMyPosition.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get locationUseMyPosition;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @locationGeoError.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location'**
  String get locationGeoError;

  /// No description provided for @locationSearchHint.
  ///
  /// In en, this message translates to:
  /// **'City or address'**
  String get locationSearchHint;

  /// No description provided for @locationSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save this address'**
  String get locationSaveTooltip;

  /// No description provided for @locationRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get locationRadius;

  /// No description provided for @locationAddressName.
  ///
  /// In en, this message translates to:
  /// **'Address name'**
  String get locationAddressName;

  /// No description provided for @locationAddressHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Home, Office…'**
  String get locationAddressHint;

  /// No description provided for @locationMyAddresses.
  ///
  /// In en, this message translates to:
  /// **'My addresses'**
  String get locationMyAddresses;

  /// No description provided for @locationSaved.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" saved'**
  String locationSaved(String name);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile & Settings'**
  String get profileTitle;

  /// No description provided for @profileMyReviews.
  ///
  /// In en, this message translates to:
  /// **'My reviews'**
  String get profileMyReviews;

  /// No description provided for @profileActiveMode.
  ///
  /// In en, this message translates to:
  /// **'Active mode'**
  String get profileActiveMode;

  /// No description provided for @profileInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get profileInformation;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileErrorUpload.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String profileErrorUpload(String error);

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileSaved;

  /// No description provided for @profileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get profileSaveError;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldFullName;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get fieldRequired;

  /// No description provided for @fieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get fieldCountry;

  /// No description provided for @modeClientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book services'**
  String get modeClientSubtitle;

  /// No description provided for @modeProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage my missions'**
  String get modeProviderSubtitle;

  /// No description provided for @modeSwitchError.
  ///
  /// In en, this message translates to:
  /// **'Could not switch mode. Please try again.'**
  String get modeSwitchError;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutContent.
  ///
  /// In en, this message translates to:
  /// **'You will need to enter your credentials to sign back in.'**
  String get signOutContent;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutButton;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @reviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reviews received yet'**
  String get reviewsEmpty;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews} =1{1 review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardMyServices.
  ///
  /// In en, this message translates to:
  /// **'My services'**
  String get dashboardMyServices;

  /// No description provided for @dashboardAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get dashboardAdd;

  /// No description provided for @dashboardActivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate your profile'**
  String get dashboardActivateTitle;

  /// No description provided for @dashboardActivateBody.
  ///
  /// In en, this message translates to:
  /// **'A few details to start receiving requests.'**
  String get dashboardActivateBody;

  /// No description provided for @dashboardActivateButton.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get dashboardActivateButton;

  /// No description provided for @profileActive.
  ///
  /// In en, this message translates to:
  /// **'Active profile'**
  String get profileActive;

  /// No description provided for @profileInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive profile'**
  String get profileInactive;

  /// No description provided for @dashboardServicesError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your services.'**
  String get dashboardServicesError;

  /// No description provided for @serviceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No services published'**
  String get serviceEmptyTitle;

  /// No description provided for @serviceEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first service to start receiving requests.'**
  String get serviceEmptyBody;

  /// No description provided for @serviceCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a service'**
  String get serviceCreate;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// No description provided for @notPublished.
  ///
  /// In en, this message translates to:
  /// **'Unpublished'**
  String get notPublished;

  /// No description provided for @tooltipProviderProfile.
  ///
  /// In en, this message translates to:
  /// **'My provider profile'**
  String get tooltipProviderProfile;

  /// No description provided for @bookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get bookingsTitle;

  /// No description provided for @tabActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get tabActive;

  /// No description provided for @tabDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tabDone;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAccepted;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusDone;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @bookingsActiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active bookings'**
  String get bookingsActiveEmpty;

  /// No description provided for @bookingsDoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed bookings'**
  String get bookingsDoneEmpty;

  /// No description provided for @bookingNoDateToday.
  ///
  /// In en, this message translates to:
  /// **'No bookings on this day'**
  String get bookingNoDateToday;

  /// No description provided for @bookingNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings'**
  String get bookingNoUpcoming;

  /// No description provided for @bookingRequestedAt.
  ///
  /// In en, this message translates to:
  /// **'Request from {date}'**
  String bookingRequestedAt(String date);

  /// No description provided for @bookingScheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled: {datetime}'**
  String bookingScheduledAt(String datetime);

  /// No description provided for @bookingDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking details'**
  String get bookingDetailTitle;

  /// No description provided for @bookingService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get bookingService;

  /// No description provided for @bookingMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get bookingMessage;

  /// No description provided for @bookingNoMessage.
  ///
  /// In en, this message translates to:
  /// **'No message'**
  String get bookingNoMessage;

  /// No description provided for @bookingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Time slot'**
  String get bookingSchedule;

  /// No description provided for @bookingScheduleUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get bookingScheduleUnspecified;

  /// No description provided for @bookingAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get bookingAddress;

  /// No description provided for @bookingAddressUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get bookingAddressUnspecified;

  /// No description provided for @bookingContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get bookingContact;

  /// No description provided for @bookingPhoneNotShared.
  ///
  /// In en, this message translates to:
  /// **'Phone number not yet shared'**
  String get bookingPhoneNotShared;

  /// No description provided for @bookingAddPhoneInProfile.
  ///
  /// In en, this message translates to:
  /// **'Add your phone number in your profile to share it.'**
  String get bookingAddPhoneInProfile;

  /// No description provided for @bookingPhoneShared.
  ///
  /// In en, this message translates to:
  /// **'Your phone number is shared'**
  String get bookingPhoneShared;

  /// No description provided for @bookingSharePhone.
  ///
  /// In en, this message translates to:
  /// **'Share my number ({phone})'**
  String bookingSharePhone(String phone);

  /// No description provided for @bookingSharePhoneError.
  ///
  /// In en, this message translates to:
  /// **'Could not share phone number.'**
  String get bookingSharePhoneError;

  /// No description provided for @bookingOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get bookingOpenChat;

  /// No description provided for @bookingReviewSent.
  ///
  /// In en, this message translates to:
  /// **'Review sent — thank you!'**
  String get bookingReviewSent;

  /// No description provided for @bookingLeaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get bookingLeaveReview;

  /// No description provided for @bookingTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get bookingTimeline;

  /// No description provided for @timelineRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get timelineRequestSent;

  /// No description provided for @timelineAccepted.
  ///
  /// In en, this message translates to:
  /// **'Request accepted'**
  String get timelineAccepted;

  /// No description provided for @timelineRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get timelineRejected;

  /// No description provided for @timelineInProgress.
  ///
  /// In en, this message translates to:
  /// **'Service in progress'**
  String get timelineInProgress;

  /// No description provided for @timelineCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get timelineCancelled;

  /// No description provided for @timelineDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get timelineDone;

  /// No description provided for @timelinePendingResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response'**
  String get timelinePendingResponse;

  /// No description provided for @timelineUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming service'**
  String get timelineUpcoming;

  /// No description provided for @bookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking not found'**
  String get bookingNotFound;

  /// No description provided for @bookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get bookingTitle;

  /// No description provided for @bookingReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get bookingReport;

  /// No description provided for @bookingAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get bookingAccept;

  /// No description provided for @bookingReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get bookingReject;

  /// No description provided for @bookingAccepted.
  ///
  /// In en, this message translates to:
  /// **'Request accepted'**
  String get bookingAccepted;

  /// No description provided for @bookingRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get bookingRejected;

  /// No description provided for @bookingAcceptError.
  ///
  /// In en, this message translates to:
  /// **'Error while accepting.'**
  String get bookingAcceptError;

  /// No description provided for @bookingRejectError.
  ///
  /// In en, this message translates to:
  /// **'Error while rejecting.'**
  String get bookingRejectError;

  /// No description provided for @bookingStartService.
  ///
  /// In en, this message translates to:
  /// **'Start service'**
  String get bookingStartService;

  /// No description provided for @bookingServiceStarted.
  ///
  /// In en, this message translates to:
  /// **'Service started'**
  String get bookingServiceStarted;

  /// No description provided for @bookingStartError.
  ///
  /// In en, this message translates to:
  /// **'Error while starting.'**
  String get bookingStartError;

  /// No description provided for @bookingCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel the request?'**
  String get bookingCancelTitle;

  /// No description provided for @bookingCancelContent.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible.'**
  String get bookingCancelContent;

  /// No description provided for @bookingCancelYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get bookingCancelYes;

  /// No description provided for @bookingCancelNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get bookingCancelNo;

  /// No description provided for @bookingCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get bookingCancelButton;

  /// No description provided for @bookingCancelError.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel. Please try again.'**
  String get bookingCancelError;

  /// No description provided for @bookingConfirmDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm completion?'**
  String get bookingConfirmDoneTitle;

  /// No description provided for @bookingConfirmDoneContent.
  ///
  /// In en, this message translates to:
  /// **'By confirming, the service will be marked as completed. You can then leave a review.'**
  String get bookingConfirmDoneContent;

  /// No description provided for @bookingConfirmDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm service completion'**
  String get bookingConfirmDoneButton;

  /// No description provided for @bookingDoneSuccess.
  ///
  /// In en, this message translates to:
  /// **'Service completed!'**
  String get bookingDoneSuccess;

  /// No description provided for @bookingDoneError.
  ///
  /// In en, this message translates to:
  /// **'Error while confirming.'**
  String get bookingDoneError;

  /// No description provided for @bookingRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Request this service'**
  String get bookingRequestTitle;

  /// No description provided for @bookingStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Describe your need'**
  String get bookingStep1Title;

  /// No description provided for @bookingStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Give details to help the provider understand your request.'**
  String get bookingStep1Subtitle;

  /// No description provided for @bookingStep1Hint.
  ///
  /// In en, this message translates to:
  /// **'E.g. I need a full cleaning of my apartment…'**
  String get bookingStep1Hint;

  /// No description provided for @bookingStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Preferred date and time'**
  String get bookingStep2Title;

  /// No description provided for @bookingStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a time slot (optional).'**
  String get bookingStep2Subtitle;

  /// No description provided for @bookingStep2PickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get bookingStep2PickDate;

  /// No description provided for @bookingStep2PickTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a time'**
  String get bookingStep2PickTime;

  /// No description provided for @bookingStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Service address'**
  String get bookingStep3Title;

  /// No description provided for @bookingStep3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Where should the provider intervene? (optional)'**
  String get bookingStep3Subtitle;

  /// No description provided for @bookingStep3Hint.
  ///
  /// In en, this message translates to:
  /// **'E.g. 12 rue de la Paix, Paris 75001'**
  String get bookingStep3Hint;

  /// No description provided for @bookingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get bookingBack;

  /// No description provided for @bookingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get bookingContinue;

  /// No description provided for @bookingSend.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get bookingSend;

  /// No description provided for @bookingSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request sent successfully ✓'**
  String get bookingSentSuccess;

  /// No description provided for @bookingConflictBusy.
  ///
  /// In en, this message translates to:
  /// **'The provider already has an appointment at this time.'**
  String get bookingConflictBusy;

  /// No description provided for @bookingConflictUnavailableDay.
  ///
  /// In en, this message translates to:
  /// **'The provider is unavailable on this day.'**
  String get bookingConflictUnavailableDay;

  /// No description provided for @bookingConflictUnavailableSlot.
  ///
  /// In en, this message translates to:
  /// **'The provider is unavailable at this time slot.'**
  String get bookingConflictUnavailableSlot;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active chats'**
  String get chatEmpty;

  /// No description provided for @chatEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Conversations start after\na booking is accepted.'**
  String get chatEmptySubtitle;

  /// No description provided for @chatActiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active conversations'**
  String get chatActiveEmpty;

  /// No description provided for @chatDoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed conversations'**
  String get chatDoneEmpty;

  /// No description provided for @chatStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation'**
  String get chatStartConversation;

  /// No description provided for @chatYou.
  ///
  /// In en, this message translates to:
  /// **'You: '**
  String get chatYou;

  /// No description provided for @chatLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages.'**
  String get chatLoadError;

  /// No description provided for @chatConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatConversation;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get chatTyping;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatErrorSend.
  ///
  /// In en, this message translates to:
  /// **'Could not send.'**
  String get chatErrorSend;

  /// No description provided for @chatTabActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get chatTabActive;

  /// No description provided for @chatTabDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chatTabDone;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsReadAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsReadAll;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsEmpty;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You will be notified here\nwhen something happens.'**
  String get notificationsEmptySubtitle;

  /// No description provided for @notificationsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications.'**
  String get notificationsError;

  /// No description provided for @notificationTimeNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get notificationTimeNow;

  /// No description provided for @notificationTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String notificationTimeMinutes(int count);

  /// No description provided for @notificationTimeHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String notificationTimeHours(int count);

  /// No description provided for @notificationTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notificationTimeYesterday;

  /// No description provided for @notificationTimeDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String notificationTimeDays(int count);

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get inboxTitle;

  /// No description provided for @inboxCalendarTooltip.
  ///
  /// In en, this message translates to:
  /// **'My calendar'**
  String get inboxCalendarTooltip;

  /// No description provided for @inboxTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get inboxTabRequests;

  /// No description provided for @inboxTabActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inboxTabActive;

  /// No description provided for @inboxEmptyRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get inboxEmptyRequests;

  /// No description provided for @inboxEmptyRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New client requests will appear here.'**
  String get inboxEmptyRequestsSubtitle;

  /// No description provided for @inboxEmptyActive.
  ///
  /// In en, this message translates to:
  /// **'No active missions'**
  String get inboxEmptyActive;

  /// No description provided for @inboxEmptyActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accepted missions will appear here.'**
  String get inboxEmptyActiveSubtitle;

  /// No description provided for @inboxLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load data.'**
  String get inboxLoadError;

  /// No description provided for @inboxOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get inboxOpenChat;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get reviewTitle;

  /// No description provided for @reviewEvaluateProvider.
  ///
  /// In en, this message translates to:
  /// **'Rate the provider'**
  String get reviewEvaluateProvider;

  /// No description provided for @reviewEvaluateClient.
  ///
  /// In en, this message translates to:
  /// **'Rate the client'**
  String get reviewEvaluateClient;

  /// No description provided for @reviewHelp.
  ///
  /// In en, this message translates to:
  /// **'Your review helps the community build trust.'**
  String get reviewHelp;

  /// No description provided for @reviewRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get reviewRating;

  /// No description provided for @reviewComment.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get reviewComment;

  /// No description provided for @reviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience…'**
  String get reviewCommentHint;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get reviewSubmit;

  /// No description provided for @reviewError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit review.'**
  String get reviewError;

  /// No description provided for @reviewBookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking not found.'**
  String get reviewBookingNotFound;

  /// No description provided for @reviewOnlyAfterDone.
  ///
  /// In en, this message translates to:
  /// **'Review available only after service completion.'**
  String get reviewOnlyAfterDone;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @reportQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting?'**
  String get reportQuestion;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your report is anonymous and will be reviewed by our team.'**
  String get reportSubtitle;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// No description provided for @reportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you.'**
  String get reportSuccess;

  /// No description provided for @reportError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit report.'**
  String get reportError;

  /// No description provided for @reportReason1.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate behaviour'**
  String get reportReason1;

  /// No description provided for @reportReason2.
  ///
  /// In en, this message translates to:
  /// **'Fake profile or scam'**
  String get reportReason2;

  /// No description provided for @reportReason3.
  ///
  /// In en, this message translates to:
  /// **'Service not performed'**
  String get reportReason3;

  /// No description provided for @reportReason4.
  ///
  /// In en, this message translates to:
  /// **'Offensive content'**
  String get reportReason4;

  /// No description provided for @reportReason5.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get reportReason5;

  /// No description provided for @reportReason6.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReason6;

  /// No description provided for @serviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get serviceDescription;

  /// No description provided for @serviceProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get serviceProviderLabel;

  /// No description provided for @serviceViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get serviceViewProfile;

  /// No description provided for @serviceBook.
  ///
  /// In en, this message translates to:
  /// **'Request this service'**
  String get serviceBook;

  /// No description provided for @serviceEditListing.
  ///
  /// In en, this message translates to:
  /// **'Edit this listing'**
  String get serviceEditListing;

  /// No description provided for @serviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Service not found'**
  String get serviceNotFound;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get seeMore;

  /// No description provided for @seeLess.
  ///
  /// In en, this message translates to:
  /// **'See less'**
  String get seeLess;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a provider'**
  String get onboardingTitle;

  /// No description provided for @onboardingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Offer your services'**
  String get onboardingHeadline;

  /// No description provided for @onboardingBody.
  ///
  /// In en, this message translates to:
  /// **'Create your provider profile in seconds. You can then publish your services and receive requests.'**
  String get onboardingBody;

  /// No description provided for @onboardingBio.
  ///
  /// In en, this message translates to:
  /// **'Introduction (optional)'**
  String get onboardingBio;

  /// No description provided for @onboardingBioHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Plumber with 10 years of experience, available in the Paris area…'**
  String get onboardingBioHint;

  /// No description provided for @onboardingZone.
  ///
  /// In en, this message translates to:
  /// **'Service area (optional)'**
  String get onboardingZone;

  /// No description provided for @onboardingZoneHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Paris and suburbs, Île-de-France…'**
  String get onboardingZoneHint;

  /// No description provided for @onboardingActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate my provider profile'**
  String get onboardingActivate;

  /// No description provided for @onboardingError.
  ///
  /// In en, this message translates to:
  /// **'Could not activate profile. Please try again.'**
  String get onboardingError;

  /// No description provided for @serviceFormCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New service'**
  String get serviceFormCreateTitle;

  /// No description provided for @serviceFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get serviceFormEditTitle;

  /// No description provided for @serviceFormTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Service title'**
  String get serviceFormTitleLabel;

  /// No description provided for @serviceFormTitleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Full apartment cleaning'**
  String get serviceFormTitleHint;

  /// No description provided for @serviceFormTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title required'**
  String get serviceFormTitleRequired;

  /// No description provided for @serviceFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get serviceFormCategory;

  /// No description provided for @serviceFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get serviceFormDescription;

  /// No description provided for @serviceFormDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what you offer…'**
  String get serviceFormDescriptionHint;

  /// No description provided for @serviceFormPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get serviceFormPrice;

  /// No description provided for @serviceFormPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get serviceFormPriceRequired;

  /// No description provided for @serviceFormPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get serviceFormPriceInvalid;

  /// No description provided for @serviceFormZones.
  ///
  /// In en, this message translates to:
  /// **'Service areas *'**
  String get serviceFormZones;

  /// No description provided for @serviceFormZonesRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one service area.'**
  String get serviceFormZonesRequired;

  /// No description provided for @serviceFormPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish this service'**
  String get serviceFormPublish;

  /// No description provided for @serviceFormPublishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visible to clients'**
  String get serviceFormPublishSubtitle;

  /// No description provided for @serviceFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get serviceFormSave;

  /// No description provided for @serviceFormCreate.
  ///
  /// In en, this message translates to:
  /// **'Create service'**
  String get serviceFormCreate;

  /// No description provided for @serviceFormPhotoError.
  ///
  /// In en, this message translates to:
  /// **'Could not upload photo. Please try again.'**
  String get serviceFormPhotoError;

  /// No description provided for @serviceFormSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get serviceFormSaveError;

  /// No description provided for @zoneAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add area'**
  String get zoneAddTitle;

  /// No description provided for @zoneEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit area'**
  String get zoneEditTitle;

  /// No description provided for @zoneAddressHint.
  ///
  /// In en, this message translates to:
  /// **'City or address'**
  String get zoneAddressHint;

  /// No description provided for @zoneSelectError.
  ///
  /// In en, this message translates to:
  /// **'Select an address from suggestions'**
  String get zoneSelectError;

  /// No description provided for @zoneLocateError.
  ///
  /// In en, this message translates to:
  /// **'Could not locate this address.'**
  String get zoneLocateError;

  /// No description provided for @zoneConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection required to add an area.'**
  String get zoneConnectionError;

  /// No description provided for @zoneRadius.
  ///
  /// In en, this message translates to:
  /// **'Service radius'**
  String get zoneRadius;

  /// No description provided for @zoneNone.
  ///
  /// In en, this message translates to:
  /// **'No areas added'**
  String get zoneNone;

  /// No description provided for @zoneAdd.
  ///
  /// In en, this message translates to:
  /// **'Add an area'**
  String get zoneAdd;

  /// No description provided for @priceHourly.
  ///
  /// In en, this message translates to:
  /// **'per hour'**
  String get priceHourly;

  /// No description provided for @priceFixed.
  ///
  /// In en, this message translates to:
  /// **'flat fee'**
  String get priceFixed;

  /// No description provided for @photoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a photo (optional)'**
  String get photoAdd;

  /// No description provided for @zoneRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Radius: {radius}'**
  String zoneRadiusLabel(String radius);

  /// No description provided for @zoneValidate.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get zoneValidate;

  /// No description provided for @zoneModify.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get zoneModify;

  /// No description provided for @phoneAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneAuthTitle;

  /// No description provided for @phoneAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your number to receive a verification code via SMS.'**
  String get phoneAuthSubtitle;

  /// No description provided for @phoneAuthButton.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get phoneAuthButton;

  /// No description provided for @phoneAuthWithNumber.
  ///
  /// In en, this message translates to:
  /// **'Continue with a phone number'**
  String get phoneAuthWithNumber;

  /// No description provided for @phoneAuthOrWith.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get phoneAuthOrWith;

  /// No description provided for @phoneAuthWebUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Phone sign-in is only available on the mobile app.'**
  String get phoneAuthWebUnsupported;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A code was sent to {phone}'**
  String otpSubtitle(String phone);

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpHint;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Please try again.'**
  String get otpError;

  /// No description provided for @otpPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Could not send code. Check the number.'**
  String get otpPhoneError;

  /// No description provided for @phoneNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get phoneNameTitle;

  /// No description provided for @phoneNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This name will be visible to other users.'**
  String get phoneNameSubtitle;

  /// No description provided for @phoneNameHint.
  ///
  /// In en, this message translates to:
  /// **'First and last name'**
  String get phoneNameHint;

  /// No description provided for @phoneNameButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get phoneNameButton;

  /// No description provided for @phoneNameError.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get phoneNameError;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System (device)'**
  String get langSystem;

  /// No description provided for @langFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get langFrench;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @switchModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a mode'**
  String get switchModeTitle;

  /// No description provided for @switchModeHeading.
  ///
  /// In en, this message translates to:
  /// **'Your active mode'**
  String get switchModeHeading;

  /// No description provided for @switchModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Switch between client and provider mode at any time.'**
  String get switchModeDescription;

  /// No description provided for @switchModeThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the app theme.'**
  String get switchModeThemeDescription;

  /// No description provided for @themeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follows your device preferences'**
  String get themeSystemSubtitle;

  /// No description provided for @themeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always in light mode'**
  String get themeLightSubtitle;

  /// No description provided for @themeDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always in dark mode'**
  String get themeDarkSubtitle;

  /// No description provided for @chatRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording in progress…'**
  String get chatRecording;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coordinate the service details here.'**
  String get chatSubtitle;

  /// No description provided for @chatMicError.
  ///
  /// In en, this message translates to:
  /// **'Could not activate microphone.'**
  String get chatMicError;

  /// No description provided for @chatVoiceError.
  ///
  /// In en, this message translates to:
  /// **'Could not send voice message.'**
  String get chatVoiceError;

  /// No description provided for @chatFileError.
  ///
  /// In en, this message translates to:
  /// **'Could not send file.'**
  String get chatFileError;

  /// No description provided for @chatAddCaption.
  ///
  /// In en, this message translates to:
  /// **'Add a message…'**
  String get chatAddCaption;

  /// No description provided for @chatGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatGallery;

  /// No description provided for @reviewsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsLabel;

  /// No description provided for @servicesOffered.
  ///
  /// In en, this message translates to:
  /// **'Services offered'**
  String get servicesOffered;

  /// No description provided for @bookingAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Service address'**
  String get bookingAddressLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
