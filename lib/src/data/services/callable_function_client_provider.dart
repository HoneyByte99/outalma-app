import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'callable_function_client.dart';

/// Server-authoritative Cloud Function client, injected via provider so tests
/// can substitute a fake and verify calls without hitting the network.
final callableFunctionClientProvider = Provider<CallableFunctionClient>(
  (ref) => const CallableFunctionClient(),
);
