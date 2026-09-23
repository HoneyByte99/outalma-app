/// Whether Firebase Crashlytics can be used on this platform.
///
/// Crashlytics ships no web implementation. Touching `FirebaseCrashlytics` on
/// web throws during startup, and `main()` then never reaches `runApp`: the
/// web app hangs on its splash screen. A pure function rather than an inline
/// `kIsWeb` so the decision is testable on the VM, where `kIsWeb` is always
/// false.
bool crashReportingAvailable({required bool isWeb}) => !isWeb;
