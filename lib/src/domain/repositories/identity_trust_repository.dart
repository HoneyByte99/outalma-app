import '../enums/identity_trust_status.dart';

abstract interface class IdentityTrustRepository {
  /// Watches the public identity state of [uid].
  ///
  /// Emits null when the document does not exist, which is the "not verified"
  /// state and not an error: at launch it is the majority case.
  Stream<IdentityTrustStatus?> watch(String uid);
}
