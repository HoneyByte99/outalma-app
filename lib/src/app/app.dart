import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../application/auth/auth_providers.dart';
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
  StreamSubscription<Uri>? _appLinkSub;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _messageSub = NotificationService.listenForeground(_messengerKey);
    _initAppLinks();
  }

  /// Listens for incoming Universal / App Links — primarily Firebase email
  /// verification links. When one arrives, applies the action code via
  /// AuthNotifier.
  Future<void> _initAppLinks() async {
    // Handle the link that launched the app (cold start case).
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handleIncomingLink(initial);
      }
    } catch (e) {
      debugPrint('[AppLinks] initial link error: $e');
    }
    // Handle subsequent links while the app is running.
    _appLinkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (Object e) => debugPrint('[AppLinks] stream error: $e'),
    );
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    // Only accept links from our two known Firebase Auth hosts on the precise
    // path Firebase uses for the email action handler. Anything else is
    // dropped silently (cf. security review H6).
    const allowedHosts = {
      'outalmaservice-d1e59.firebaseapp.com',
      'outalmaservice-d1e59.web.app',
    };
    if (!allowedHosts.contains(uri.host) ||
        !uri.path.startsWith('/__/auth/')) {
      return;
    }

    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) return;

    if (mode != 'verifyEmail') {
      // Ignore unsupported modes (resetPassword, etc.). Firebase Hosting still
      // renders its default page if no in-app handler claims the link.
      return;
    }

    try {
      final ok = await ref
          .read(authNotifierProvider.notifier)
          .completeEmailVerification(oobCode);
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Adresse email vérifiée ✓'
                  : 'Lien expiré ou déjà utilisé. Renvoyez un nouveau lien.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AppLinks] completeEmailVerification error: $e');
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Vérification de l\'email échouée.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _appLinkSub?.cancel();
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
