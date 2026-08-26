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
LumaFrame _sharpFrame({int size = 8}) {
  final bytes = Uint8List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      bytes[y * size + x] = ((x + y) % 2 == 0) ? 0 : 255;
    }
  }
  return LumaFrame(luma: bytes, width: size, height: size, rowStride: size);
}

// A flat luma plane: variance is zero, i.e. "too blurry".
LumaFrame _blurryFrame({int size = 8}) {
  final bytes = Uint8List(size * size)..fillRange(0, size * size, 128);
  return LumaFrame(luma: bytes, width: size, height: size, rowStride: size);
}

Widget _wrap(
  FakeCaptureSource source, {
  required ValueChanged<Uint8List> onCaptured,
  FakeDocumentTextDetector? textDetector,
}) {
  return ProviderScope(
    overrides: [
      identityCaptureSourceProvider.overrideWithValue(source),
      documentTextDetectorProvider.overrideWithValue(
        textDetector ?? FakeDocumentTextDetector(),
      ),
      // Low thresholds so the checkerboard passes and the flat frame fails,
      // while keeping recto strictly harder than verso.
      captureConfigProvider.overrideWithValue(
        const CaptureConfig(
          rectoSharpnessThreshold: 10,
          versoSharpnessThreshold: 5,
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CaptureDocumentPage(
        side: DocumentSide.recto,
        onCaptured: onCaptured,
      ),
    ),
  );
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

    await tester.tap(find.text('Prendre la photo'));
    await tester.pumpAndSettle();

    expect(captured, equals(Uint8List.fromList(const [7, 7, 7])));
    expect(detector.detectCount, 1);
  });
}
