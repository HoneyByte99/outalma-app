import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notification/notification_service.dart';
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

  @override
  void initState() {
    super.initState();
    NotificationService.listenForeground(_messengerKey);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Outalma',
      theme: AppTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ConnectivityBanner(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
