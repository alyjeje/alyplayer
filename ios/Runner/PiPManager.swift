import AVKit
import AVFoundation
import Flutter

/// Manages Picture-in-Picture using a native AVPlayer + AVPlayerLayer for iOS.
/// The AVPlayerLayer must be properly sized and visible for iOS to render PiP frames.
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
    private var possibleObservation: NSKeyValueObservation?

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

    /// Configure audio session for background playback.
    /// Called both at app launch and before PiP.
    static func configureAudioSession() {
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
        PiPManager.configureAudioSession()
        currentUrl = url

        // Create AVPlayer
        guard let videoURL = URL(string: url) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid URL", details: nil))
            return
        }

        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        player.allowsExternalPlayback = true
        avPlayer = player

        // Seek to position for VOD
        if positionSeconds > 0 {
            player.seek(to: CMTime(seconds: positionSeconds, preferredTimescale: 1000))
        }

        // Create AVPlayerLayer with proper size — iOS REQUIRES the layer to be
        // visible and rendering frames for PiP to show a window
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        playerLayer = layer

        guard let window = getKeyWindow() else {
            result(FlutterError(code: "NO_WINDOW", message: "No key window", details: nil))
            cleanupNativePlayer()
            return
        }

        // Container: full screen size, inserted BEHIND the Flutter view
        // so it's not visible to the user, but iOS still renders the layer
        let screenBounds = window.bounds
        let container = UIView(frame: screenBounds)
        container.backgroundColor = .black
        layer.frame = container.bounds
        container.layer.addSublayer(layer)
        containerView = container

        // Insert at index 0 = behind Flutter's view
        window.insertSubview(container, at: 0)

        // Start playback
        player.play()

        // Create PiP controller
        guard let pipCtrl = AVPictureInPictureController(playerLayer: layer) else {
            result(FlutterError(code: "PIP_FAILED", message: "Could not create PiP controller", details: nil))
            cleanupNativePlayer()
            return
        }
        pipCtrl.delegate = self

        // Enable automatic PiP when app goes to background (iOS 14.2+)
        if #available(iOS 14.2, *) {
            pipCtrl.canStartPictureInPictureAutomaticallyFromInline = true
        }

        pipController = pipCtrl
        pendingResult = result

        // Wait for player item to be ready, then start PiP
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.statusObservation?.invalidate()
                    self.statusObservation = nil
                    // Bring container to front so layer renders visible frames
                    window.bringSubviewToFront(container)
                    self.waitForPiPPossibleThenStart(pipCtrl: pipCtrl)

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
            self.possibleObservation?.invalidate()
            self.possibleObservation = nil
            pending(FlutterError(code: "TIMEOUT", message: "Player not ready after 10s", details: nil))
            self.cleanupNativePlayer()
        }
    }

    /// Use KVO on isPictureInPicturePossible to know exactly when we can start PiP
    private func waitForPiPPossibleThenStart(pipCtrl: AVPictureInPictureController) {
        if pipCtrl.isPictureInPicturePossible {
            startPiPNow(pipCtrl: pipCtrl)
            return
        }

        // Observe isPictureInPicturePossible
        possibleObservation = pipCtrl.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] ctrl, change in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if ctrl.isPictureInPicturePossible {
                    self.possibleObservation?.invalidate()
                    self.possibleObservation = nil
                    self.startPiPNow(pipCtrl: ctrl)
                }
            }
        }
    }

    private func startPiPNow(pipCtrl: AVPictureInPictureController) {
        pipCtrl.startPictureInPicture()
        if let pending = pendingResult {
            pendingResult = nil
            pending(true)
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
        possibleObservation?.invalidate()
        possibleObservation = nil

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
        // PiP window is now taking over — hide the container
        containerView?.isHidden = true
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
