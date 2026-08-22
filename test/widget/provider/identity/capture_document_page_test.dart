import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/capture_config.dart';
import 'package:outalma_app/src/application/identity/capture_source.dart';
import 'package:outalma_app/src/application/identity/identity_capture_providers.dart';
import 'package:outalma_app/src/data/services/fake_capture_source.dart';
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
}) {
  return ProviderScope(
    overrides: [
      identityCaptureSourceProvider.overrideWithValue(source),
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
}
