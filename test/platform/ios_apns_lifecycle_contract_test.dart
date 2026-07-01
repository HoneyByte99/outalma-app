// Contract tests for the iOS APNs registration lifecycle.
//
// Regression guard for a real production bug: devices whose launch-time APNs
// registration failed (no network at that instant) never got a token because
// iOS does not retry on its own - and the first fix attempt was dead code
// because it hooked AppDelegate.applicationDidBecomeActive, which UIKit never
// calls in a UIScene-based app. Swift cannot be unit-tested from here, so
// these tests pin the native wiring as text contracts:
//   1. the app is (still) scene-based,
//   2. the foreground re-registration lives in SceneDelegate (the hook that
//      actually fires), not only at launch,
//   3. nobody reintroduces lifecycle logic in AppDelegate where it is dead.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final sceneDelegate = File(
    'ios/Runner/SceneDelegate.swift',
  ).readAsStringSync();
  final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

  group('iOS APNs lifecycle contract', () {
    test('app declares the UIScene lifecycle with our SceneDelegate', () {
      expect(infoPlist, contains('UIApplicationSceneManifest'));
      expect(infoPlist, contains('SceneDelegate'));
    });

    test('SceneDelegate re-registers for APNs on every foreground '
        '(sceneDidBecomeActive override, super preserved)', () {
      expect(
        sceneDelegate,
        contains('override func sceneDidBecomeActive'),
        reason:
            'Foreground APNs re-registration must hook the scene '
            'lifecycle - AppDelegate lifecycle methods are never called '
            'in a UIScene-based app.',
      );
      expect(sceneDelegate, contains('super.sceneDidBecomeActive'));
      expect(sceneDelegate, contains('registerForRemoteNotifications()'));
    });

    test('AppDelegate still triggers the launch-time APNs registration', () {
      expect(appDelegate, contains('didFinishLaunchingWithOptions'));
      expect(appDelegate, contains('registerForRemoteNotifications()'));
    });

    test('AppDelegate does not hook dead UIKit lifecycle methods', () {
      expect(
        appDelegate,
        isNot(contains('override func applicationDidBecomeActive')),
        reason:
            'applicationDidBecomeActive is never called in a UIScene-based '
            'app - logic placed there silently does nothing (this exact '
            'mistake shipped once). Use SceneDelegate.sceneDidBecomeActive.',
      );
    });

    test('AppDelegate surfaces APNs registration failures', () {
      expect(
        appDelegate,
        contains('didFailToRegisterForRemoteNotificationsWithError'),
        reason:
            'Registration failures must be logged, not swallowed - this is '
            'how we diagnose devices that never obtain an APNs token.',
      );
    });
  });
}
