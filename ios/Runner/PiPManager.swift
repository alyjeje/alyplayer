import AVKit
import AVFoundation
import Flutter

/// Manages Picture-in-Picture using a native AVPlayer for iOS.
/// When PiP is requested, this class creates a hidden AVPlayerViewController,
/// loads the same stream URL that media_kit is playing, and activates PiP.
/// When PiP ends, Flutter is notified so media_kit can resume.
class PiPManager: NSObject {
    static let shared = PiPManager()

    private var pipController: AVPictureInPictureController?
    private var playerViewController: AVPlayerViewController?
    private var avPlayer: AVPlayer?
    private var methodChannel: FlutterMethodChannel?

    private var currentUrl: String?
    private var isPiPActive = false

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func register(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.alyplayer/pip",
            binaryMessenger: messenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "PiPManager deallocated", details: nil))
                return
            }

            switch call.method {
            case "isSupported":
                result(AVPictureInPictureController.isPictureInPictureSupported())

            case "startPiP":
                guard let args = call.arguments as? [String: Any],
                      let url = args["url"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing 'url'", details: nil))
                    return
                }
                let position = args["positionSeconds"] as? Double ?? 0.0
                let headers = args["headers"] as? [String: String]
                self.startPiP(url: url, positionSeconds: position, headers: headers, result: result)

            case "stopPiP":
                self.stopPiP(result: result)

            case "isPiPActive":
                result(self.isPiPActive)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("[PiPManager] Audio session error: \(error)")
        }
    }

    // MARK: - Key Window helper (iOS 15+ safe)

    private func getKeyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: - Start PiP

    private func startPiP(url: String, positionSeconds: Double, headers: [String: String]?, result: @escaping FlutterResult) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            result(FlutterError(code: "UNSUPPORTED", message: "PiP not supported on this device", details: nil))
            return
        }

        configureAudioSession()
        currentUrl = url

        // Create AVPlayer
        let asset = AVURLAsset(url: URL(string: url)!)
        let playerItem = AVPlayerItem(asset: asset)
        avPlayer = AVPlayer(playerItem: playerItem)

        // Seek to current position if VOD
        if positionSeconds > 0 {
            let seekTime = CMTime(seconds: positionSeconds, preferredTimescale: 1000)
            avPlayer?.seek(to: seekTime)
        }

        // Create AVPlayerViewController (hidden -- used only for PiP)
        let playerVC = AVPlayerViewController()
        playerVC.player = avPlayer
        playerVC.allowsPictureInPicturePlayback = true
        if #available(iOS 14.2, *) {
            playerVC.canStartPictureInPictureAutomaticallyFromInline = true
        }

        // Add to view hierarchy (required for PiP to work)
        if let rootVC = getKeyWindow()?.rootViewController {
            playerVC.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            playerVC.view.alpha = 0.01
            rootVC.view.addSubview(playerVC.view)
            rootVC.addChild(playerVC)
            playerVC.didMove(toParent: rootVC)
        }

        playerViewController = playerVC
        avPlayer?.play()

        // Wait for player to initialize, then start PiP
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            if let playerLayer = self.findPlayerLayer(in: playerVC.view.layer) {
                let pipCtrl = AVPictureInPictureController(playerLayer: playerLayer)
                pipCtrl.delegate = self
                self.pipController = pipCtrl

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if pipCtrl.isPictureInPicturePossible {
                        pipCtrl.startPictureInPicture()
                        self.isPiPActive = true
                        result(true)
                    } else {
                        result(FlutterError(code: "PIP_FAILED", message: "PiP not possible", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "PIP_FAILED", message: "Could not find player layer", details: nil))
            }
        }
    }

    private func findPlayerLayer(in layer: CALayer) -> AVPlayerLayer? {
        if let playerLayer = layer as? AVPlayerLayer {
            return playerLayer
        }
        for sublayer in layer.sublayers ?? [] {
            if let found = findPlayerLayer(in: sublayer) {
                return found
            }
        }
        return nil
    }

    // MARK: - Stop PiP

    private func stopPiP(result: @escaping FlutterResult) {
        pipController?.stopPictureInPicture()
        cleanupNativePlayer()
        result(true)
    }

    private func cleanupNativePlayer() {
        avPlayer?.pause()
        avPlayer = nil

        playerViewController?.willMove(toParent: nil)
        playerViewController?.view.removeFromSuperview()
        playerViewController?.removeFromParent()
        playerViewController = nil

        pipController = nil
        isPiPActive = false
        currentUrl = nil
    }

    private func getCurrentPosition() -> Double {
        guard let player = avPlayer else { return 0.0 }
        return CMTimeGetSeconds(player.currentTime())
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPManager: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        isPiPActive = true
        methodChannel?.invokeMethod("onPiPStarted", arguments: nil)
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        let position = getCurrentPosition()
        isPiPActive = false
        methodChannel?.invokeMethod("onPiPStopped", arguments: [
            "position": position
        ])
        cleanupNativePlayer()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isPiPActive = false
        methodChannel?.invokeMethod("onPiPError", arguments: [
            "error": error.localizedDescription
        ])
        cleanupNativePlayer()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        let position = getCurrentPosition()
        methodChannel?.invokeMethod("onPiPRestoreUI", arguments: [
            "position": position
        ])
        completionHandler(true)
    }
}
