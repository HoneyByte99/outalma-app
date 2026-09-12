import 'package:cloud_functions/cloud_functions.dart';

import '../../application/auth/phone_otp_port.dart';
import '../../domain/auth/otp_request_error.dart';
import 'callable_function_client.dart';

/// [PhoneOtpPort] over the `requestPhoneOtp` callable.
///
/// Goes through [CallableFunctionClient] (plain HTTP) like every other callable
/// in this app, never `FirebaseFunctions.httpsCallable`, which carries a Swift
/// concurrency fatalError on iOS with FirebaseFunctions ~11.15.
///
/// Translates the server's refusal into an [OtpRequestError] via
/// [classifyOtpRequestError] and throws it, so the pages branch on a stable
/// kind and never on Firebase types (archi 5.5). Anything the transport throws
/// that is not a [FirebaseFunctionsException] is folded into `unknown` rather
/// than left to escape: [PhoneOtpPort] promises to only ever throw an
/// [OtpRequestError].
class FunctionsPhoneOtpService implements PhoneOtpPort {
  const FunctionsPhoneOtpService();

  @override
  Future<OtpRequestOutcome> request(String phoneE164) async {
    try {
      final data = await const CallableFunctionClient().call(
        'requestPhoneOtp',
        // The channel is forced server-side; sending it would only give a
        // caller the illusion of a choice.
        data: {'phone': phoneE164},
      );
      return OtpRequestOutcome(
        retryAfterMs: _retryAfterMs(data['retryAfterMs']),
      );
    } on FirebaseFunctionsException catch (e) {
      throw classifyOtpRequestError(
        detailsCode: _detailsCode(e.details),
        httpCode: e.code,
        retryAfterMs: _retryAfterMs(_detailsField(e.details, 'retryAfterMs')),
      );
    } catch (_) {
      throw const OtpRequestError(OtpRequestErrorKind.unknown);
    }
  }

  /// Reads the stable machine code the guard sends alongside its refusal.
  static String? _detailsCode(Object? details) {
    final value = _detailsField(details, 'code');
    return value is String ? value : null;
  }

  static Object? _detailsField(Object? details, String key) =>
      details is Map ? details[key] : null;

  /// The wire carries JSON numbers, which arrive as int or double depending on
  /// the platform and the value. A non-numeric or absent field stays null: an
  /// absent delay must not become a zero, which would read as "retry now".
  static int? _retryAfterMs(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
