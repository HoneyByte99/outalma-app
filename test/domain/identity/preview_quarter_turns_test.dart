import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/preview_quarter_turns.dart';

void main() {
  group('previewQuarterTurns', () {
    // The claim this test exists to pin: on iOS the preview texture and the
    // Dart image stream are the same CVPixelBuffer, so nothing can rotate one
    // relative to the other. No sensor value and no device posture changes it.
    test('is always zero on iOS, whatever the sensor reports', () {
      for (final sensor in const [0, 90, 180, 270]) {
        expect(
          previewQuarterTurns(isIOS: true, sensorOrientation: sensor),
          0,
          reason: 'sensorOrientation $sensor',
        );
      }
    });

    test('follows the sensor orientation on Android', () {
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: 0), 0);
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: 90), 1);
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: 180), 2);
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: 270), 3);
    });

    test('stays inside 0 to 3 for an out-of-range sensor value', () {
      // A camera reporting something unexpected must still give a usable
      // preview: refusing here would take out the capture screen for the sake
      // of a cosmetic overlay.
      for (final sensor in const [360, 450, -90, 720]) {
        final turns = previewQuarterTurns(
          isIOS: false,
          sensorOrientation: sensor,
        );
        expect(turns, inInclusiveRange(0, 3), reason: 'sensor $sensor');
      }
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: 360), 0);
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: -90), 3);
    });

    test('rounds an off-quadrant value to the nearest quarter turn', () {
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: 88), 1);
      expect(previewQuarterTurns(isIOS: false, sensorOrientation: 100), 1);
    });
  });
}
