import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/application/onboarding/onboarding_provider.dart';

/// Background / terminated FCM handler. The notification itself is displayed by
/// the OS (our pushes carry a `notification` block), so this is a no-op beyond
/// ensuring Firebase is initialised in the background isolate. Registering it
/// is required for FCM to wake the app without warnings and enables future
/// data-only handling.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  // Catch all uncaught async errors. runZonedGuarded is intentionally
  // fire-and-forget; errors are forwarded to the second callback.
  // ignore: unawaited_futures
  runZonedGuarded(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: binding);

      final results = await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        initializeDateFormatting('fr_FR'),
        readOnboardingDone(),
      ]);

      // Register the background message handler once Firebase is ready.
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final onboardingDone = results[2] as bool;

      final crashlytics = FirebaseCrashlytics.instance;

      // Flutter framework errors (widget build failures, layout overflows, etc.)
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };

      // Platform-level errors (native crashes, unhandled platform exceptions)
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true; // prevents app termination
      };

      FlutterNativeSplash.remove();
      runApp(
        ProviderScope(
          overrides: [
            onboardingDoneProvider.overrideWith((_) => onboardingDone),
          ],
          child: const OutalmaServiceApp(),
        ),
      );
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
