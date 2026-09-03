import 'package:cloud_functions/cloud_functions.dart';

import '../../application/identity/identity_ports.dart';
import '../../domain/identity/identity_submit_error.dart';
import 'callable_function_client.dart';

/// [IdentitySubmitPort] over the `submitIdentityVerification` callable.
///
/// Goes through [CallableFunctionClient] (plain HTTP), never
/// `FirebaseFunctions.httpsCallable`: that native path carries a Swift
/// concurrency fatalError (`asyncLet_finish_after_task_completion`) on iOS
/// with FirebaseFunctions ~11.15 (the version this app is pinned to), which
/// no Dart try/catch can intercept because it terminates the process. Every
/// other callable in the app was moved off it for the same reason (commit
/// a5a6a6f); this one was added afterwards and missed the migration, which is
/// the identity-submit crash this class exists to close.
///
/// Translates a [FirebaseFunctionsException] into the domain
/// [IdentitySubmitError] via [classifyIdentitySubmitError] and throws it, so the
/// UI branches on a stable kind and never on Firebase types (archi 5.5). Prefers
/// the stable `details.code` (E11) and falls back to the coarse HTTP code the
/// socle emits today. Anything the transport throws that is not a
/// [FirebaseFunctionsException] is folded into `unknown` rather than left to
/// escape: [IdentitySubmitPort] promises to only ever throw an
/// [IdentitySubmitError].
class FunctionsIdentitySubmitService implements IdentitySubmitPort {
  const FunctionsIdentitySubmitService();

  @override
  Future<IdentitySubmitOutcome> submit({required String batchId}) async {
    try {
      final data = await const CallableFunctionClient().call(
        'submitIdentityVerification',
        data: {'batchId': batchId},
      );
      final alreadySubmitted = data['alreadySubmitted'] == true;
      return IdentitySubmitOutcome(alreadySubmitted: alreadySubmitted);
    } on FirebaseFunctionsException catch (e) {
      throw classifyIdentitySubmitError(
        detailsCode: _detailsCode(e.details),
        httpCode: e.code,
        retryAfterMs: _retryAfterMs(e.details),
      );
    } catch (_) {
      throw const IdentitySubmitError(IdentitySubmitErrorKind.unknown);
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
