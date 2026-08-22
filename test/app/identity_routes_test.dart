// Locks the identity route contract wired in router.dart (E6). A silent change
// to any of these paths would orphan the capture journey again, which is the
// exact bug this increment exists to fix, so the paths are pinned here.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/router.dart';

void main() {
  test('identity routes are the expected paths', () {
    expect(AppRoutes.identityStatus, '/provider/identity');
    expect(AppRoutes.identityGuide, '/provider/identity/guide');
    expect(AppRoutes.identityCapture, '/provider/identity/capture');
    expect(AppRoutes.identityUnavailable, '/provider/identity/unavailable');
  });

  test('guide and capture live under the status entry', () {
    expect(AppRoutes.identityGuide, startsWith(AppRoutes.identityStatus));
    expect(AppRoutes.identityCapture, startsWith(AppRoutes.identityStatus));
  });
}
