import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/capture_source.dart';
import 'package:outalma_app/src/application/identity/identity_capture_providers.dart';
import 'package:outalma_app/src/data/services/fake_capture_source.dart';
import 'package:outalma_app/src/features/provider/identity/selfie_liveness_page.dart';

/// WARNING before adding a test here: the face guide LOOPS while the challenge
/// is in `turnHead`, because the gesture has to keep being demonstrated. A
/// `pumpAndSettle` reached in that state never converges and times out. The
/// calls below are safe only because they land in `waitingFace` or
/// `returnToFront`. In `turnHead`, pump a bounded duration instead.

Widget _wrap(
  FakeCaptureSource source, {
  required ValueChanged<Uint8List> onCaptured,
  required VoidCallback onContactSupport,
}) {
  return ProviderScope(
    overrides: [identityCaptureSourceProvider.overrideWithValue(source)],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SelfieLivenessPage(
        onCaptured: onCaptured,
        onContactSupport: onContactSupport,
      ),
    ),
  );
}

void main() {
  testWidgets('follows the challenge instructions then captures on ready', (
    tester,
  ) async {
    final source = FakeCaptureSource(
      captureBytes: Uint8List.fromList(const [7, 7]),
    );
    addTearDown(source.dispose);
    Uint8List? captured;

    await tester.pumpWidget(
      _wrap(source, onCaptured: (b) => captured = b, onContactSupport: () {}),
    );
    await tester.pumpAndSettle();

    // Waiting for a face.
    expect(find.text('Placez votre visage dans le cadre.'), findsOneWidget);

    // One frontal face: asked to turn the head. Two pumps: the broadcast
    // observation is delivered on a microtask, then the rebuild follows.
    source.emitFace(
      const FaceObservation(faceCount: 1, yawAngleDeg: 0, timestampMs: 0),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Tournez lentement la tête sur le côté.'), findsOneWidget);

    // Head turned past the threshold: asked to face the lens again.
    source.emitFace(
      const FaceObservation(faceCount: 1, yawAngleDeg: 30, timestampMs: 100),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Revenez maintenant face à l\'objectif.'), findsOneWidget);

    // Frontal again after a proven turn: the shutter fires.
    source.emitFace(
      const FaceObservation(faceCount: 1, yawAngleDeg: 0, timestampMs: 200),
    );
    await tester.pumpAndSettle();

    expect(source.captureCount, 1);
    expect(captured, equals(Uint8List.fromList(const [7, 7])));
  });

  testWidgets(
    'after three failures, only a support route is offered (AC-C34)',
    (tester) async {
      final source = FakeCaptureSource();
      addTearDown(source.dispose);
      var supportOpened = false;

      await tester.pumpWidget(
        _wrap(
          source,
          onCaptured: (_) {},
          onContactSupport: () => supportOpened = true,
        ),
      );
      await tester.pumpAndSettle();

      // Three timeouts (each: a start frame, then a frame past the 15s window).
      for (var i = 0; i < 3; i++) {
        source.emitFace(
          const FaceObservation(faceCount: 1, yawAngleDeg: 0, timestampMs: 0),
        );
        await tester.pump();
        await tester.pump();
        source.emitFace(
          const FaceObservation(
            faceCount: 1,
            yawAngleDeg: 0,
            timestampMs: 20000,
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      expect(find.text('Besoin d\'aide ?'), findsOneWidget);
      expect(source.captureCount, 0, reason: 'the challenge is never bypassed');

      await tester.tap(find.text('Contacter le support'));
      await tester.pump();
      expect(supportOpened, isTrue);
    },
  );
}
