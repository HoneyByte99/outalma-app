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
import 'package:outalma_app/src/data/services/fake_document_text_detector.dart';
import 'package:outalma_app/src/features/provider/identity/capture_document_page.dart';
import 'package:outalma_app/src/features/provider/identity/identity_capture_widgets.dart';

/// The geometry the contour depends on, pinned in CI rather than observed on a
/// phone. Three tests, and the first one is about Flutter itself.
///
/// The whole projection rests on one layout fact: under
/// `Stack(fit: StackFit.expand)` a non-positioned child gets TIGHT constraints,
/// and `RenderAspectRatio` returns `constraints.smallest` on a tight
/// constraint. So the `AspectRatio` that `CameraPreview` wraps itself in is
/// INERT, the camera texture is stretched over the whole rectangle, and
/// normalised plane coordinates map linearly onto the overlay.
///
/// If a future Flutter changed that rule, or a future `camera` inserted a
/// `Center` or a `FittedBox` into its tree, the contour would silently drift
/// instead of failing. These tests are what turn that into a red build.
///
/// Verified against Flutter 3.41.5 and camera 0.12.0+2.

/// A card-shaped bright region on a dark ground, big enough for the grid.
///
/// [scale] shrinks the card about the centre, so a test can produce a framing
/// the detector calls `tooSmall` without changing anything else.
LumaFrame _cardFrame({
  int width = 384,
  int height = 216,
  int atMs = 0,
  double scale = 1,
}) {
  final bytes = Uint8List(width * height);
  final halfW = 0.3 * scale;
  final halfH = 0.35 * scale;
  final left = (width * (0.5 - halfW)).round();
  final right = (width * (0.5 + halfW)).round();
  final top = (height * (0.5 - halfH)).round();
  final bottom = (height * (0.5 + halfH)).round();
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final inCard = x >= left && x <= right && y >= top && y <= bottom;
      bytes[y * width + x] = inCard ? 230 : 20;
    }
  }
  return LumaFrame(
    luma: bytes,
    width: width,
    height: height,
    rowStride: width,
    timestampMs: atMs,
  );
}

Widget _wrapContour(FakeCaptureSource source, {required CaptureConfig config}) {
  return ProviderScope(
    overrides: [
      identityCaptureSourceProvider.overrideWithValue(source),
      documentTextDetectorProvider.overrideWithValue(
        FakeDocumentTextDetector(),
      ),
      captureConfigProvider.overrideWithValue(config),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      home: CaptureDocumentPage(side: DocumentSide.recto, onCaptured: (_) {}),
    ),
  );
}

void main() {
  testWidgets('an AspectRatio is INERT under StackFit.expand', (tester) async {
    // The premise itself, with no camera and no contour in sight. A regression
    // in this Flutter rule is the one thing that would move the contour without
    // anything else failing.
    const stackKey = Key('the-stack');
    const childKey = Key('the-aspect-child');

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          key: stackKey,
          fit: StackFit.expand,
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: ColoredBox(
                key: childKey,
                color: Color(0xFF000000),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );

    final stackRect = tester.getRect(find.byKey(stackKey));
    final childRect = tester.getRect(find.byKey(childKey));
    expect(
      childRect,
      stackRect,
      reason: 'the AspectRatio must be inert, so the texture is full-bleed',
    );
  });

  testWidgets('the contour canvas covers the whole preview', (tester) async {
    // With the fake reproducing the real preview's SHAPE (an AspectRatio around
    // an expanded Stack), this is no longer true by construction: a fake that
    // returned a bare box would make it pass whatever camera did to its tree.
    final source = FakeCaptureSource()
      ..previewAspectRatio = 9 / 16
      ..geometry = const PreviewGeometry(
        previewWidth: 1920,
        previewHeight: 1080,
        sensorOrientation: 90,
        isIOS: false,
      );
    addTearDown(source.dispose);

    await tester.pumpWidget(
      _wrapContour(
        source,
        config: const CaptureConfig(
          contourOverlayEnabled: true,
          analyzeEveryNthFrame: 1,
          contourGridLongSide: 48,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Found by its ratio, not by tree position: the TEMPLATE also carries an
    // AspectRatio (85.6/54), so `.first` would be one refactor away from
    // silently comparing the wrong two rectangles.
    final previewAspectRatio = find.byWidgetPredicate(
      (w) => w is AspectRatio && (w.aspectRatio - 9 / 16).abs() < 1e-9,
    );
    expect(previewAspectRatio, findsOneWidget);

    final previewRect = tester.getRect(previewAspectRatio);
    final contourRect = tester.getRect(find.byType(DocumentContourOverlay));
    expect(contourRect, previewRect);

    // And both fill the stack, which is the inert-AspectRatio premise showing
    // up in the real tree rather than in an isolated fixture.
    final stackRect = tester.getRect(find.byType(Stack).first);
    expect(previewRect, stackRect);
  });

  testWidgets('no contour is drawn when preview and plane disagree', (
    tester,
  ) async {
    // The premise nothing in the platform guarantees: Android binds Preview and
    // ImageAnalysis without a shared ViewPort, so a 16:9 plane can end up over
    // a 4:3 preview. That contour would be wrong everywhere, and no
    // "is it inside the frame" net catches a systematic error like that.
    final source = FakeCaptureSource()
      ..previewAspectRatio = 3 / 4
      ..geometry = const PreviewGeometry(
        previewWidth: 1440,
        previewHeight: 1080, // 4:3, against a 16:9 frame below
        sensorOrientation: 90,
        isIOS: false,
      );
    addTearDown(source.dispose);

    await tester.pumpWidget(
      _wrapContour(
        source,
        config: const CaptureConfig(
          contourOverlayEnabled: true,
          analyzeEveryNthFrame: 1,
          contourGridLongSide: 48,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 8; i++) {
      source.emitLuma(_cardFrame(atMs: i * 100));
      await tester.pump();
    }

    final overlay = tester.widget<DocumentContourOverlay>(
      find.byType(DocumentContourOverlay),
    );
    expect(overlay.quad, isNull);
  });

  testWidgets('the contour appears once the card has been seen enough', (
    tester,
  ) async {
    final source = FakeCaptureSource()
      ..previewAspectRatio = 9 / 16
      ..geometry = const PreviewGeometry(
        previewWidth: 1920,
        previewHeight: 1080,
        sensorOrientation: 90,
        isIOS: false,
      );
    addTearDown(source.dispose);

    await tester.pumpWidget(
      _wrapContour(
        source,
        config: const CaptureConfig(
          contourOverlayEnabled: true,
          analyzeEveryNthFrame: 1,
          contourGridLongSide: 48,
          acquireFrames: 3,
          loseFrames: 5,
          edgeThreshold: 20,
        ),
      ),
    );
    await tester.pumpAndSettle();

    DocumentContourOverlay overlay() => tester.widget<DocumentContourOverlay>(
      find.byType(DocumentContourOverlay),
    );

    expect(overlay().quad, isNull, reason: 'nothing seen yet');

    for (var i = 0; i < 6; i++) {
      source.emitLuma(_cardFrame(atMs: i * 100));
      await tester.pump();
    }
    expect(overlay().quad, isNotNull, reason: 'the card has been seen');

    // And the template yields the floor rather than competing with it.
    final template = tester.widget<DocumentFrameOverlay>(
      find.byType(DocumentFrameOverlay),
    );
    expect(template.contourVisible, isTrue);

    // The colour the template gave up must have moved onto the contour, not
    // fallen back to DocumentContourOverlay's own white default (M3): both
    // widgets must agree on the exact same colorFor(state.reason).
    expect(
      overlay().color,
      colorFor(template.reason),
      reason:
          'the contour must carry the live shutter colour, '
          'not a hardcoded default',
    );
  });

  testWidgets(
    'with the overlay flag off, nothing is drawn and no work is done',
    (tester) async {
      final source = FakeCaptureSource()
        ..previewAspectRatio = 9 / 16
        ..geometry = const PreviewGeometry(
          previewWidth: 1920,
          previewHeight: 1080,
          sensorOrientation: 90,
          isIOS: false,
        );
      addTearDown(source.dispose);

      await tester.pumpWidget(
        _wrapContour(
          source,
          // The flag is passed EXPLICITLY false rather than left to the
          // default: the shipped default became true in build 32 (calibration
          // pass). This test guards the OFF path, not the shipped one.
          config: const CaptureConfig(
            analyzeEveryNthFrame: 1,
            contourOverlayEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 8; i++) {
        source.emitLuma(_cardFrame(atMs: i * 100));
        await tester.pump();
      }

      expect(
        tester
            .widget<DocumentContourOverlay>(find.byType(DocumentContourOverlay))
            .quad,
        isNull,
      );
      expect(
        tester
            .widget<DocumentFrameOverlay>(find.byType(DocumentFrameOverlay))
            .contourVisible,
        isFalse,
      );
    },
  );

  group('the framing flag', () {
    // The behavioural half of the second flag. Its unit test pins the default;
    // this pins what the default MEANS: with framing off, a badly framed card is
    // still photographed exactly as it was before this feature existed.
    Future<bool> runJourney(
      WidgetTester tester, {
      required bool contourFramingEnabled,
    }) async {
      final source = FakeCaptureSource()
        ..previewAspectRatio = 9 / 16
        ..geometry = const PreviewGeometry(
          previewWidth: 1920,
          previewHeight: 1080,
          sensorOrientation: 90,
          isIOS: false,
        );
      addTearDown(source.dispose);

      var captured = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityCaptureSourceProvider.overrideWithValue(source),
            documentTextDetectorProvider.overrideWithValue(
              FakeDocumentTextDetector(),
            ),
            captureConfigProvider.overrideWithValue(
              CaptureConfig(
                rectoSharpnessThreshold: 10,
                versoSharpnessThreshold: 5,
                analysisCenterFraction: 1,
                analyzeEveryNthFrame: 1,
                contourOverlayEnabled: true,
                contourFramingEnabled: contourFramingEnabled,
                contourGridLongSide: 48,
                edgeThreshold: 20,
                minFill: 0.3,
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            home: CaptureDocumentPage(
              side: DocumentSide.recto,
              onCaptured: (_) => captured = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Arm the shutter with a different scene, then hold a card that the
      // detector calls too small, well past the 800 ms hold.
      source.emitLuma(_cardFrame(atMs: 0, scale: 0.2));
      await tester.pump();
      for (var t = 100; t <= 2000; t += 100) {
        source.emitLuma(_cardFrame(atMs: t, scale: 0.45));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      return captured;
    }

    testWidgets('OFF: a badly framed card is still photographed', (
      tester,
    ) async {
      expect(await runJourney(tester, contourFramingEnabled: false), isTrue);
    });

    testWidgets('ON: a badly framed card is held back', (tester) async {
      expect(await runJourney(tester, contourFramingEnabled: true), isFalse);
    });
  });

  group('the framing copy on screen', () {
    // The other half of the A3 pair. The unit tests prove the shutter REACHES
    // tooClose; this proves the screen can say something about it, in French,
    // through l10n. Coverage of the increment named this line as reached by
    // nothing, and a state with no words is a blank circle for a provider who
    // cannot read.
    testWidgets('a card overflowing the frame says so, in French', (
      tester,
    ) async {
      final source = FakeCaptureSource()
        ..previewAspectRatio = 9 / 16
        ..geometry = const PreviewGeometry(
          previewWidth: 1920,
          previewHeight: 1080,
          sensorOrientation: 90,
          isIOS: false,
        );
      addTearDown(source.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityCaptureSourceProvider.overrideWithValue(source),
            documentTextDetectorProvider.overrideWithValue(
              FakeDocumentTextDetector(),
            ),
            captureConfigProvider.overrideWithValue(
              const CaptureConfig(
                rectoSharpnessThreshold: 10,
                versoSharpnessThreshold: 5,
                analysisCenterFraction: 1,
                analyzeEveryNthFrame: 1,
                contourOverlayEnabled: true,
                contourFramingEnabled: true,
                contourGridLongSide: 48,
                edgeThreshold: 20,
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            home: CaptureDocumentPage(
              side: DocumentSide.recto,
              onCaptured: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Arm on one scene, then present a card that spills past the frame.
      source.emitLuma(_cardFrame(atMs: 0, scale: 0.3));
      await tester.pump();
      for (var t = 100; t <= 900; t += 100) {
        source.emitLuma(_cardFrame(atMs: t, scale: 1.6));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Éloignez un peu la carte.'), findsOneWidget);
    });
  });
}
