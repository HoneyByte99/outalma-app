import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../application/locale/locale_provider.dart';
import '../application/notification/notification_service.dart';
import '../application/theme/theme_provider.dart';
import 'app_theme.dart';
import 'connectivity_banner.dart';
import 'router.dart';

class OutalmaServiceApp extends ConsumerStatefulWidget {
  const OutalmaServiceApp({super.key});

  @override
  ConsumerState<OutalmaServiceApp> createState() => _OutalmaServiceAppState();
}

class _OutalmaServiceAppState extends ConsumerState<OutalmaServiceApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<RemoteMessage>? _messageSub;

  @override
  void initState() {
    super.initState();
    _messageSub = NotificationService.listenForeground(_messengerKey);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Outalma Service',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) =>
          ConnectivityBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
