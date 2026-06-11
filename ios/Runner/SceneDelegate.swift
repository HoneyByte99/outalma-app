import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    // Re-attempt APNs registration on every foreground, not just at launch.
    // The single registration in didFinishLaunching silently fails if the
    // device had no network at that moment — and iOS does NOT auto-retry, so
    // getAPNSToken() stays null forever (apns-token-not-set → no FCM token →
    // no pushToken → no notifications). Re-registering when the app becomes
    // active recovers those devices the next time they open with a working
    // connection. Cheap and idempotent: if a token already exists, iOS returns
    // it immediately via Firebase's swizzled delegate.
    //
    // This MUST live here and not in AppDelegate.applicationDidBecomeActive:
    // the app uses the UIScene lifecycle (UIApplicationSceneManifest in
    // Info.plist), so UIKit never calls the AppDelegate lifecycle methods.
    // Guarded by test/platform/ios_apns_lifecycle_contract_test.dart.
    UIApplication.shared.registerForRemoteNotifications()
  }
}
