import AVKit
import AVFoundation
import Flutter

/// Manages Picture-in-Picture using a native AVPlayer + AVPlayerLayer for iOS.
///
/// Key rules for iOS PiP to work:
/// - AVPlayerLayer must be ON TOP of Flutter (not behind, not hidden)
/// - alpha must be 1.0 (not 0.01, not 0)
/// - isHidden must be false
/// - frame must be on-screen (no negative x/y)
/// - layer must have non-zero size
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
    /// Called at app launch and before PiP.
    static func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
            print("[PiPManager] Audio session configured OK")
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
        print("[PiPManager] startPiP called with url: \(url.prefix(80))...")

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("[PiPManager] PiP not supported on this device")
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

        // Create AVPlayerLayer
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        playerLayer = layer

        guard let window = getKeyWindow() else {
            print("[PiPManager] No key window found!")
            result(FlutterError(code: "NO_WINDOW", message: "No key window", details: nil))
            cleanupNativePlayer()
            return
        }

        // CRITICAL: Container must be ON TOP of Flutter, visible, on-screen, alpha=1
        // 1x1 pixel in top-left corner — user won't see it but iOS renders the layer
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        container.clipsToBounds = true
        container.backgroundColor = .clear
        container.isHidden = false
        container.alpha = 1.0
        layer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        container.layer.addSublayer(layer)
        containerView = container

        // addSubview = ON TOP of all existing subviews (including Flutter)
        window.addSubview(container)
        print("[PiPManager] Container added ON TOP of window at (0,0) 1x1")

        // Start playback
        player.play()

        // Create PiP controller from the layer
        guard let pipCtrl = AVPictureInPictureController(playerLayer: layer) else {
            print("[PiPManager] Failed to create AVPictureInPictureController")
            result(FlutterError(code: "PIP_FAILED", message: "Could not create PiP controller", details: nil))
            cleanupNativePlayer()
            return
        }
        pipCtrl.delegate = self

        // Enable automatic PiP when app goes to background (iOS 14.2+)
        if #available(iOS 14.2, *) {
            pipCtrl.canStartPictureInPictureAutomaticallyFromInline = true
            print("[PiPManager] canStartPictureInPictureAutomaticallyFromInline = true")
        }

        pipController = pipCtrl
        pendingResult = result

        // KVO: wait for player item readyToPlay
        statusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                print("[PiPManager] AVPlayerItem status: \(item.status.rawValue) (0=unknown, 1=ready, 2=failed)")

                switch item.status {
                case .readyToPlay:
                    self.statusObservation?.invalidate()
                    self.statusObservation = nil
                    print("[PiPManager] Player ready! Tracks: \(item.tracks.count)")
                    for track in item.tracks {
                        print("[PiPManager]   Track: \(track.assetTrack?.mediaType.rawValue ?? "unknown")")
                    }
                    print("[PiPManager] isPictureInPicturePossible = \(pipCtrl.isPictureInPicturePossible)")
                    self.waitForPiPPossibleThenStart(pipCtrl: pipCtrl)

                case .failed:
                    self.statusObservation?.invalidate()
                    self.statusObservation = nil
                    print("[PiPManager] Player FAILED: \(item.error?.localizedDescription ?? "unknown")")
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

        // Timeout: 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, let pending = self.pendingResult else { return }
            print("[PiPManager] TIMEOUT: player not ready after 10s")
            self.pendingResult = nil
            self.statusObservation?.invalidate()
            self.statusObservation = nil
            self.possibleObservation?.invalidate()
            self.possibleObservation = nil
            pending(FlutterError(code: "TIMEOUT", message: "Player not ready after 10s", details: nil))
            self.cleanupNativePlayer()
        }
    }

    /// KVO on isPictureInPicturePossible — triggers when iOS is ready for PiP
    private func waitForPiPPossibleThenStart(pipCtrl: AVPictureInPictureController) {
        if pipCtrl.isPictureInPicturePossible {
            print("[PiPManager] PiP possible immediately — starting!")
            startPiPNow(pipCtrl: pipCtrl)
            return
        }

        print("[PiPManager] PiP not yet possible — observing...")
        possibleObservation = pipCtrl.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] ctrl, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                print("[PiPManager] isPictureInPicturePossible changed to: \(ctrl.isPictureInPicturePossible)")
                if ctrl.isPictureInPicturePossible {
                    self.possibleObservation?.invalidate()
                    self.possibleObservation = nil
                    self.startPiPNow(pipCtrl: ctrl)
                }
            }
        }
    }

    private func startPiPNow(pipCtrl: AVPictureInPictureController) {
        print("[PiPManager] Calling startPictureInPicture()!")
        pipCtrl.startPictureInPicture()
        if let pending = pendingResult {
            pendingResult = nil
            pending(true)
        }
    }

    // MARK: - Stop PiP

    private func stopPiP(result: @escaping FlutterResult) {
        print("[PiPManager] stopPiP called")
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
        print("[PiPManager] Cleanup done")
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
        print("[PiPManager] willStartPictureInPicture")
        isPiPActive = true
        methodChannel?.invokeMethod("onPiPStarted", arguments: nil)
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("[PiPManager] didStartPictureInPicture — PiP is now active!")
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("[PiPManager] didStopPictureInPicture")
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
        print("[PiPManager] FAILED to start PiP: \(error)")
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
        print("[PiPManager] restoreUserInterface")
        let position = getCurrentPosition()
        methodChannel?.invokeMethod("onPiPRestoreUI", arguments: [
            "position": position
        ])
        completionHandler(true)
    }
}
