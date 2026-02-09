import AVKit
import Flutter
import UIKit

/// Manages AirPlay route picker via platform channel.
class AirPlayManager: NSObject {
    static let shared = AirPlayManager()

    private var methodChannel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func register(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.alyplayer/airplay",
            binaryMessenger: messenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "showRoutePicker":
                self.showRoutePicker(result: result)
            case "isAvailable":
                result(true) // AirPlay is always available on iOS
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func showRoutePicker(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            // Get the key window
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                result(FlutterError(code: "NO_WINDOW", message: "No key window", details: nil))
                return
            }

            // Create AVRoutePickerView and trigger it
            let routePicker = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            routePicker.isHidden = true
            window.addSubview(routePicker)

            // Find the button inside AVRoutePickerView and tap it
            for subview in routePicker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .touchUpInside)
                    break
                }
            }

            // Clean up after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                routePicker.removeFromSuperview()
            }

            result(true)
        }
    }
}
