import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/active_mode.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_state.dart';

/// Tracks the active mode for the current session.
/// Initialised from the authenticated user's persisted activeMode.
final activeModeProvider = StateProvider<ActiveMode>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is AuthAuthenticated) return authState.user.activeMode;
  return ActiveMode.client;
});
