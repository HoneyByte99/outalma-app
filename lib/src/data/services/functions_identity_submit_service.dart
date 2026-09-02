import 'package:cloud_functions/cloud_functions.dart';

import '../../application/identity/identity_ports.dart';
import '../../domain/identity/identity_submit_error.dart';

/// [IdentitySubmitPort] over the `submitIdentityVerification` callable.
///
/// Translates a [FirebaseFunctionsException] into the domain
/// [IdentitySubmitError] via [classifyIdentitySubmitError] and throws it, so the
/// UI branches on a stable kind and never on Firebase types (archi 5.5). Prefers
/// the stable `details.code` (E11) and falls back to the coarse HTTP code the
/// socle emits today.
class FunctionsIdentitySubmitService implements IdentitySubmitPort {
  const FunctionsIdentitySubmitService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<IdentitySubmitOutcome> submit({required String batchId}) async {
    try {
      final callable = _functions.httpsCallable('submitIdentityVerification');
      final result = await callable.call<Map<String, dynamic>>({
        'batchId': batchId,
      });
      final data = result.data;
      final alreadySubmitted = data['alreadySubmitted'] == true;
      return IdentitySubmitOutcome(alreadySubmitted: alreadySubmitted);
    } on FirebaseFunctionsException catch (e) {
      throw classifyIdentitySubmitError(
        detailsCode: _detailsCode(e.details),
        httpCode: e.code,
        retryAfterMs: _retryAfterMs(e.details),
      );
    }
  }

  /// Reads `details.code` when the server sends the E11 payload; null otherwise.
  static String? _detailsCode(Object? details) {
    if (details is Map && details['code'] is String) {
      return details['code'] as String;
    }
    return null;
  }

  /// Reads `details.retryAfterMs` for the rate-limit refusal (AC-C13b). The
  /// client never estimates it: absent means absent.
  static int? _retryAfterMs(Object? details) {
    if (details is Map) {
      final value = details['retryAfterMs'];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return null;
  }
}
