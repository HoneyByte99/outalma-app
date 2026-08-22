import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/capture_selection.dart';

void main() {
  group('selectCaptureSource', () {
    String pick({required bool debugMode, required bool fakeEnabled}) {
      return selectCaptureSource<String>(
        debugMode: debugMode,
        fakeEnabled: fakeEnabled,
        real: () => 'real',
        fake: () => 'fake',
      );
    }

    test('fake only when BOTH debug mode and the dart-define are on', () {
      expect(pick(debugMode: true, fakeEnabled: true), 'fake');
    });

    test('real when the dart-define is off, even in debug', () {
      expect(pick(debugMode: true, fakeEnabled: false), 'real');
    });

    test('real when not in debug, even with the dart-define on', () {
      // This is the guard that matters: profile and release builds must never
      // reach the fake, whatever the define says.
      expect(pick(debugMode: false, fakeEnabled: true), 'real');
    });

    test('real when both are off', () {
      expect(pick(debugMode: false, fakeEnabled: false), 'real');
    });

    test('only calls the branch it selects', () {
      var realCalls = 0;
      var fakeCalls = 0;
      selectCaptureSource<String>(
        debugMode: true,
        fakeEnabled: true,
        real: () {
          realCalls++;
          return 'real';
        },
        fake: () {
          fakeCalls++;
          return 'fake';
        },
      );
      expect(realCalls, 0);
      expect(fakeCalls, 1);
    });
  });

  group('captureAvailable', () {
    test('is available on mobile', () {
      expect(captureAvailable(isWeb: false), isTrue);
    });

    test('is unavailable on web (mobile-only capture, D2)', () {
      expect(captureAvailable(isWeb: true), isFalse);
    });
  });
}
