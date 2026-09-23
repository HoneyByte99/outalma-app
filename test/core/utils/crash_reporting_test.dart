import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/core/utils/crash_reporting.dart';

void main() {
  // Crashlytics has no web implementation: touching FirebaseCrashlytics on web
  // throws during startup, and main() then never reaches runApp, so the web
  // app hangs on its splash screen (budget line C1).
  test('crash reporting is off on web', () {
    expect(crashReportingAvailable(isWeb: true), isFalse);
  });

  test('crash reporting stays on for the mobile builds', () {
    expect(crashReportingAvailable(isWeb: false), isTrue);
  });
}
