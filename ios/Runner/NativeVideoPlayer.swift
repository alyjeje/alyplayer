import AVKit
import AVFoundation
import Flutter

/// Native iOS video player using AVPlayerViewController.
/// PiP, AirPlay, subtitles, and audio tracks are all handled natively by Apple.
/// This replaces the media_kit + PiP hack approach on iOS.
class NativeVideoPlayer: NSObject {
    static let shared = NativeVideoPlayer()

    private var methodChannel: FlutterMethodChannel?
    private weak var rootVC: UIViewController?
    private var playerVC: AVPlayerViewController?
    private var player: AVPlayer?
    private var dismissCheckTimer: Timer?
    private var _isPiPActive = false

    private override init() {
        super.init()
    }

    func register(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.alyplayer/native_player",
            binaryMessenger: messenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "presentPlayer":
                guard let args = call.arguments as? [String: Any],
                      let url = args["url"] as? String else {
                    result(FlutterError(code: "ARGS", message: "Missing url", details: nil))
                    return
                }
                self.presentPlayer(
                    url: url,
                    title: args["title"] as? String,
                    positionSeconds: args["positionSeconds"] as? Double ?? 0,
                    result: result
                )

            case "dismissPlayer":
                self.dismissPlayer(result: result)

            case "getPosition":
                result(self.getCurrentPosition())

            case "isPresented":
                result(self.playerVC?.presentingViewController != nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func setRootViewController(_ vc: UIViewController) {
        rootVC = vc
    }

    // MARK: - Present Player

    private func presentPlayer(url: String, title: String?, positionSeconds: Double, result: @escaping FlutterResult) {
        print("[NativePlayer] presentPlayer: \(url.prefix(80))...")

        guard let videoURL = URL(string: url) else {
            result(FlutterError(code: "URL", message: "Invalid URL: \(url)", details: nil))
            return
        }

        // Clean up any previous session
        cleanup()

        // Configure audio for background playback
        PiPManager.configureAudioSession()

        // Create AVPlayer
        let item = AVPlayerItem(asset: AVURLAsset(url: videoURL))
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.allowsExternalPlayback = true
        player = avPlayer

        // Seek to position (for VOD resume)
        if positionSeconds > 0 {
            avPlayer.seek(to: CMTime(seconds: positionSeconds, preferredTimescale: 1000))
        }

        // Set title metadata (shows in PiP and Now Playing)
        if let title = title {
            let meta = AVMutableMetadataItem()
            meta.identifier = .commonIdentifierTitle
            meta.value = title as NSString
            item.externalMetadata = [meta]
        }

        // Create AVPlayerViewController
        let vc = AVPlayerViewController()
        vc.player = avPlayer
        vc.allowsPictureInPicturePlayback = true
        vc.delegate = self

        // Auto-PiP when app goes to background
        if #available(iOS 14.2, *) {
            vc.canStartPictureInPictureAutomaticallyFromInline = true
        }

        // Disable Live Text analysis for performance
        if #available(iOS 16.0, *) {
            vc.allowsVideoFrameAnalysis = false
        }

        playerVC = vc

        // Present full-screen from Flutter's root VC
        guard let root = rootVC else {
            result(FlutterError(code: "VC", message: "No root view controller", details: nil))
            return
        }

        vc.modalPresentationStyle = .fullScreen
        root.present(vc, animated: true) {
            avPlayer.play()
            print("[NativePlayer] Player presented and playing")
            result(true)
        }

        // Monitor for dismissal (when user taps Done)
        startDismissMonitor()
    }

    // MARK: - Dismiss

    private func dismissPlayer(result: @escaping FlutterResult) {
        let position = getCurrentPosition()
        print("[NativePlayer] dismissPlayer at position: \(position)")
        if let vc = playerVC, vc.presentingViewController != nil {
            vc.dismiss(animated: true) { [weak self] in
                self?.cleanup()
            }
        } else {
            cleanup()
        }
        result(["positionSeconds": position])
    }

    // MARK: - Dismiss Monitor

    /// Periodically checks if the native player was dismissed (user tapped Done).
    /// AVPlayerViewController doesn't provide a direct dismissal delegate for modal presentations.
    private func startDismissMonitor() {
        dismissCheckTimer?.invalidate()
        dismissCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // If playerVC exists but is no longer presented, it was dismissed
            if let vc = self.playerVC, vc.presentingViewController == nil, !self.isPiPActive() {
                print("[NativePlayer] Player was dismissed by user")
                self.dismissCheckTimer?.invalidate()
                self.dismissCheckTimer = nil
                let position = self.getCurrentPosition()
                self.methodChannel?.invokeMethod("onDismissed", arguments: [
                    "positionSeconds": position
                ])
                self.cleanup()
            }
        }
    }

    private func isPiPActive() -> Bool {
        return _isPiPActive
    }

    // MARK: - Helpers

    private func getCurrentPosition() -> Double {
        guard let p = player else { return 0 }
        let t = p.currentTime()
        return t.isValid ? CMTimeGetSeconds(t) : 0
    }

    private func cleanup() {
        print("[NativePlayer] cleanup")
        dismissCheckTimer?.invalidate()
        dismissCheckTimer = nil
        _isPiPActive = false
        player?.pause()
        player = nil
        playerVC = nil
    }
}

// MARK: - AVPlayerViewControllerDelegate

extension NativeVideoPlayer: AVPlayerViewControllerDelegate {

    func playerViewControllerWillStartPictureInPicture(
        _ playerViewController: AVPlayerViewController
    ) {
        print("[NativePlayer] PiP will start")
        _isPiPActive = true
        // Stop dismiss monitor during PiP (the modal gets dismissed but player continues)
        dismissCheckTimer?.invalidate()
        dismissCheckTimer = nil
        methodChannel?.invokeMethod("onPiPStarted", arguments: nil)
    }

    func playerViewControllerDidStartPictureInPicture(
        _ playerViewController: AVPlayerViewController
    ) {
        print("[NativePlayer] PiP started")
    }

    func playerViewControllerDidStopPictureInPicture(
        _ playerViewController: AVPlayerViewController
    ) {
        print("[NativePlayer] PiP stopped")
        _isPiPActive = false
        let position = getCurrentPosition()
        methodChannel?.invokeMethod("onPiPStopped", arguments: [
            "positionSeconds": position
        ])
        // If the player VC is not presented (user closed PiP without restoring), clean up
        if playerViewController.presentingViewController == nil {
            cleanup()
        } else {
            // Player is still presented, restart dismiss monitor
            startDismissMonitor()
        }
    }

    func playerViewControllerFailedToStartPictureInPicture(
        _ playerViewController: AVPlayerViewController,
        withError error: Error
    ) {
        print("[NativePlayer] PiP failed: \(error)")
        methodChannel?.invokeMethod("onPiPError", arguments: [
            "error": error.localizedDescription
        ])
        // Restart dismiss monitor since PiP didn't work
        startDismissMonitor()
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        print("[NativePlayer] Restoring UI from PiP")
        guard let root = rootVC else {
            completionHandler(false)
            return
        }

        // Re-present the player full-screen when coming back from PiP
        if playerViewController.presentingViewController == nil {
            root.present(playerViewController, animated: true) { [weak self] in
                self?.startDismissMonitor()
                completionHandler(true)
            }
        } else {
            startDismissMonitor()
            completionHandler(true)
        }
    }

    /// Automatically dismiss the full-screen player when PiP starts
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
        _ playerViewController: AVPlayerViewController
    ) -> Bool {
        return true
    }
}
