import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Read the Maps API key injected via Info.plist → Secrets.xcconfig.
    // Never hardcode billing-sensitive keys in source files.
    let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String ?? ""
    #if DEBUG
    guard !mapsApiKey.isEmpty else {
      fatalError("MAPS_API_KEY is empty — create ios/Flutter/Secrets.xcconfig from Secrets.xcconfig.example (see scripts/run.sh).")
    }
    #else
    if mapsApiKey.isEmpty {
      NSLog("⚠️ MAPS_API_KEY is empty — Google Maps will not render. Check Secrets.xcconfig / CI injection.")
    }
    #endif
    GMSServices.provideAPIKey(mapsApiKey)

    // Explicitly trigger APNs registration. With this app's custom Flutter
    // engine setup, FirebaseMessaging's automatic registration was not firing,
    // so iOS never delivered an APNs device token (getAPNSToken() stayed null
    // and getToken() threw `apns-token-not-set`). Firebase's swizzled
    // didRegisterForRemoteNotificationsWithDeviceToken captures the token once
    // it arrives, so getToken() then succeeds.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
