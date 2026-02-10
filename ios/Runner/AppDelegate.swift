import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure audio session for background playback (required for PiP and background audio)
    PiPManager.configureAudioSession()

    // Register platform channels
    if let controller = window?.rootViewController as? FlutterViewController {
      PiPManager.shared.register(with: controller.binaryMessenger)
      AirPlayManager.shared.register(with: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
