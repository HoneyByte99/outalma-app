/// Pure selectors for the capture seam (archi 5.2), kept out of any provider
/// body so they are testable on the VM and mutable as guards (T3/T4).
///
/// The round-1 review showed why an inline `!kReleaseMode` guard was worthless:
/// it is a compile-time constant, false under `flutter test`, so neutralising
/// it could never turn a test red. Extracting the decision into a pure function
/// makes the guard real: a test drives all four combinations, and breaking the
/// condition breaks a test.
library;

/// Chooses the real or the fake capture source.
///
/// The fake is reachable ONLY when both [debugMode] is true (so profile and
/// release builds are excluded: `kReleaseMode` alone would leave profile open)
/// AND [fakeEnabled] is set (the `OUTALMA_FAKE_CAPTURE` dart-define). Two locks,
/// so the test seam can never ship to a production build. Generic over the
/// source type so this file stays in the domain layer without importing the
/// concrete camera adapter.
T selectCaptureSource<T>({
  required bool debugMode,
  required bool fakeEnabled,
  required T Function() real,
  required T Function() fake,
}) {
  return (debugMode && fakeEnabled) ? fake() : real();
}

/// Whether the identity capture flow can run on this platform.
///
/// The capture is mobile-only (D2): `camera` and ML Kit have no web support,
/// and the flow must never be offered where it cannot complete. On web the
/// entry shows an explicit "use the mobile app" message instead (AC-C04),
/// which is why this is a pure predicate on [isWeb] rather than a branch read
/// inline from `kIsWeb` (that would be dead code under a VM test run).
bool captureAvailable({required bool isWeb}) => !isWeb;
