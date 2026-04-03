import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notification/notification_service.dart';
import '../application/theme/theme_provider.dart';
import 'app_theme.dart';
import 'connectivity_banner.dart';
import 'router.dart';

class OutlamaApp extends ConsumerStatefulWidget {
  const OutlamaApp({super.key});

  @override
  ConsumerState<OutlamaApp> createState() => _OutlamaAppState();
}

class _OutlamaAppState extends ConsumerState<OutlamaApp> {
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

    return MaterialApp.router(
      title: 'Outalma',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ConnectivityBanner(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
