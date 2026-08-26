import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/fake_capture_source.dart';
import '../../data/services/functions_identity_submit_service.dart';
import '../../data/services/identity_upload_service.dart';
// Web isolation (archi 5.3): the real adapter pulls in `camera` and ML Kit,
// which have no web support, so it is imported only under dart.library.io. On
// web the stub is compiled instead and the entry is never offered (AC-C04).
import '../../data/services/camera_capture_source_stub.dart'
    if (dart.library.io) '../../data/services/camera_capture_source.dart';
// Web isolation (archi 5.3): `google_mlkit_text_recognition` has no web support,
// so the real detector is imported only under dart.library.io; the stub compiles
// on web where the capture entry is never offered.
import '../../data/services/mlkit_document_text_detector_stub.dart'
    if (dart.library.io) '../../data/services/mlkit_document_text_detector.dart';
import '../../domain/identity/capture_selection.dart';
import '../auth/auth_providers.dart';
import 'capture_config.dart';
import 'capture_source.dart';
import 'document_text_detector.dart';
import 'hex_batch_id_generator.dart';
import 'identity_deposit_service.dart';
import 'identity_ports.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

final identityUploadPortProvider = Provider<IdentityUploadPort>(
  (ref) => IdentityUploadService(ref.watch(firebaseStorageProvider)),
);

final identitySubmitPortProvider = Provider<IdentitySubmitPort>(
  (ref) => FunctionsIdentitySubmitService(ref.watch(functionsProvider)),
);

final batchIdGeneratorProvider = Provider<BatchIdGenerator>(
  (ref) => HexBatchIdGenerator(),
);

final captureConfigProvider = Provider<CaptureConfig>(
  (ref) => const CaptureConfig(),
);

/// The injectable capture seam (archi 5.2).
///
/// The choice is a PURE function ([selectCaptureSource]), so breaking the guard
/// breaks a test: the fake is reachable only when both `kDebugMode` (profile and
/// release excluded) AND the `OUTALMA_FAKE_CAPTURE` dart-define are set. In a
/// widget test this provider is overridden with a drivable [FakeCaptureSource].
final identityCaptureSourceProvider = Provider<IdentityCaptureSource>((ref) {
  return selectCaptureSource<IdentityCaptureSource>(
    debugMode: kDebugMode,
    fakeEnabled: const bool.fromEnvironment('OUTALMA_FAKE_CAPTURE'),
    real: CameraCaptureSource.new,
    fake: FakeCaptureSource.new,
  );
});

/// The injectable readable-text detector (archi 5.3 extension). A widget test
/// overrides this with a drivable [FakeDocumentTextDetector]; the real one wraps
/// on-device ML Kit text recognition and is disposed when the provider drops.
final documentTextDetectorProvider = Provider<DocumentTextDetector>((ref) {
  final detector = MlkitDocumentTextDetector();
  ref.onDispose(detector.dispose);
  return detector;
});

final identityDepositServiceProvider = Provider<IdentityDepositService>((ref) {
  return IdentityDepositService(
    upload: ref.watch(identityUploadPortProvider),
    submit: ref.watch(identitySubmitPortProvider),
    batchIds: ref.watch(batchIdGeneratorProvider),
  );
});
