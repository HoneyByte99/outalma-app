import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/pricing_config.dart';
import '../auth/auth_providers.dart';

/// Reads the `config/pricing` grid once per session and exposes it to the
/// service form. The same document backs the Firestore server rule, so the
/// range the form displays and the range the server enforces cannot drift
/// apart (archi section 5).
///
/// A missing or incoherent document surfaces as an error the form turns into a
/// visible state with a retry action (spec AC-15, scenario SC-12): no hard-coded
/// fallback range, which would reintroduce the double source this design
/// removes. Invalidate this provider to retry the read.
final pricingConfigProvider = FutureProvider<PricingConfig>((ref) async {
  final db = ref.watch(firestoreProvider);
  final snap = await db.collection('config').doc('pricing').get();
  final data = snap.data();
  if (data == null) {
    throw StateError('config/pricing is missing');
  }
  final config = PricingConfig.fromMap(data);
  if (!config.isCoherent) {
    throw StateError('config/pricing is incoherent');
  }
  return config;
});
