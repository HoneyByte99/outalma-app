import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';

Future<void> main() async {
  // Catch all uncaught async errors.
  runZonedGuarded(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);

    await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      initializeDateFormatting('fr_FR'),
    ]);

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
      const ProviderScope(
        child: OutalmaServiceApp(),
      ),
    );
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
