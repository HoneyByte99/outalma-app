import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/capture_config.dart';
import 'package:outalma_app/src/application/identity/identity_capture_providers.dart';
import 'package:outalma_app/src/data/services/fake_capture_source.dart';
import 'package:outalma_app/src/data/services/fake_document_text_detector.dart';
import 'package:outalma_app/src/features/provider/identity/identity_capture_flow.dart';

/// The orientation lock, and specifically WHERE it lives.
///
/// It is taken by the flow and not by the capture page, because the two document
/// pages carry different `ValueKey`s: swapping recto for verso makes Flutter
/// inflate the new element, running its `initState`, BEFORE unmounting the old
/// one at `finalizeTree`. A lock taken per page would therefore be released by
/// the outgoing recto immediately after the verso took it, leaving the second
/// half of the journey unlocked. These tests pin that ordering rather than
/// trusting the reasoning.
void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<MethodCall> orientationCalls() => calls
      .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
      .toList();

  Widget wrap({required bool contourOverlayEnabled}) {
    final source = FakeCaptureSource();
    addTearDown(source.dispose);
    return ProviderScope(
      overrides: [
        captureConfigProvider.overrideWithValue(
          CaptureConfig(contourOverlayEnabled: contourOverlayEnabled),
        ),
        identityCaptureSourceProvider.overrideWithValue(source),
        documentTextDetectorProvider.overrideWithValue(
          FakeDocumentTextDetector(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IdentityCaptureFlow(onFinished: () {}, onContactSupport: () {}),
      ),
    );
  }

  testWidgets('locks portrait once when the contour is drawn', (tester) async {
    await tester.pumpWidget(wrap(contourOverlayEnabled: true));
    await tester.pumpAndSettle();

    final locks = orientationCalls();
    expect(locks, hasLength(1));
    expect(locks.single.arguments, ['DeviceOrientation.portraitUp']);
  });

  testWidgets('takes NO lock while the contour is off', (tester) async {
    // Android and iPad rotate freely today (no screenOrientation in the
    // manifest, four orientations on iPad in Info.plist), so locking portrait
    // is a visible behaviour change. It must not ship with the feature off.
    await tester.pumpWidget(wrap(contourOverlayEnabled: false));
    await tester.pumpAndSettle();

    expect(orientationCalls(), isEmpty);
  });

  testWidgets('restores the platform default on the way out', (tester) async {
    await tester.pumpWidget(wrap(contourOverlayEnabled: true));
    await tester.pumpAndSettle();
    calls.clear();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final restores = orientationCalls();
    expect(restores, hasLength(1));
    expect(restores.single.arguments, isEmpty);
  });

  testWidgets('never releases the lock while the journey is still running', (
    tester,
  ) async {
    // The trap this placement exists to close. The flow rebuilds through its
    // steps without ever disposing, so no restore may be emitted between the
    // first frame and the end of the journey.
    await tester.pumpWidget(wrap(contourOverlayEnabled: true));
    await tester.pumpAndSettle();
    calls.clear();

    // Several rebuilds of the live flow: nothing may restore the orientation.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(
      orientationCalls(),
      isEmpty,
      reason: 'the lock must hold for the whole journey, recto AND verso',
    );
  });
}
