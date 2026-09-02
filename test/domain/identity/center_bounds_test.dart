import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/center_bounds.dart';

void main() {
  group('centerBounds', () {
    test('fraction 1.0 returns the whole image', () {
      expect(centerBounds(100, 60, 1.0), (
        left: 0,
        top: 0,
        width: 100,
        height: 60,
      ));
    });

    test('a fraction above 1 is treated as the whole image', () {
      expect(centerBounds(100, 60, 1.5), (
        left: 0,
        top: 0,
        width: 100,
        height: 60,
      ));
    });

    test('fraction 0.5 is centred on both axes', () {
      expect(centerBounds(100, 60, 0.5), (
        left: 25,
        top: 15,
        width: 50,
        height: 30,
      ));
    });

    test('the window stays inside the image', () {
      final b = centerBounds(101, 61, 0.7);
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.left + b.width, lessThanOrEqualTo(101));
      expect(b.top + b.height, lessThanOrEqualTo(61));
    });

    test(
      'falls back to the whole image when the window would be degenerate',
      () {
        // 3 x 0.5 rounds to 2, which has no interior pixel to differentiate.
        expect(centerBounds(3, 3, 0.5), (left: 0, top: 0, width: 3, height: 3));
      },
    );

    test('falls back to the whole image on a fraction close to zero', () {
      expect(centerBounds(100, 60, 0.01), (
        left: 0,
        top: 0,
        width: 100,
        height: 60,
      ));
    });
  });
}
