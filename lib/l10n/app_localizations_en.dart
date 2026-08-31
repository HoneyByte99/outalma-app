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
  String get signUpPasswordConfirmHint => 'Confirm password';

  @override
  String get signUpShowPassword => 'Show password';

  @override
  String get signUpHidePassword => 'Hide password';

  @override
  String get signUpErrorPasswordMismatch => 'Passwords do not match.';

  @override
  String get emailVerifyBanner => 'Verify your email address.';

  @override
  String get emailVerifyResend => 'Resend';

  @override
  String get emailVerifySent => 'Verification email sent.';

  @override
  String get emailVerifyError => 'Could not send. Try again later.';

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
  String get authErrorInvalidOtp => 'Invalid or expired code.';

  @override
  String get authErrorOtpSend => 'Could not send the code. Please retry.';

  @override
  String get phoneOtpSendCode => 'Get code';

  @override
  String get phoneOtpVerify => 'Verify';

  @override
  String get phoneOtpHint => '6-digit code';

  @override
  String get phoneOtpResend => 'Resend code';

  @override
  String get phoneOtpEditNumber => 'Edit number';

  @override
  String phoneOtpSentTo(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get phoneOtpNoAccount =>
      'No account found for this number. Please sign up first.';

  @override
  String get signUpVerificationNotice =>
      'After signing up, a verification email will be sent. Tap the link in your inbox to confirm your address.';

  @override
  String get signUpVerificationResent => 'Verification email re-sent.';

  @override
  String homeGreeting(String name) {
    return 'Hello $name';
  }

  @override
  String get homeGreetingNoName => 'Hello';

  @override
  String get homeSearchPrompt => 'What are you looking for?';

  @override
  String get homeSearchHint => 'Search for a service…';

  @override
  String homeSearchEmpty(String query) {
    return 'No results for « $query »';
  }

  @override
  String get categoryAll => 'All';

  @override
  String get categoryMenage => 'Cleaning';

  @override
  String get categoryPlomberie => 'Plumbing';

  @override
  String get categoryJardinage => 'Gardening';

  @override
  String get categoryElectricite => 'Electricity';

  @override
  String get categoryPeinture => 'Painting';

  @override
  String get categoryBricolage => 'Handyman';

  @override
  String get categoryGardeEnfants => 'Childcare';

  @override
  String get categoryCuisine => 'Cooking';

  @override
  String get categoryRepassage => 'Ironing';

  @override
  String get servicesEmpty => 'No services available\nright now';

  @override
  String homeCategoryEmpty(String category) {
    return 'No « $category » listings\nyet';
  }

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get modeClient => 'Client';

  @override
  String get modeProvider => 'Provider';

  @override
  String get modeClientActivated => 'Client mode activated';

  @override
  String get modeProviderActivated => 'Provider mode activated';

  @override
  String get modeBadgeTapToSwitch => 'Tap to switch mode';

  @override
  String get verifiedBadgeLabel => 'Verified';

  @override
  String get serviceZonesLabel => 'Service areas';

  @override
  String get serviceViewOnMap => 'View on map';

  @override
  String get reportDetailsLabel => 'Details (optional)';

  @override
  String get reportDetailsHint =>
      'Add information that will help our moderation team…';

  @override
  String get dashboardStatsUpcomingWeek => 'Upcoming this week';

  @override
  String get dashboardStatsThisMonth => 'Bookings this month';

  @override
  String get dashboardStatsAcceptanceRate => 'Acceptance rate';

  @override
  String get locationTitle => 'Location';

  @override
  String get locationAllAreas => 'All of Senegal';

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
  String get profileErrorUpload =>
      'Could not upload the photo. Please try again.';

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
  String get fieldPhone => 'Phone number';

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
  String get reviewsTitle => 'Reviews';

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
  String get dashboardCompleteProfileTitle => 'Complete your profile';

  @override
  String get dashboardCompleteProfileBody =>
      'Add your bio and service area to build client trust.';

  @override
  String get hubFallbackName => 'My profile';

  @override
  String get hubEditProfile => 'Edit profile';

  @override
  String get hubAvailable => 'Available';

  @override
  String get hubPaused => 'Paused';

  @override
  String get hubAvailableSub => 'Clients can book you';

  @override
  String get hubPausedSub => 'Your listings are hidden';

  @override
  String get hubNoServicesHint => 'Publish a listing to become available';

  @override
  String get hubSemanticsOn => 'Available. Tap to pause.';

  @override
  String get hubSemanticsOff => 'Paused. Tap to become available.';

  @override
  String get hubResumed => 'You\'re available again';

  @override
  String get hubToggleError => 'Couldn\'t update your availability. Try again.';

  @override
  String get hubPauseTitle => 'Pause your activity?';

  @override
  String hubPauseBody(int count) {
    return 'Your $count listings will be hidden from clients. Resume whenever you want.';
  }

  @override
  String get hubPauseBodyNoCount =>
      'Your listings will be hidden from clients. Resume whenever you want.';

  @override
  String get hubPauseCta => 'Pause';

  @override
  String get serviceMaskedPaused => 'Paused';

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
  String get serviceStatusPending => 'Pending review';

  @override
  String get serviceStatusRejected => 'Rejected';

  @override
  String get serviceActive => 'Online';

  @override
  String get serviceInactive => 'Offline';

  @override
  String serviceToggleActivate(String title) {
    return 'Bring $title online';
  }

  @override
  String serviceToggleDeactivate(String title) {
    return 'Take $title offline';
  }

  @override
  String get serviceDelete => 'Delete';

  @override
  String get serviceDeleteTitle => 'Delete this service?';

  @override
  String get serviceDeleteBody => 'This listing will be permanently removed.';

  @override
  String get serviceDeleted => 'Service deleted';

  @override
  String get ratingNew => 'New';

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
  String bookingDistanceEstimate(String km) {
    return 'Estimated distance: ~$km km';
  }

  @override
  String get bookingOpenDirections => 'Directions';

  @override
  String get bookingContact => 'Contact';

  @override
  String get bookingPhoneNotShared => 'Phone number not yet shared';

  @override
  String get bookingCallAction => 'Call';

  @override
  String get bookingWhatsappAction => 'WhatsApp';

  @override
  String get bookingPhoneCopied => 'Number copied';

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
  String get bookingReviewSent => 'Review sent, thank you!';

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
  String get bookingViewProviderProfile => 'View profile';

  @override
  String get bookingViewClientReviews => 'View reviews';

  @override
  String get providerProfileUnavailable => 'Profile unavailable';

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
  String get bookingCancelReasonHint => 'Reason (optional)';

  @override
  String get bookingCancelError => 'Could not cancel. Please try again.';

  @override
  String get bookingCancelSuccess => 'Request cancelled.';

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
  String bookingDefaultMessage(String serviceTitle) {
    return 'Hello, I am interested in your service « $serviceTitle ». Could you contact me to arrange an appointment? Thank you!';
  }

  @override
  String get bookingStep2Title => 'Preferred date and time';

  @override
  String get bookingStep2Subtitle => 'Select a time slot (optional).';

  @override
  String get bookingStep2PickDate => 'Choose a date';

  @override
  String get bookingStep2PickTime => 'Choose a time';

  @override
  String get bookingPickSlot => 'Choose an available time';

  @override
  String get bookingNoSlots => 'No free slots that day. Try another date.';

  @override
  String get bookingProviderUnavailable =>
      'This provider is currently unavailable.';

  @override
  String get bookingAddressNotInSenegal =>
      'The service must take place in Senegal. Please choose an address in Senegal.';

  @override
  String get marketplaceDisclaimer =>
      'Outalma only connects clients and independent providers. Any agreement and payment is made directly between you, outside the app and at your own risk. Always check who you are dealing with.';

  @override
  String get bookingStep3Title => 'Service address';

  @override
  String get bookingStep3Subtitle =>
      'Where should the provider intervene? (optional)';

  @override
  String get bookingStep3Hint => 'E.g. Rue 10, Point E, Dakar';

  @override
  String get bookingBack => 'Back';

  @override
  String get bookingContinue => 'Continue';

  @override
  String get bookingSend => 'Send request';

  @override
  String get bookingVoiceMessageLabel => 'Voice message';

  @override
  String get chatPhotoMessageLabel => 'Photo';

  @override
  String get bookingRecordPrompt => 'Tap to record';

  @override
  String get bookingDeleteRecording => 'Delete recording';

  @override
  String get bookingVoicePermissionDenied =>
      'Microphone permission denied. Check your settings.';

  @override
  String get bookingVoiceUploadFailed =>
      'Voice message upload failed. Please try again.';

  @override
  String get bookingVoicePlayLabel => 'Play';

  @override
  String get bookingVoiceStopLabel => 'Stop';

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
  String notificationsUnreadCount(int count) {
    return '$count unread';
  }

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
  String get calendarFullDay => 'All day';

  @override
  String get calendarLegendBooking => 'Booking';

  @override
  String get calendarLegendBlocked => 'Unavailable';

  @override
  String get calendarServiceFallback => 'Service';

  @override
  String get calendarDeleteSlotTitle => 'Remove this block?';

  @override
  String get calendarDeleteSlotBody => 'This time will become bookable again.';

  @override
  String get calendarDeleteSlotConfirm => 'Remove';

  @override
  String get inboxTabRequests => 'Requests';

  @override
  String get inboxTabActive => 'In progress';

  @override
  String get inboxTabCompleted => 'Completed';

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
  String get inboxEmptyCompleted => 'No completed missions';

  @override
  String get inboxEmptyCompletedSubtitle =>
      'Finished, declined or cancelled missions appear here.';

  @override
  String get inboxLoadError => 'Could not load data.';

  @override
  String get inboxOpenChat => 'Open chat';

  @override
  String get inboxMoreDetails => 'More details';

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
  String servicePhotoCounter(int current, int total) {
    return 'Photo $current of $total';
  }

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
  String get onboardingEditTitle => 'Edit my profile';

  @override
  String get onboardingHeadline => 'Offer your services';

  @override
  String get onboardingEditHeadline => 'Your provider profile';

  @override
  String get onboardingBody =>
      'Create your provider profile in seconds. You can then publish your services and receive requests.';

  @override
  String get onboardingEditBody =>
      'Update your introduction and working hours.';

  @override
  String get onboardingBio => 'Introduction (optional)';

  @override
  String get onboardingBioHint =>
      'E.g. Plumber with 10 years of experience, available in Dakar…';

  @override
  String get onboardingActivate => 'Activate my provider profile';

  @override
  String get onboardingSave => 'Save';

  @override
  String get onboardingHours => 'Working hours';

  @override
  String get onboardingHoursHint =>
      'Clients can only book time slots within this window.';

  @override
  String get onboardingHoursStart => 'From';

  @override
  String get onboardingHoursEnd => 'To';

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
  String get serviceFormPhotoAdd => 'Add a photo (optional)';

  @override
  String serviceFormPhotoMax(int max) {
    return 'You can add up to $max photos.';
  }

  @override
  String serviceFormPhotoCount(int count, int max) {
    return '$count of $max photos';
  }

  @override
  String get serviceFormSaveError => 'Could not save. Please try again.';

  @override
  String get serviceFormPublishNeedsProfile =>
      'Complete your provider profile before publishing. You can save it as a draft for now.';

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
  String get priceDaily => 'per day';

  @override
  String get priceMonthly => 'per month';

  @override
  String get priceUnitHourly => '/h';

  @override
  String get priceUnitDaily => '/day';

  @override
  String get priceUnitMonthly => '/mo';

  @override
  String get serviceFormBillingMode => 'Billing mode';

  @override
  String get serviceFormExtraTasks => 'Additional tasks covered';

  @override
  String get serviceFormExtraTasksSubtitle =>
      'Up to three tasks beyond the main one';

  @override
  String get serviceFormExtraTasksMax => 'Three additional tasks at most.';

  @override
  String serviceFormPriceRange(String min, String max) {
    return 'Allowed range: $min to $max F CFA';
  }

  @override
  String serviceFormPriceOutOfRange(String min, String max) {
    return 'The price must be between $min and $max F CFA.';
  }

  @override
  String get serviceFormPriceMonthlyMin => 'Monthly minimum';

  @override
  String get serviceFormPriceMonthlyMax => 'Monthly maximum';

  @override
  String get serviceFormMonthlyMaxBelowMin =>
      'The maximum must be greater than or equal to the minimum.';

  @override
  String get serviceFormPricingUnavailable =>
      'The pricing grid is unavailable. Retry.';

  @override
  String get photoAdd => 'Add a photo (optional)';

  @override
  String zoneRadiusLabel(String radius) {
    return 'Radius: $radius';
  }

  @override
  String get zoneValidate => 'Confirm';

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
  String get chatMicPermission =>
      'Allow microphone access to send a voice message.';

  @override
  String get notifDisabledBanner =>
      'Turn on notifications so you don\'t miss anything.';

  @override
  String get notifEnableAction => 'Enable';

  @override
  String get micEnableAction => 'Settings';

  @override
  String get bookingVoiceMessage => 'Voice message';

  @override
  String get chatMissionEndedBanner =>
      'Mission completed. Conversation is read-only.';

  @override
  String get chatVoiceError => 'Could not send voice message.';

  @override
  String get chatVoiceSending => 'Sending voice message…';

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

  @override
  String get introSlide1Title => 'Welcome to Outalma';

  @override
  String get introSlide1Body =>
      'Find the best service providers near you, quickly and with confidence.';

  @override
  String get introSlide2Title => 'Book in seconds';

  @override
  String get introSlide2Body =>
      'Pick a service, choose a time slot, and confirm in just a few taps.';

  @override
  String get introSlide3Title => 'Track in real time';

  @override
  String get introSlide3Body =>
      'Stay informed at every step: confirmation, travel, and service completion.';

  @override
  String get introSlide4Title => 'Ready to start';

  @override
  String get introSlide4Body =>
      'By continuing, you accept our terms of use and privacy policy.';

  @override
  String get introTermsAccept => 'I accept the terms of use';

  @override
  String get introNext => 'Next';

  @override
  String get introGetStarted => 'Get started';

  @override
  String get introTermsRequired => 'Please accept the terms to continue.';

  @override
  String get legalReadTerms => 'Read the terms of use';

  @override
  String get legalReadPrivacy => 'Read the privacy policy';

  @override
  String get legalTermsTitle => 'Terms of use';

  @override
  String get legalPrivacyTitle => 'Privacy policy';

  @override
  String get introSkip => 'Skip';

  @override
  String get authTabEmail => 'Email';

  @override
  String get authTabPhone => 'Phone';

  @override
  String get locationMyPosition => 'My location';

  @override
  String get chatUnsupportedFormat => 'Unsupported format';

  @override
  String get chatHoldToRecord => 'Hold to record';

  @override
  String get chatSlideToCancel => 'Slide to cancel';

  @override
  String get chatReleaseToCancel => 'Release to cancel';

  @override
  String get chatTakePhoto => 'Photo';

  @override
  String get legalSection => 'Legal';

  @override
  String get accountExportData => 'Export my data';

  @override
  String get accountRequestExport => 'Request a data export';

  @override
  String get exportRequestTitle => 'Request a data export';

  @override
  String get exportRequestBody =>
      'We\'ll prepare your data and email it to you. Confirm the address below.';

  @override
  String get exportRequestEmail => 'Email address';

  @override
  String get exportRequestSend => 'Send request';

  @override
  String get exportRequestSent =>
      'Request sent. You\'ll receive your data by email.';

  @override
  String get accountDeleteTitle => 'Delete my account';

  @override
  String get accountDeleteWarning =>
      'This action is permanent and irreversible. Your profile, services and personal information will be deleted.';

  @override
  String get accountDeleteConfirm => 'Delete permanently';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get blockUser => 'Block this user';

  @override
  String get unblockUser => 'Unblock this user';

  @override
  String get blockUserConfirm =>
      'Block this user? You will no longer see their messages and they can no longer contact you.';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get userUnblocked => 'User unblocked';

  @override
  String get chatBlockedBanner =>
      'You have blocked this user. Unblock to chat again.';

  @override
  String get blockedUsersTitle => 'Blocked accounts';

  @override
  String get blockedUsersEmpty => 'You haven\'t blocked anyone.';

  @override
  String get blockedUsersEmptyHint =>
      'You can block someone from a conversation.';

  @override
  String get blockedUserUnknown => 'User';

  @override
  String get bookingModeText => 'Text';

  @override
  String get bookingModeVoice => 'Voice';

  @override
  String reviewStarLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count star$_temp0';
  }

  @override
  String get chatReply => 'Reply';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatReportMessage => 'Report this message';

  @override
  String get chatDeletedMessage => 'Message deleted';

  @override
  String get chatReplyingTo => 'Replying to';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatEditing => 'Edit message';

  @override
  String get chatEdited => 'edited';

  @override
  String get chatDateToday => 'Today';

  @override
  String get chatDateYesterday => 'Yesterday';

  @override
  String get chatLoadOlder => 'Show older messages';

  @override
  String get zoneSheetEditTitle => 'Edit area';

  @override
  String get zoneSheetAddTitle => 'Add an area';

  @override
  String get zoneCityOrAddress => 'City or address';

  @override
  String get zoneEdit => 'Edit';

  @override
  String get serviceFormPhotoRemove => 'Remove photo';

  @override
  String get serviceFormPhotoRemoved => 'Photo removed';

  @override
  String get serviceFormPhotoUndo => 'Undo';

  @override
  String get trustVerifiedLabel => 'Verified profile';

  @override
  String get trustPendingLabel => 'Verification under way';

  @override
  String get trustUnverifiedLabel => 'Identity not verified';

  @override
  String get identityCaptureRectoTitle => 'Front of the ID';

  @override
  String get identityCaptureVersoTitle => 'Back of the ID';

  @override
  String get identityCaptureRectoInstruction =>
      'Place the front of your card inside the frame, flat and readable.';

  @override
  String get identityCaptureVersoInstruction =>
      'Place the back of your card inside the frame, flat and readable.';

  @override
  String get identityCaptureButton => 'Take the photo';

  @override
  String get identityCaptureRetake => 'Retake';

  @override
  String get identityCaptureUse => 'Use this photo';

  @override
  String get identityCaptureBlurry =>
      'Photo too blurry. Steady the device and move closer to the document.';

  @override
  String get identityCaptureNoText =>
      'No readable text detected. Line up your ID card inside the frame.';

  @override
  String get identityCaptureSendAnyway => 'Send anyway, a human will review it';

  @override
  String get identityCaptureAutoHint => 'The photo is taken automatically.';

  @override
  String get identityCaptureSearching => 'Place the card inside the frame.';

  @override
  String get identityCaptureFlipCard => 'Turn the card over.';

  @override
  String get identityCaptureMoving => 'Hold the card still.';

  @override
  String get identityCaptureHoldStill => 'Stay still, the photo is coming.';

  @override
  String get identityCaptureRefused => 'Photo not kept. Frame the card again.';

  @override
  String get identityCaptureManualHint =>
      'You can also take the photo yourself.';

  @override
  String identityStepProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get identityPermissionDeniedTitle => 'Camera not allowed';

  @override
  String get identityPermissionDeniedBody =>
      'Outalma needs the camera to photograph your ID. Allow camera access to continue.';

  @override
  String get identityOpenSettings => 'Open settings';

  @override
  String get identityCameraUnavailableTitle => 'Camera unavailable';

  @override
  String get identityCameraUnavailableBody =>
      'No usable camera on this device. The verification journey runs on a phone.';

  @override
  String get identityRetry => 'Try again';

  @override
  String get identitySelfieTitle => 'Verification selfie';

  @override
  String get identityLivenessWaitingFace => 'Place your face inside the frame.';

  @override
  String get identityLivenessMultipleFaces => 'Only one face must be visible.';

  @override
  String get identityLivenessTurnHead => 'Slowly turn your head to the side.';

  @override
  String get identityLivenessReturnToFront => 'Now face the lens again.';

  @override
  String get identityLivenessReady => 'Hold still.';

  @override
  String get identityLivenessExpired =>
      'The challenge timed out. Let\'s start over.';

  @override
  String get identityLivenessRetryDifferent =>
      'Let\'s retry: slowly turn your head to the side, then face the lens again.';

  @override
  String get identityLivenessFaceGuideLabel =>
      'Demonstration of the head movement to perform.';

  @override
  String get identityLivenessSupportTitle => 'Need a hand?';

  @override
  String get identityLivenessSupportBody =>
      'The challenge did not complete after several tries. Contact support to finish your verification.';

  @override
  String get identityContactSupport => 'Contact support';

  @override
  String get identityRecapTitle => 'Check your photos';

  @override
  String get identityRecapBody =>
      'These three images will be sent for verification.';

  @override
  String get identityRecapConfirm => 'Send for verification';

  @override
  String get identityDepositUploading => 'Sending your photos…';

  @override
  String get identityDepositSubmitting => 'Finalising…';

  @override
  String get identityDepositSuccessTitle => 'Photos sent';

  @override
  String get identityDepositSuccessBody =>
      'Your file is being reviewed. You will be notified of the decision.';

  @override
  String get identityDepositAlreadySubmitted =>
      'This submission was already recorded.';

  @override
  String get identityErrorBatchInvalid =>
      'The upload did not complete. Retake your photos.';

  @override
  String get identityErrorObjectsMissing =>
      'Your photos did not arrive. Retake the capture.';

  @override
  String get identityErrorBatchStale =>
      'Your photos waited too long. Retake the capture.';

  @override
  String get identityErrorAccountMissing =>
      'Session expired. Please sign in again.';

  @override
  String get identityErrorPendingExists => 'A file is already under review.';

  @override
  String get identityErrorAlreadyVerified =>
      'Your identity is already verified.';

  @override
  String get identityErrorRateLimited =>
      'Too many recent submissions. Try again later.';

  @override
  String identityErrorRateLimitedWithDelay(String duration) {
    return 'Too many recent submissions. Try again in $duration.';
  }

  @override
  String get identityErrorStorageDenied =>
      'The upload was refused. Retake your photos.';

  @override
  String get identityErrorNetwork => 'Connection interrupted. You can resume.';

  @override
  String get identityErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String identityDurationHours(int hours) {
    return '$hours h';
  }

  @override
  String identityDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get identityDone => 'Done';

  @override
  String get identityGuideTitle => 'Verify your identity';

  @override
  String get identityGuideStepRecto => 'Front';

  @override
  String get identityGuideStepVerso => 'Back';

  @override
  String get identityGuideStepSelfie => 'Selfie';

  @override
  String get identityGuideWhy =>
      'A verified profile earns client trust. The badge shows you are who you say you are.';

  @override
  String get identityGuideNext =>
      'A member of our team reviews your file within 48 hours. You can keep offering your services in the meantime.';

  @override
  String get identityGuideHave =>
      'Have your CEDEAO ID card ready, in a well-lit spot. Allow about two minutes. Your photos are not kept on the phone.';

  @override
  String get identityGuideStart => 'Start';

  @override
  String get identityGuideConsentHint => 'Tick the box to continue';

  @override
  String get identityGuideMention1 =>
      'We collect a photo of the front and back of your ID card, and a selfie.';

  @override
  String get identityGuideMention2 =>
      'They are used only to check that you are the person offering services on Outalma.';

  @override
  String get identityGuideMention3 =>
      'Only authorised members of the Outalma team can view them. No client and no other provider has access.';

  @override
  String get identityGuideMention4 =>
      'They are kept until you delete your account.';

  @override
  String get identityGuideMention5 =>
      'You can delete your account at any time from your settings.';

  @override
  String get identityGuideMention6 =>
      'We reply within 48 hours. You can keep offering your services in the meantime.';

  @override
  String get identityConsentCheckbox =>
      'I have read the above and I agree to send my ID document and my selfie to Outalma for verification.';

  @override
  String get identityConsentTermsLink => 'Read the terms of use';

  @override
  String get identityStatusTitle => 'Identity verification';

  @override
  String get identityStatusNoneBody =>
      'Get the « Verified profile » badge so clients can trust you before booking.';

  @override
  String get identityStatusStartCta => 'Verify my identity';

  @override
  String get identityStatusRestartCta => 'Start again';

  @override
  String identityStatusPendingBody(String date) {
    return 'Submitted on $date, reply within 48 hours. You will be notified of the decision.';
  }

  @override
  String get identityStatusPendingBodyNoDate =>
      'Your file is under review, reply within 48 hours. You will be notified of the decision.';

  @override
  String identityStatusVerifiedBody(String date) {
    return 'Verified since $date.';
  }

  @override
  String get identityStatusVerifiedBodyNoDate => 'Your profile is verified.';

  @override
  String get identityStatusRejectedTitle => 'Verification refused';

  @override
  String get identityStatusRevokedTitle => 'Verification withdrawn';

  @override
  String get identityStatusPriorityNote =>
      'Your next file will be handled as a priority.';

  @override
  String get identityStatusNoReason =>
      'No reason was provided. You can start again.';

  @override
  String get identityStatusUnavailable => 'State unavailable';

  @override
  String get identityWebOnlyMobile =>
      'Identity verification is done from the Outalma mobile app.';

  @override
  String get identityWebBack => 'Back';

  @override
  String identitySupportReference(String reference) {
    return 'Your reference: $reference';
  }

  @override
  String get hubIdentityVerifiedSub => 'Your profile is verified';

  @override
  String get hubIdentityPendingSub => 'Reply within 48 hours';

  @override
  String get hubIdentityVerifyCta => 'Verify my identity';

  @override
  String get hubIdentityVerifySub => 'Get the « Verified profile » badge';

  @override
  String get hubIdentityActionRequiredSub =>
      'Action required: restart verification';

  @override
  String get profileIdentitySection => 'Identity verification';

  @override
  String get calendarFormatMonth => 'Month';

  @override
  String get calendarFormatTwoWeeks => '2 weeks';

  @override
  String get serviceSeeReviews => 'See reviews';
}
