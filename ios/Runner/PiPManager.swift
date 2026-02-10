import AVKit
import AVFoundation
import Flutter

/// Manages Picture-in-Picture using a native AVPlayer + AVPlayerLayer for iOS.
/// The AVPlayerLayer must be properly sized and on-screen for iOS to create the PiP window.
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
    private var statusObservation: NSKeyValueObservation?

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

        // Create AVPlayerLayer with a PROPER size — iOS requires a real-sized layer
        // to render video frames for PiP
        let layer = AVPlayerLayer(player: player)
        layer.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        layer.videoGravity = .resizeAspect
        playerLayer = layer

        // Container view: on-screen, small but properly sized
        // Positioned at bottom-right corner, will be hidden once PiP starts
        guard let window = getKeyWindow() else {
            result(FlutterError(code: "NO_WINDOW", message: "No key window", details: nil))
            cleanupNativePlayer()
            return
        }

        let screenBounds = window.bounds
        let container = UIView(frame: CGRect(
            x: screenBounds.width - 322,
            y: screenBounds.height - 182,
            width: 320,
            height: 180
        ))
        container.clipsToBounds = true
        // Semi-transparent so it's barely visible but iOS considers it "on screen"
        container.alpha = 0.01
        container.layer.addSublayer(layer)
        containerView = container
        window.addSubview(container)

        // Start playback immediately
        player.play()

        // Create PiP controller from the properly-sized layer
        guard let pipCtrl = AVPictureInPictureController(playerLayer: layer) else {
            result(FlutterError(code: "PIP_FAILED", message: "Could not create PiP controller", details: nil))
            cleanupNativePlayer()
            return
        }
        pipCtrl.delegate = self
        pipController = pipCtrl

        // Use KVO to observe when the player item is ready to play
        pendingResult = result
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.statusObservation?.invalidate()
                    self.statusObservation = nil
                    self.attemptStartPiP(pipCtrl: pipCtrl)

                case .failed:
                    self.statusObservation?.invalidate()
                    self.statusObservation = nil
                    if let pending = self.pendingResult {
                        self.pendingResult = nil
                        pending(FlutterError(
                            code: "PLAYER_FAILED",
                            message: item.error?.localizedDescription ?? "Player failed",
                            details: nil
                        ))
                    }
                    self.cleanupNativePlayer()

                default:
                    break
                }
            }
        }

        // Timeout: if not ready after 10 seconds, fail
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, let pending = self.pendingResult else { return }
            self.pendingResult = nil
            self.statusObservation?.invalidate()
            self.statusObservation = nil
            pending(FlutterError(code: "TIMEOUT", message: "Player not ready after 10s", details: nil))
            self.cleanupNativePlayer()
        }
    }

    private func attemptStartPiP(pipCtrl: AVPictureInPictureController) {
        // Try to start PiP — may need a short delay for the layer to render a frame
        if pipCtrl.isPictureInPicturePossible {
            pipCtrl.startPictureInPicture()
            if let pending = pendingResult {
                pendingResult = nil
                pending(true)
            }
        } else {
            // Retry after a short delay (layer may need a moment to render)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if pipCtrl.isPictureInPicturePossible {
                    pipCtrl.startPictureInPicture()
                    if let pending = self.pendingResult {
                        self.pendingResult = nil
                        pending(true)
                    }
                } else {
                    // One more retry after 1.5s total
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self else { return }
                        if pipCtrl.isPictureInPicturePossible {
                            pipCtrl.startPictureInPicture()
                            if let pending = self.pendingResult {
                                self.pendingResult = nil
                                pending(true)
                            }
                        } else {
                            if let pending = self.pendingResult {
                                self.pendingResult = nil
                                pending(FlutterError(
                                    code: "PIP_FAILED",
                                    message: "PiP not possible after retries",
                                    details: nil
                                ))
                            }
                            self.cleanupNativePlayer()
                        }
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
        statusObservation?.invalidate()
        statusObservation = nil

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
        // Once PiP starts, make the container fully invisible
        containerView?.alpha = 0.0
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
