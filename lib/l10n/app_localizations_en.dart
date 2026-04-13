// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navChats => 'Chats';

  @override
  String get navProfile => 'Profile';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navMissions => 'Missions';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get tooltipNotifications => 'Notifications';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeSystem => 'System';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get errorGeneral => 'An error occurred. Please try again.';

  @override
  String get errorLoading => 'Loading error';

  @override
  String get errorNetwork => 'Connection error';

  @override
  String get signInWelcome => 'Welcome back!';

  @override
  String get signInSubtitle => 'Sign in to access your services.';

  @override
  String get signInEmailHint => 'Email address';

  @override
  String get signInPasswordHint => 'Password';

  @override
  String get signInForgotPassword => 'Forgot password?';

  @override
  String get signInForgotEnterEmail =>
      'Enter your email to reset your password.';

  @override
  String get signInForgotEmailSent => 'Reset email sent.';

  @override
  String get signInForgotEmailError =>
      'Could not send email. Check the address.';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInNoAccount => 'No account? ';

  @override
  String get signInRegister => 'Sign up';

  @override
  String get signInErrorEmptyFields => 'Please fill in all fields.';

  @override
  String get authErrorInvalidCredential => 'Incorrect email or password.';

  @override
  String get authErrorAccountDisabled => 'This account has been disabled.';

  @override
  String get authErrorTooManyRequests => 'Too many attempts. Try again later.';

  @override
  String get authErrorSignInFailed => 'Sign in failed. Check your credentials.';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpSubtitle => 'Join Outalma and access home services.';

  @override
  String get signUpNameHint => 'Your full name';

  @override
  String get signUpPasswordHint => 'Password (min. 6 characters)';

  @override
  String get signUpButton => 'Create account';

  @override
  String get signUpHaveAccount => 'Already have an account? ';

  @override
  String get signUpSignIn => 'Sign in';

  @override
  String get signUpErrorEmptyFields => 'Please fill in all required fields.';

  @override
  String get signUpErrorPasswordTooShort =>
      'Password must be at least 6 characters.';

  @override
  String get authErrorEmailAlreadyInUse => 'This email is already in use.';

  @override
  String get authErrorInvalidEmail => 'Invalid email address.';

  @override
  String get authErrorWeakPassword => 'Password too weak (min. 6 characters).';

  @override
  String get authErrorSignUpFailed => 'Sign up failed. Check your information.';

  @override
  String get authErrorPhoneTaken => 'This phone number is already in use.';

  @override
  String homeGreeting(String name) {
    return 'Hello $name';
  }

  @override
  String get homeGreetingNoName => 'Hello';

  @override
  String get homeSearchPrompt => 'What are you looking for?';

  @override
  String get categoryAll => 'All';

  @override
  String get servicesEmpty => 'No services available\nright now';

  @override
  String get modeClient => 'Client';

  @override
  String get modeProvider => 'Provider';

  @override
  String get modeClientActivated => 'Client mode activated';

  @override
  String get modeProviderActivated => 'Provider mode activated';

  @override
  String get locationTitle => 'Location';

  @override
  String get locationAllFrance => 'All of France';

  @override
  String get locationValidate => 'Apply';

  @override
  String get locationUseMyPosition => 'Use my location';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationServiceDisabled => 'Enable location services in settings';

  @override
  String get locationGeoError => 'Could not get your location';

  @override
  String get locationSearchHint => 'City or address';

  @override
  String get locationSaveTooltip => 'Save this address';

  @override
  String get locationRadius => 'Radius';

  @override
  String get locationAddressName => 'Address name';

  @override
  String get locationAddressHint => 'E.g. Home, Office…';

  @override
  String get locationMyAddresses => 'My addresses';

  @override
  String locationSaved(String name) {
    return '\"$name\" saved';
  }

  @override
  String get profileTitle => 'Profile & Settings';

  @override
  String get profileMyReviews => 'My reviews';

  @override
  String get profileActiveMode => 'Active mode';

  @override
  String get profileInformation => 'Information';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileAccount => 'Account';

  @override
  String profileErrorUpload(String error) {
    return 'Error: $error';
  }

  @override
  String get profileSaved => 'Profile updated.';

  @override
  String get profileSaveError => 'Could not save. Please try again.';

  @override
  String get profileLanguage => 'Language';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldRequired => 'Required field';

  @override
  String get fieldCountry => 'Country';

  @override
  String get modeClientSubtitle => 'Book services';

  @override
  String get modeProviderSubtitle => 'Manage my missions';

  @override
  String get modeSwitchError => 'Could not switch mode. Please try again.';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutContent =>
      'You will need to enter your credentials to sign back in.';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get signOut => 'Sign out';

  @override
  String get reviewsEmpty => 'No reviews received yet';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardMyServices => 'My services';

  @override
  String get dashboardAdd => 'Add';

  @override
  String get dashboardActivateTitle => 'Activate your profile';

  @override
  String get dashboardActivateBody =>
      'A few details to start receiving requests.';

  @override
  String get dashboardActivateButton => 'Get started';

  @override
  String get profileActive => 'Active profile';

  @override
  String get profileInactive => 'Inactive profile';

  @override
  String get dashboardServicesError => 'Could not load your services.';

  @override
  String get serviceEmptyTitle => 'No services published';

  @override
  String get serviceEmptyBody =>
      'Create your first service to start receiving requests.';

  @override
  String get serviceCreate => 'Create a service';

  @override
  String get published => 'Published';

  @override
  String get notPublished => 'Unpublished';

  @override
  String get tooltipProviderProfile => 'My provider profile';

  @override
  String get bookingsTitle => 'My bookings';

  @override
  String get tabActive => 'In progress';

  @override
  String get tabDone => 'Completed';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusDone => 'Completed';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get bookingsActiveEmpty => 'No active bookings';

  @override
  String get bookingsDoneEmpty => 'No completed bookings';

  @override
  String get bookingNoDateToday => 'No bookings on this day';

  @override
  String get bookingNoUpcoming => 'No upcoming bookings';

  @override
  String bookingRequestedAt(String date) {
    return 'Request from $date';
  }

  @override
  String bookingScheduledAt(String datetime) {
    return 'Scheduled: $datetime';
  }

  @override
  String get bookingDetailTitle => 'Booking details';

  @override
  String get bookingService => 'Service';

  @override
  String get bookingMessage => 'Message';

  @override
  String get bookingNoMessage => 'No message';

  @override
  String get bookingSchedule => 'Time slot';

  @override
  String get bookingScheduleUnspecified => 'Unspecified';

  @override
  String get bookingAddress => 'Address';

  @override
  String get bookingAddressUnspecified => 'Unspecified';

  @override
  String get bookingContact => 'Contact';

  @override
  String get bookingPhoneNotShared => 'Phone number not yet shared';

  @override
  String get bookingAddPhoneInProfile =>
      'Add your phone number in your profile to share it.';

  @override
  String get bookingPhoneShared => 'Your phone number is shared';

  @override
  String bookingSharePhone(String phone) {
    return 'Share my number ($phone)';
  }

  @override
  String get bookingSharePhoneError => 'Could not share phone number.';

  @override
  String get bookingOpenChat => 'Open chat';

  @override
  String get bookingReviewSent => 'Review sent — thank you!';

  @override
  String get bookingLeaveReview => 'Leave a review';

  @override
  String get bookingTimeline => 'Timeline';

  @override
  String get timelineRequestSent => 'Request sent';

  @override
  String get timelineAccepted => 'Request accepted';

  @override
  String get timelineRejected => 'Request rejected';

  @override
  String get timelineInProgress => 'Service in progress';

  @override
  String get timelineCancelled => 'Cancelled';

  @override
  String get timelineDone => 'Completed';

  @override
  String get timelinePendingResponse => 'Waiting for response';

  @override
  String get timelineUpcoming => 'Upcoming service';

  @override
  String get bookingNotFound => 'Booking not found';

  @override
  String get bookingTitle => 'Booking';

  @override
  String get bookingReport => 'Report';

  @override
  String get bookingAccept => 'Accept';

  @override
  String get bookingReject => 'Reject';

  @override
  String get bookingAccepted => 'Request accepted';

  @override
  String get bookingRejected => 'Request rejected';

  @override
  String get bookingAcceptError => 'Error while accepting.';

  @override
  String get bookingRejectError => 'Error while rejecting.';

  @override
  String get bookingStartService => 'Start service';

  @override
  String get bookingServiceStarted => 'Service started';

  @override
  String get bookingStartError => 'Error while starting.';

  @override
  String get bookingCancelTitle => 'Cancel the request?';

  @override
  String get bookingCancelContent => 'This action is irreversible.';

  @override
  String get bookingCancelYes => 'Yes, cancel';

  @override
  String get bookingCancelNo => 'No';

  @override
  String get bookingCancelButton => 'Cancel request';

  @override
  String get bookingCancelError => 'Could not cancel. Please try again.';

  @override
  String get bookingConfirmDoneTitle => 'Confirm completion?';

  @override
  String get bookingConfirmDoneContent =>
      'By confirming, the service will be marked as completed. You can then leave a review.';

  @override
  String get bookingConfirmDoneButton => 'Confirm service completion';

  @override
  String get bookingDoneSuccess => 'Service completed!';

  @override
  String get bookingDoneError => 'Error while confirming.';

  @override
  String get bookingRequestTitle => 'Request this service';

  @override
  String get bookingStep1Title => 'Describe your need';

  @override
  String get bookingStep1Subtitle =>
      'Give details to help the provider understand your request.';

  @override
  String get bookingStep1Hint => 'E.g. I need a full cleaning of my apartment…';

  @override
  String get bookingStep2Title => 'Preferred date and time';

  @override
  String get bookingStep2Subtitle => 'Select a time slot (optional).';

  @override
  String get bookingStep2PickDate => 'Choose a date';

  @override
  String get bookingStep2PickTime => 'Choose a time';

  @override
  String get bookingStep3Title => 'Service address';

  @override
  String get bookingStep3Subtitle =>
      'Where should the provider intervene? (optional)';

  @override
  String get bookingStep3Hint => 'E.g. 12 rue de la Paix, Paris 75001';

  @override
  String get bookingBack => 'Back';

  @override
  String get bookingContinue => 'Continue';

  @override
  String get bookingSend => 'Send request';

  @override
  String get bookingSentSuccess => 'Request sent successfully ✓';

  @override
  String get bookingConflictBusy =>
      'The provider already has an appointment at this time.';

  @override
  String get bookingConflictUnavailableDay =>
      'The provider is unavailable on this day.';

  @override
  String get bookingConflictUnavailableSlot =>
      'The provider is unavailable at this time slot.';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get chatEmpty => 'No active chats';

  @override
  String get chatEmptySubtitle =>
      'Conversations start after\na booking is accepted.';

  @override
  String get chatActiveEmpty => 'No active conversations';

  @override
  String get chatDoneEmpty => 'No completed conversations';

  @override
  String get chatStartConversation => 'Start the conversation';

  @override
  String get chatYou => 'You: ';

  @override
  String get chatLoadError => 'Could not load messages.';

  @override
  String get chatConversation => 'Conversation';

  @override
  String get chatTyping => 'Type a message…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatErrorSend => 'Could not send.';

  @override
  String get chatTabActive => 'In progress';

  @override
  String get chatTabDone => 'Completed';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsReadAll => 'Mark all read';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get notificationsEmptySubtitle =>
      'You will be notified here\nwhen something happens.';

  @override
  String get notificationsError => 'Could not load notifications.';

  @override
  String get notificationTimeNow => 'Just now';

  @override
  String notificationTimeMinutes(int count) {
    return '$count min ago';
  }

  @override
  String notificationTimeHours(int count) {
    return '$count h ago';
  }

  @override
  String get notificationTimeYesterday => 'Yesterday';

  @override
  String notificationTimeDays(int count) {
    return '$count days ago';
  }

  @override
  String get inboxTitle => 'Missions';

  @override
  String get inboxCalendarTooltip => 'My calendar';

  @override
  String get inboxTabRequests => 'Requests';

  @override
  String get inboxTabActive => 'In progress';

  @override
  String get inboxEmptyRequests => 'No pending requests';

  @override
  String get inboxEmptyRequestsSubtitle =>
      'New client requests will appear here.';

  @override
  String get inboxEmptyActive => 'No active missions';

  @override
  String get inboxEmptyActiveSubtitle => 'Accepted missions will appear here.';

  @override
  String get inboxLoadError => 'Could not load data.';

  @override
  String get inboxOpenChat => 'Open chat';

  @override
  String get reviewTitle => 'Leave a review';

  @override
  String get reviewEvaluateProvider => 'Rate the provider';

  @override
  String get reviewEvaluateClient => 'Rate the client';

  @override
  String get reviewHelp => 'Your review helps the community build trust.';

  @override
  String get reviewRating => 'Rating';

  @override
  String get reviewComment => 'Comment (optional)';

  @override
  String get reviewCommentHint => 'Share your experience…';

  @override
  String get reviewSubmit => 'Submit review';

  @override
  String get reviewError => 'Could not submit review.';

  @override
  String get reviewBookingNotFound => 'Booking not found.';

  @override
  String get reviewOnlyAfterDone =>
      'Review available only after service completion.';

  @override
  String get reportTitle => 'Report';

  @override
  String get reportQuestion => 'Why are you reporting?';

  @override
  String get reportSubtitle =>
      'Your report is anonymous and will be reviewed by our team.';

  @override
  String get reportSubmit => 'Submit report';

  @override
  String get reportSuccess => 'Report submitted. Thank you.';

  @override
  String get reportError => 'Could not submit report.';

  @override
  String get reportReason1 => 'Inappropriate behaviour';

  @override
  String get reportReason2 => 'Fake profile or scam';

  @override
  String get reportReason3 => 'Service not performed';

  @override
  String get reportReason4 => 'Offensive content';

  @override
  String get reportReason5 => 'Harassment';

  @override
  String get reportReason6 => 'Other';

  @override
  String get serviceDescription => 'Description';

  @override
  String get serviceProviderLabel => 'Provider';

  @override
  String get serviceViewProfile => 'View profile';

  @override
  String get serviceBook => 'Request this service';

  @override
  String get serviceEditListing => 'Edit this listing';

  @override
  String get serviceNotFound => 'Service not found';

  @override
  String get seeMore => 'See more';

  @override
  String get seeLess => 'See less';

  @override
  String get onboardingTitle => 'Become a provider';

  @override
  String get onboardingHeadline => 'Offer your services';

  @override
  String get onboardingBody =>
      'Create your provider profile in seconds. You can then publish your services and receive requests.';

  @override
  String get onboardingBio => 'Introduction (optional)';

  @override
  String get onboardingBioHint =>
      'E.g. Plumber with 10 years of experience, available in the Paris area…';

  @override
  String get onboardingZone => 'Service area (optional)';

  @override
  String get onboardingZoneHint => 'E.g. Paris and suburbs, Île-de-France…';

  @override
  String get onboardingActivate => 'Activate my provider profile';

  @override
  String get onboardingError => 'Could not activate profile. Please try again.';

  @override
  String get serviceFormCreateTitle => 'New service';

  @override
  String get serviceFormEditTitle => 'Edit service';

  @override
  String get serviceFormTitleLabel => 'Service title';

  @override
  String get serviceFormTitleHint => 'E.g. Full apartment cleaning';

  @override
  String get serviceFormTitleRequired => 'Title required';

  @override
  String get serviceFormCategory => 'Category';

  @override
  String get serviceFormDescription => 'Description (optional)';

  @override
  String get serviceFormDescriptionHint => 'Describe what you offer…';

  @override
  String get serviceFormPrice => 'Price';

  @override
  String get serviceFormPriceRequired => 'Required';

  @override
  String get serviceFormPriceInvalid => 'Invalid';

  @override
  String get serviceFormZones => 'Service areas *';

  @override
  String get serviceFormZonesRequired => 'Add at least one service area.';

  @override
  String get serviceFormPublish => 'Publish this service';

  @override
  String get serviceFormPublishSubtitle => 'Visible to clients';

  @override
  String get serviceFormSave => 'Save';

  @override
  String get serviceFormCreate => 'Create service';

  @override
  String get serviceFormPhotoError =>
      'Could not upload photo. Please try again.';

  @override
  String get serviceFormSaveError => 'Could not save. Please try again.';

  @override
  String get zoneAddTitle => 'Add area';

  @override
  String get zoneEditTitle => 'Edit area';

  @override
  String get zoneAddressHint => 'City or address';

  @override
  String get zoneSelectError => 'Select an address from suggestions';

  @override
  String get zoneLocateError => 'Could not locate this address.';

  @override
  String get zoneConnectionError => 'Connection required to add an area.';

  @override
  String get zoneRadius => 'Service radius';

  @override
  String get zoneNone => 'No areas added';

  @override
  String get zoneAdd => 'Add an area';

  @override
  String get priceHourly => 'per hour';

  @override
  String get priceFixed => 'flat fee';

  @override
  String get photoAdd => 'Add a photo (optional)';

  @override
  String zoneRadiusLabel(String radius) {
    return 'Radius: $radius';
  }

  @override
  String get zoneValidate => 'Validate';

  @override
  String get zoneModify => 'Modify';

  @override
  String get phoneAuthTitle => 'Phone number';

  @override
  String get phoneAuthSubtitle =>
      'Enter your number to receive a verification code via SMS.';

  @override
  String get phoneAuthButton => 'Send code';

  @override
  String get phoneAuthWithNumber => 'Continue with a phone number';

  @override
  String get phoneAuthOrWith => 'or';

  @override
  String get phoneAuthWebUnsupported =>
      'Phone sign-in is only available on the mobile app.';

  @override
  String get otpTitle => 'Verification code';

  @override
  String otpSubtitle(String phone) {
    return 'A code was sent to $phone';
  }

  @override
  String get otpHint => '6-digit code';

  @override
  String get otpVerify => 'Verify';

  @override
  String otpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpResend => 'Resend code';

  @override
  String get otpError => 'Incorrect code. Please try again.';

  @override
  String get otpPhoneError => 'Could not send code. Check the number.';

  @override
  String get phoneNameTitle => 'Your name';

  @override
  String get phoneNameSubtitle => 'This name will be visible to other users.';

  @override
  String get phoneNameHint => 'First and last name';

  @override
  String get phoneNameButton => 'Continue';

  @override
  String get phoneNameError => 'Could not save. Please try again.';

  @override
  String get langSystem => 'System (device)';

  @override
  String get langFrench => 'French';

  @override
  String get langEnglish => 'English';

  @override
  String get switchModeTitle => 'Choose a mode';

  @override
  String get switchModeHeading => 'Your active mode';

  @override
  String get switchModeDescription =>
      'Switch between client and provider mode at any time.';

  @override
  String get switchModeThemeDescription => 'Choose the app theme.';

  @override
  String get themeSystemSubtitle => 'Follows your device preferences';

  @override
  String get themeLightSubtitle => 'Always in light mode';

  @override
  String get themeDarkSubtitle => 'Always in dark mode';

  @override
  String get chatRecording => 'Recording in progress…';

  @override
  String get chatSubtitle => 'Coordinate the service details here.';

  @override
  String get chatMicError => 'Could not activate microphone.';

  @override
  String get chatVoiceError => 'Could not send voice message.';

  @override
  String get chatFileError => 'Could not send file.';

  @override
  String get chatAddCaption => 'Add a message…';

  @override
  String get chatGallery => 'Gallery';

  @override
  String get reviewsLabel => 'Reviews';

  @override
  String get servicesOffered => 'Services offered';

  @override
  String get bookingAddressLabel => 'Service address';
}
