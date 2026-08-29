import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/capture_config.dart';
import 'package:outalma_app/src/application/identity/capture_source.dart';
import 'package:outalma_app/src/application/identity/document_text_detector.dart';
import 'package:outalma_app/src/application/identity/identity_capture_providers.dart';
import 'package:outalma_app/src/data/services/fake_capture_source.dart';
import 'package:outalma_app/src/data/services/fake_document_text_detector.dart';
import 'package:outalma_app/src/features/provider/identity/capture_document_page.dart';

// A sharp luma plane: a 0/255 checkerboard has a large Laplacian variance.
// [atMs] drives the frame clock the shutter measures its hold against.
LumaFrame _sharpFrame({int size = 8, int atMs = 0}) {
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

// A flat luma plane: variance is zero, i.e. "too blurry".
LumaFrame _blurryFrame({int size = 8, int atMs = 0, int level = 128}) {
  final bytes = Uint8List(size * size)..fillRange(0, size * size, level);
  return LumaFrame(
    luma: bytes,
    width: size,
    height: size,
    rowStride: size,
    timestampMs: atMs,
  );
}

Widget _wrap(
  FakeCaptureSource source, {
  required ValueChanged<Uint8List> onCaptured,
  FakeDocumentTextDetector? textDetector,
  DocumentSide side = DocumentSide.recto,
}) {
  return ProviderScope(
    overrides: [
      identityCaptureSourceProvider.overrideWithValue(source),
      documentTextDetectorProvider.overrideWithValue(
        textDetector ?? FakeDocumentTextDetector(),
      ),
      // Low thresholds so the checkerboard passes and the flat frame fails,
      // while keeping recto strictly harder than verso. The analysis window is
      // left at the whole frame: these synthetic planes are uniform, so
      // cropping would only make the fixtures harder to read.
      captureConfigProvider.overrideWithValue(
        const CaptureConfig(
          rectoSharpnessThreshold: 10,
          versoSharpnessThreshold: 5,
          analysisCenterFraction: 1,
          analyzeEveryNthFrame: 1,
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CaptureDocumentPage(side: side, onCaptured: onCaptured),
    ),
  );
}

/// Feeds frames the way a hand does: a first different frame ARMS the shutter
/// (the scene moved), then an identical stretch holds it still until the hold
/// elapses. Returns nothing; the caller asserts on what the page did.
Future<void> _presentCard(
  WidgetTester tester,
  FakeCaptureSource source, {
  int fromMs = 0,
  int untilMs = 2000,
  int stepMs = 100,
}) async {
  // The arming frame: a different plane, so the motion signature moves.
  source.emitLuma(_blurryFrame(atMs: fromMs, level: 20));
  await tester.pump();
  // Then a steady, sharp card.
  for (var t = fromMs + stepMs; t <= untilMs; t += stepMs) {
    source.emitLuma(_sharpFrame(atMs: t));
    await tester.pump();
  }
}

/// Brings the screen to the state where the manual shutter is offered, by
/// letting the one-shot fallback timer run out.
///
/// The button is no longer there from the first millisecond: the photo is meant
/// to be taken automatically, and the button is the fallback for when that does
/// not happen. No pumpAndSettle, and it tolerates a button that is already
/// present, so the same helper is green before and after the shutter is wired.
Future<void> revealManualShutter(
  WidgetTester tester, {
  Duration fallbackAfter = const Duration(seconds: 10),
}) async {
  await tester.pump(fallbackAfter);
}

void main() {
  testWidgets('shows the permission-denied state when denied (AC-C11)', (
    tester,
  ) async {
    final source = FakeCaptureSource(permission: CameraPermissionState.denied);
    addTearDown(source.dispose);

    await tester.pumpWidget(_wrap(source, onCaptured: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Caméra non autorisée'), findsOneWidget);
  });

  testWidgets('shows the unavailable state when no camera can open', (
    tester,
  ) async {
    final source = FakeCaptureSource(available: false);
    addTearDown(source.dispose);

    await tester.pumpWidget(_wrap(source, onCaptured: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Caméra indisponible'), findsOneWidget);
  });

  testWidgets('refuses a blurry frame before any capture (AC-C06)', (
    tester,
  ) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    Uint8List? captured;

    await tester.pumpWidget(_wrap(source, onCaptured: (b) => captured = b));
    await tester.pumpAndSettle();

    source.emitLuma(_blurryFrame());
    await tester.pump();

    await revealManualShutter(tester);
    await tester.tap(find.text('Prendre la photo'));
    await tester.pump();

    expect(
      find.textContaining('trop floue'),
      findsOneWidget,
      reason: 'a blurry frame must be refused with guidance',
    );
    expect(captured, isNull, reason: 'nothing is captured while blurry');
    expect(source.captureCount, 0);
  });

  testWidgets('captures once the frame is sharp enough', (tester) async {
    final source = FakeCaptureSource(
      captureBytes: Uint8List.fromList(const [9, 9, 9]),
    );
    addTearDown(source.dispose);
    Uint8List? captured;

    await tester.pumpWidget(_wrap(source, onCaptured: (b) => captured = b));
    await tester.pumpAndSettle();

    source.emitLuma(_sharpFrame());
    await tester.pump();

    await revealManualShutter(tester);
    await tester.tap(find.text('Prendre la photo'));
    await tester.pumpAndSettle();

    expect(source.captureCount, 1);
    expect(captured, isNotNull);
    expect(captured, equals(Uint8List.fromList(const [9, 9, 9])));
  });

  testWidgets('offers "send anyway" after two blur refusals (AC-C34)', (
    tester,
  ) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    Uint8List? captured;

    await tester.pumpWidget(_wrap(source, onCaptured: (b) => captured = b));
    await tester.pumpAndSettle();

    source.emitLuma(_blurryFrame());
    await tester.pump();

    // Two consecutive blur refusals on the same still.
    await revealManualShutter(tester);
    await tester.tap(find.text('Prendre la photo'));
    await tester.pump();
    expect(find.text('Envoyer quand même, un humain relira'), findsNothing);

    await tester.tap(find.text('Prendre la photo'));
    await tester.pump();
    expect(find.text('Envoyer quand même, un humain relira'), findsOneWidget);

    // The escape sends the still despite the blur (a human will review it).
    await tester.tap(find.text('Envoyer quand même, un humain relira'));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(source.captureCount, 1);
  });

  testWidgets('refuses a sharp still that carries no readable text (AC-C06b)', (
    tester,
  ) async {
    // A crisp photo of anything but a document (a wall, a cow) passes the
    // sharpness gate; the readable-text gate must still refuse it.
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    final detector = FakeDocumentTextDetector(result: DocumentTextResult.none);
    Uint8List? captured;

    await tester.pumpWidget(
      _wrap(source, onCaptured: (b) => captured = b, textDetector: detector),
    );
    await tester.pumpAndSettle();

    source.emitLuma(_sharpFrame());
    await tester.pump();

    await revealManualShutter(tester);
    await tester.tap(find.text('Prendre la photo'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Aucun texte lisible'),
      findsOneWidget,
      reason: 'a sharp still with no text must be refused with guidance',
    );
    expect(captured, isNull, reason: 'a non-document is never accepted');
    expect(detector.detectCount, 1, reason: 'the text gate must run');
    // The still WAS shot (sharpness passed) before the text gate rejected it.
    expect(source.captureCount, 1);
  });

  testWidgets('"send anyway" still requires readable text (hardened AC-C34)', (
    tester,
  ) async {
    // The blur escape must not become a hole: a still with no text at all is
    // refused even on the "send anyway" path.
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    final detector = FakeDocumentTextDetector(result: DocumentTextResult.none);
    Uint8List? captured;

    await tester.pumpWidget(
      _wrap(source, onCaptured: (b) => captured = b, textDetector: detector),
    );
    await tester.pumpAndSettle();

    source.emitLuma(_blurryFrame());
    await tester.pump();

    await revealManualShutter(tester);
    await tester.tap(find.text('Prendre la photo'));
    await tester.pump();
    await tester.tap(find.text('Prendre la photo'));
    await tester.pump();
    expect(find.text('Envoyer quand même, un humain relira'), findsOneWidget);

    await tester.tap(find.text('Envoyer quand même, un humain relira'));
    await tester.pumpAndSettle();

    expect(captured, isNull, reason: 'no text means no accept, even forced');
    expect(find.textContaining('Aucun texte lisible'), findsOneWidget);
    expect(detector.detectCount, 1);
  });

  testWidgets('accepts a sharp still once readable text is detected', (
    tester,
  ) async {
    final source = FakeCaptureSource(
      captureBytes: Uint8List.fromList(const [7, 7, 7]),
    );
    addTearDown(source.dispose);
    final detector = FakeDocumentTextDetector(
      result: const DocumentTextResult(hasText: true, blockCount: 5),
    );
    Uint8List? captured;

    await tester.pumpWidget(
      _wrap(source, onCaptured: (b) => captured = b, textDetector: detector),
    );
    await tester.pumpAndSettle();

    source.emitLuma(_sharpFrame());
    await tester.pump();

    await revealManualShutter(tester);
    await tester.tap(find.text('Prendre la photo'));
    await tester.pumpAndSettle();

    expect(captured, equals(Uint8List.fromList(const [7, 7, 7])));
    expect(detector.detectCount, 1);
  });

  // --- The automatic shutter -----------------------------------------------

  testWidgets('fires on its own, with nobody touching the screen', (
    tester,
  ) async {
    final source = FakeCaptureSource(
      captureBytes: Uint8List.fromList(const [4, 2]),
    );
    addTearDown(source.dispose);
    Uint8List? captured;

    await tester.pumpWidget(_wrap(source, onCaptured: (b) => captured = b));
    await tester.pumpAndSettle();

    await _presentCard(tester, source);
    await tester.pumpAndSettle();

    expect(source.captureCount, 1, reason: 'no tap anywhere in this test');
    expect(captured, equals(Uint8List.fromList(const [4, 2])));
  });

  testWidgets('never fires while the scene keeps moving', (tester) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);

    await tester.pumpWidget(_wrap(source, onCaptured: (_) {}));
    await tester.pumpAndSettle();

    // Sharp throughout, but every frame differs from the last: a hand that
    // never settles.
    for (var t = 0; t <= 5000; t += 100) {
      source.emitLuma(
        (t ~/ 100).isEven
            ? _sharpFrame(atMs: t)
            : _sharpFrame(atMs: t, size: 12),
      );
      await tester.pump();
    }

    expect(source.captureCount, 0);
    expect(find.text('Tenez la carte immobile.'), findsOneWidget);
  });

  testWidgets('never fires on a scene that was already there and never moved '
      '(the verso would otherwise reshoot the recto)', (tester) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);

    await tester.pumpWidget(
      _wrap(source, onCaptured: (_) {}, side: DocumentSide.verso),
    );
    await tester.pumpAndSettle();

    // A perfectly framed, perfectly still card for ten seconds, which nobody
    // touched: exactly the recto left lying there when the verso opens.
    for (var t = 0; t <= 10000; t += 100) {
      source.emitLuma(_sharpFrame(atMs: t));
      await tester.pump();
    }

    expect(
      source.captureCount,
      0,
      reason: 'an untouched scene is never worth shooting',
    );
    expect(find.text('Retournez la carte.'), findsOneWidget);
  });

  testWidgets('the manual button is absent until the fallback is due', (
    tester,
  ) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);

    await tester.pumpWidget(_wrap(source, onCaptured: (_) {}));
    await tester.pumpAndSettle();

    expect(
      find.text('Prendre la photo'),
      findsNothing,
      reason: 'the photo is meant to be taken automatically',
    );

    await revealManualShutter(tester);
    expect(find.text('Prendre la photo'), findsOneWidget);
  });

  testWidgets('the fallback is offered even when no frame ever arrives', (
    tester,
  ) async {
    // A stream that opens and then delivers nothing: the user must not be left
    // without any command at all.
    final source = FakeCaptureSource();
    addTearDown(source.dispose);

    await tester.pumpWidget(_wrap(source, onCaptured: (_) {}));
    await tester.pumpAndSettle();

    await revealManualShutter(tester);
    expect(find.text('Prendre la photo'), findsOneWidget);
  });

  testWidgets('a refused shot shows the refusal, then the stream comes back', (
    tester,
  ) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    final detector = FakeDocumentTextDetector(result: DocumentTextResult.none);
    Uint8List? captured;

    await tester.pumpWidget(
      _wrap(source, onCaptured: (b) => captured = b, textDetector: detector),
    );
    await tester.pumpAndSettle();

    await _presentCard(tester, source);
    await tester.pumpAndSettle();

    expect(source.captureCount, 1, reason: 'it fired on its own');
    expect(captured, isNull, reason: 'no readable text, so not kept');
    expect(source.resumeCount, 1, reason: 'the preview must come back');
    expect(find.textContaining('Aucun texte lisible'), findsOneWidget);

    // The refusal survives many frames, not one. The clock stays continuous on
    // purpose: it is anchored on the first frame BACK, so what must be proved
    // is that it outlives the frames that follow it, not that it survives an
    // artificial jump forward.
    for (var t = 2100; t <= 2500; t += 100) {
      source.emitLuma(_sharpFrame(atMs: t));
      await tester.pump();
      expect(
        find.textContaining('Aucun texte lisible'),
        findsOneWidget,
        reason: 'still refused at t=$t',
      );
    }
    expect(source.captureCount, 1, reason: 'no re-fire during the refusal');
  });

  testWidgets('a still scene after a refusal needs a NEW gesture to fire', (
    tester,
  ) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    final detector = FakeDocumentTextDetector(result: DocumentTextResult.none);

    await tester.pumpWidget(
      _wrap(source, onCaptured: (_) {}, textDetector: detector),
    );
    await tester.pumpAndSettle();

    await _presentCard(tester, source);
    await tester.pumpAndSettle();
    expect(source.captureCount, 1);

    // Ten seconds of the same untouched scene after the refusal.
    for (var t = 5000; t <= 15000; t += 100) {
      source.emitLuma(_sharpFrame(atMs: t));
      await tester.pump();
    }
    expect(
      source.captureCount,
      1,
      reason: 'disarmed again: nothing fires without a fresh gesture',
    );
  });

  testWidgets('without a working resume, no frame arrives and nothing fires', (
    tester,
  ) async {
    final source = FakeCaptureSource()..failResume = true;
    addTearDown(source.dispose);
    final detector = FakeDocumentTextDetector(result: DocumentTextResult.none);

    await tester.pumpWidget(
      _wrap(source, onCaptured: (_) {}, textDetector: detector),
    );
    await tester.pumpAndSettle();

    await _presentCard(tester, source);
    await tester.pumpAndSettle();

    expect(source.captureCount, 1);
    // The fallback reopen ran; whether or not it delivers, the shutter is dead
    // until frames come back.
    final before = source.captureCount;
    for (var t = 6000; t <= 16000; t += 100) {
      source.emitLuma(_sharpFrame(atMs: t));
      await tester.pump();
    }
    expect(source.captureCount, before);
  });

  testWidgets(
    'with sharpness unknown, the button refuses and counts, and only then '
    'offers the escape (AC-C34 is not relabelled)',
    (tester) async {
      // A camera that opens but never delivers a frame: sharpness is UNKNOWN,
      // and the barrier must not be silently skipped just because there is
      // nothing to measure.
      final source = FakeCaptureSource();
      addTearDown(source.dispose);
      final detector = FakeDocumentTextDetector(
        result: DocumentTextResult.none,
      );
      Uint8List? captured;

      await tester.pumpWidget(
        _wrap(source, onCaptured: (b) => captured = b, textDetector: detector),
      );
      await tester.pumpAndSettle();

      await revealManualShutter(tester);
      expect(
        find.text('Prendre la photo'),
        findsOneWidget,
        reason: 'the user is never left without a command',
      );

      // First press: refused, nothing shot, and it COUNTS.
      await tester.tap(find.text('Prendre la photo'));
      await tester.pump();
      expect(
        source.captureCount,
        0,
        reason: 'unknown sharpness never captures silently',
      );
      expect(find.textContaining('trop floue'), findsOneWidget);
      expect(
        find.text('Envoyer quand même, un humain relira'),
        findsNothing,
        reason: 'AC-C34 still needs its two refusals',
      );

      // Second press: still refused, and only NOW does the escape appear.
      await tester.tap(find.text('Prendre la photo'));
      await tester.pump();
      expect(source.captureCount, 0);
      expect(find.text('Envoyer quand même, un humain relira'), findsOneWidget);

      // And the escape still runs the readable-text gate.
      await tester.tap(find.text('Envoyer quand même, un humain relira'));
      await tester.pumpAndSettle();
      expect(source.captureCount, 1, reason: 'the escape does shoot');
      expect(captured, isNull, reason: 'no text means no accept, even forced');
    },
  );

  testWidgets('the automatic shutter gives up after its refusal limit', (
    tester,
  ) async {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    final detector = FakeDocumentTextDetector(result: DocumentTextResult.none);

    await tester.pumpWidget(
      _wrap(source, onCaptured: (_) {}, textDetector: detector),
    );
    await tester.pumpAndSettle();

    // Three automatic attempts, each armed by a fresh gesture and refused.
    var clock = 0;
    for (var attempt = 0; attempt < 3; attempt++) {
      await _presentCard(tester, source, fromMs: clock, untilMs: clock + 4000);
      await tester.pumpAndSettle();
      clock += 6000;
    }

    expect(source.captureCount, 3);
    expect(
      find.text('Prendre la photo'),
      findsOneWidget,
      reason: 'the loop hands over rather than burning more shots',
    );

    // A fourth well-framed presentation must NOT fire automatically.
    await _presentCard(tester, source, fromMs: clock, untilMs: clock + 4000);
    await tester.pumpAndSettle();
    expect(source.captureCount, 3);
  });

  testWidgets('the unavailable state always offers a way back (U1)', (
    tester,
  ) async {
    final source = FakeCaptureSource(available: false);
    addTearDown(source.dispose);

    await tester.pumpWidget(_wrap(source, onCaptured: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Caméra indisponible'), findsOneWidget);
    expect(
      find.text('Réessayer'),
      findsOneWidget,
      reason: 'this state can now be entered mid journey',
    );
  });

  testWidgets('the permanently-denied state routes to the system settings', (
    tester,
  ) async {
    final source = FakeCaptureSource(
      permission: CameraPermissionState.permanentlyDenied,
    );
    addTearDown(source.dispose);

    await tester.pumpWidget(_wrap(source, onCaptured: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Caméra non autorisée'), findsOneWidget);
    expect(find.text('Ouvrir les réglages'), findsOneWidget);
  });
}
