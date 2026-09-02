import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/identity/capture_config.dart';
import 'package:outalma_app/src/application/identity/capture_source.dart';
import 'package:outalma_app/src/application/identity/identity_capture_providers.dart';
import 'package:outalma_app/src/application/identity/identity_ports.dart';
import 'package:outalma_app/src/data/services/fake_capture_source.dart';
import 'package:outalma_app/src/data/services/fake_document_text_detector.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/identity/identity_submit_error.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/features/provider/identity/identity_capture_flow.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'prov_1',
      displayName: 'Provider User',
      email: 'prov@test.com',
      country: 'FR',
      activeMode: ActiveMode.provider,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

class _SpyUpload implements IdentityUploadPort {
  final paths = <String>[];
  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    paths.add(path);
  }
}

class _StubSubmit implements IdentitySubmitPort {
  _StubSubmit({this.error});
  final IdentitySubmitError? error;
  int calls = 0;

  @override
  Future<IdentitySubmitOutcome> submit({required String batchId}) async {
    calls++;
    if (error != null) throw error!;
    return const IdentitySubmitOutcome(alreadySubmitted: false);
  }
}

LumaFrame _sharp({int size = 8, int atMs = 0}) {
  final bytes = Uint8List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      bytes[y * size + x] = ((x + y) % 2 == 0) ? 0 : 255;
    }
  }
  return LumaFrame(
    luma: bytes,
    width: size,
    height: size,
    rowStride: size,
    timestampMs: atMs,
  );
}

Widget _wrap({
  required FakeCaptureSource source,
  required IdentityUploadPort upload,
  required IdentitySubmitPort submit,
  required VoidCallback onFinished,
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
      identityCaptureSourceProvider.overrideWithValue(source),
      // Documents carry text: the readable-text gate must pass so the flow can
      // advance past each capture (the detector itself is exercised elsewhere).
      documentTextDetectorProvider.overrideWithValue(
        FakeDocumentTextDetector(),
      ),
      captureConfigProvider.overrideWithValue(
        const CaptureConfig(
          rectoSharpnessThreshold: 10,
          versoSharpnessThreshold: 5,
        ),
      ),
      identityUploadPortProvider.overrideWithValue(upload),
      identitySubmitPortProvider.overrideWithValue(submit),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: IdentityCaptureFlow(
        onFinished: onFinished,
        onContactSupport: () {},
      ),
    ),
  );
}

// Drives one document capture through the MANUAL fallback: a sharp frame, then
// the fallback timer runs out so the button is offered, then the button.
//
// This flow test is about the journey (recto, verso, selfie, recap, deposit),
// not about the shutter, so it deliberately takes the deterministic manual
// route rather than staging the movement and hold an automatic shot needs.
Future<void> _captureDocument(
  WidgetTester tester,
  FakeCaptureSource source,
) async {
  source.emitLuma(_sharp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 10));
  await tester.tap(find.text('Prendre la photo'));
  await tester.pumpAndSettle();
}

// Drives the selfie: a turn then a frontal return opens the shutter.
Future<void> _captureSelfie(
  WidgetTester tester,
  FakeCaptureSource source,
) async {
  source.emitFace(
    const FaceObservation(faceCount: 1, yawAngleDeg: 30, timestampMs: 0),
  );
  await tester.pump();
  await tester.pump();
  source.emitFace(
    const FaceObservation(faceCount: 1, yawAngleDeg: 0, timestampMs: 100),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recto to verso to selfie to recap to a successful deposit', (
    tester,
  ) async {
    final source = FakeCaptureSource(
      captureBytes: Uint8List.fromList(const [5]),
    );
    addTearDown(source.dispose);
    final upload = _SpyUpload();
    final submit = _StubSubmit();
    var finished = false;

    await tester.pumpWidget(
      _wrap(
        source: source,
        upload: upload,
        submit: submit,
        onFinished: () => finished = true,
      ),
    );
    await tester.pumpAndSettle();

    // Recto.
    expect(find.text('Recto de la pièce'), findsOneWidget);
    await _captureDocument(tester, source);

    // Verso.
    expect(find.text('Verso de la pièce'), findsOneWidget);

    // The three pages share ONE capture source, and the architecture carries
    // no ownership token: the destroyed recto page must simply stop reacting.
    // Feed the shared source a stretch that WOULD fire, and check the count
    // moves at most once, for the verso alone.
    final beforeVerso = source.captureCount;
    for (var t = 0; t <= 4000; t += 100) {
      source.emitLuma(t == 0 ? _sharp(size: 12, atMs: t) : _sharp(atMs: t));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
      source.captureCount - beforeVerso,
      1,
      reason: 'exactly the verso, and nothing from the dead recto page',
    );

    // Selfie.
    expect(find.text('Selfie de vérification'), findsOneWidget);
    await _captureSelfie(tester, source);

    // Recap: nothing has been uploaded yet (E13).
    expect(find.text('Vérifiez vos photos'), findsOneWidget);
    expect(upload.paths, isEmpty);
    expect(submit.calls, 0);

    // Confirm the deposit.
    await tester.tap(find.text('Envoyer pour vérification'));
    await tester.pumpAndSettle();

    // Three objects uploaded then the callable, in order.
    expect(upload.paths.length, 3);
    expect(upload.paths[0], endsWith('/recto.jpg'));
    expect(upload.paths[1], endsWith('/verso.jpg'));
    expect(upload.paths[2], endsWith('/selfie.jpg'));
    expect(submit.calls, 1);

    expect(find.text('Photos envoyées'), findsOneWidget);
    await tester.tap(find.text('Terminé'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('a failed deposit is resumable on a fresh capture (AC-C14)', (
    tester,
  ) async {
    final source = FakeCaptureSource(
      captureBytes: Uint8List.fromList(const [5]),
    );
    addTearDown(source.dispose);
    final submit = _StubSubmit(
      error: const IdentitySubmitError(IdentitySubmitErrorKind.network),
    );

    await tester.pumpWidget(
      _wrap(
        source: source,
        upload: _SpyUpload(),
        submit: submit,
        onFinished: () {},
      ),
    );
    await tester.pumpAndSettle();

    await _captureDocument(tester, source); // recto
    await _captureDocument(tester, source); // verso
    await _captureSelfie(tester, source); // selfie
    await tester.tap(find.text('Envoyer pour vérification'));
    await tester.pumpAndSettle();

    // A network failure shows an actionable message, never a success screen.
    expect(find.text('Photos envoyées'), findsNothing);
    expect(find.textContaining('Connexion interrompue'), findsOneWidget);

    // Retry restarts the capture from the recto.
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Recto de la pièce'), findsOneWidget);
  });
}
