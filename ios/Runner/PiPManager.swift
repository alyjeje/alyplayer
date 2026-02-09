import AVKit
import AVFoundation
import Flutter

/// Manages Picture-in-Picture using a native AVPlayer + AVPlayerLayer for iOS.
/// Creates a dedicated AVPlayerLayer (not relying on AVPlayerViewController's internal hierarchy).
class PiPManager: NSObject {
    static let shared = PiPManager()

    private var pipController: AVPictureInPictureController?
    private var avPlayer: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var containerView: UIView?
    private var methodChannel: FlutterMethodChannel?

    private var currentUrl: String?
    private var isPiPActive = false
    private var pendingResult: FlutterResult?

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
                self.startPiP(url: url, positionSeconds: position, result: result)

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

    // MARK: - Key Window

    private func getKeyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: - Start PiP

    private func startPiP(url: String, positionSeconds: Double, result: @escaping FlutterResult) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            result(FlutterError(code: "UNSUPPORTED", message: "PiP not supported", details: nil))
            return
        }

        // Clean up any previous session
        cleanupNativePlayer()
        configureAudioSession()
        currentUrl = url

        // Create AVPlayer
        guard let videoURL = URL(string: url) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid URL", details: nil))
            return
        }

        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        avPlayer = player

        // Seek to position for VOD
        if positionSeconds > 0 {
            player.seek(to: CMTime(seconds: positionSeconds, preferredTimescale: 1000))
        }

        // Create our OWN AVPlayerLayer (not searching for one inside AVPlayerViewController)
        let layer = AVPlayerLayer(player: player)
        layer.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
        layer.videoGravity = .resizeAspect
        playerLayer = layer

        // Attach to a small container view in the window
        let container = UIView(frame: CGRect(x: -10, y: -10, width: 2, height: 2))
        container.layer.addSublayer(layer)
        containerView = container

        if let window = getKeyWindow() {
            window.addSubview(container)
        }

        // Start playback
        player.play()

        // Create PiP controller from our dedicated layer
        guard let pipCtrl = AVPictureInPictureController(playerLayer: layer) else {
            result(FlutterError(code: "PIP_FAILED", message: "Could not create PiP controller", details: nil))
            cleanupNativePlayer()
            return
        }
        pipCtrl.delegate = self
        pipController = pipCtrl

        // Wait for the player to buffer, then start PiP
        pendingResult = result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, let pending = self.pendingResult else { return }
            self.pendingResult = nil

            if pipCtrl.isPictureInPicturePossible {
                pipCtrl.startPictureInPicture()
                pending(true)
            } else {
                // Retry once more after a longer delay
                self.pendingResult = pending
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self = self, let pending2 = self.pendingResult else { return }
                    self.pendingResult = nil
                    if pipCtrl.isPictureInPicturePossible {
                        pipCtrl.startPictureInPicture()
                        pending2(true)
                    } else {
                        pending2(FlutterError(code: "PIP_FAILED", message: "PiP not possible after retry", details: nil))
                        self.cleanupNativePlayer()
                    }
                }
            }
        }
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

        playerLayer?.removeFromSuperlayer()
        playerLayer = nil

        containerView?.removeFromSuperview()
        containerView = nil

        pipController = nil
        isPiPActive = false
        currentUrl = nil
        pendingResult = nil
    }

    private func getCurrentPosition() -> Double {
        guard let player = avPlayer else { return 0.0 }
        let time = player.currentTime()
        return time.isValid ? CMTimeGetSeconds(time) : 0.0
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
        print("[PiPManager] Failed to start PiP: \(error)")
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
