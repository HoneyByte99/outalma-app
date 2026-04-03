import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Wraps [child] and shows a slim offline banner at the top when the device
/// has no network connectivity. Dismisses automatically when connection returns.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late StreamSubscription<List<ConnectivityResult>> _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    // Check current status immediately
    Connectivity().checkConnectivity().then(_handleResults);
    // Listen for changes
    _sub = Connectivity()
        .onConnectivityChanged
        .listen(_handleResults);
  }

  void _handleResults(List<ConnectivityResult> results) {
    final nowOffline = results.every((r) => r == ConnectivityResult.none);
    if (nowOffline != _offline) {
      setState(() => _offline = nowOffline);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _offline
              ? _OfflineBanner()
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 6,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'Pas de connexion internet',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
