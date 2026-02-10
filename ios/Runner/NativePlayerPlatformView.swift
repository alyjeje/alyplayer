import Flutter
import AVKit
import AVFoundation

/// Inline AVPlayerViewController embedded as a FlutterPlatformView.
/// PiP works because the player is inline (not modal).
/// Flutter controls overlay on top (showsPlaybackControls = false).
class NativePlayerPlatformView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private let playerVC: AVPlayerViewController
    private var player: AVPlayer?
    private let channel: FlutterMethodChannel

    // PiP state
    private var _isPiPActive = false

    // Observers
    private var periodicTimeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var itemBufferObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?

    // URL fallback
    private var currentURL: String?
    private var fallbackURL: String?
    private var currentHeaders: [String: String] = [:]
    private var currentTitle: String?
    private var hasTriedFallback = false

    // Default UA — VLC-like so IPTV servers don't block
    private static let defaultUserAgent = "VLC/3.0.20 LibVLC/3.0.20"

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: [String: Any]?,
        messenger: FlutterBinaryMessenger
    ) {
        containerView = UIView(frame: frame)
        containerView.backgroundColor = .black

        playerVC = AVPlayerViewController()
        playerVC.allowsPictureInPicturePlayback = true
        playerVC.showsPlaybackControls = false  // Flutter handles UI

        if #available(iOS 14.2, *) {
            playerVC.canStartPictureInPictureAutomaticallyFromInline = true
        }
        if #available(iOS 16.0, *) {
            playerVC.allowsVideoFrameAnalysis = false
        }

        channel = FlutterMethodChannel(
            name: "com.alyplayer/native_player_view_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        playerVC.delegate = self

        // Embed playerVC's view inside container
        playerVC.view.frame = containerView.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(playerVC.view)

        // Add playerVC as child of root VC (required for PiP to work)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let rootVC = self.findRootViewController() {
                rootVC.addChild(self.playerVC)
                self.playerVC.didMove(toParent: rootVC)
            }
        }

        configureAudioSession()

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    func view() -> UIView {
        return containerView
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("[NativePlayerView] Audio session error: \(error)")
        }
    }

    // MARK: - Root VC

    private func findRootViewController() -> UIViewController? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }

    // MARK: - Method Call Handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String else {
                result(FlutterError(code: "ARGS", message: "Missing url", details: nil))
                return
            }
            let headers = args["headers"] as? [String: String] ?? [:]
            let title = args["title"] as? String
            let position = args["positionSeconds"] as? Double ?? 0
            let fallback = args["fallbackUrl"] as? String
            play(
                url: url,
                headers: headers,
                title: title,
                positionSeconds: position,
                fallbackUrl: fallback,
                result: result
            )

        case "pause":
            player?.pause()
            result(nil)

        case "resume":
            player?.play()
            result(nil)

        case "seek":
            guard let args = call.arguments as? [String: Any],
                  let seconds = args["positionSeconds"] as? Double else {
                result(FlutterError(code: "ARGS", message: "Missing positionSeconds", details: nil))
                return
            }
            let time = CMTime(seconds: seconds, preferredTimescale: 1000)
            player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            result(nil)

        case "getPosition":
            result(getCurrentPosition())

        case "getDuration":
            result(getCurrentDuration())

        case "setPlaybackSpeed":
            guard let args = call.arguments as? [String: Any],
                  let rate = args["rate"] as? Double else {
                result(FlutterError(code: "ARGS", message: "Missing rate", details: nil))
                return
            }
            player?.rate = Float(rate)
            result(nil)

        case "getSubtitleTracks":
            result(getMediaSelectionTracks(for: .legible))

        case "setSubtitleTrack":
            let args = call.arguments as? [String: Any]
            let index = args?["index"] as? Int
            setMediaSelectionTrack(for: .legible, index: index)
            result(nil)

        case "getAudioTracks":
            result(getMediaSelectionTracks(for: .audible))

        case "setAudioTrack":
            guard let args = call.arguments as? [String: Any],
                  let index = args["index"] as? Int else {
                result(FlutterError(code: "ARGS", message: "Missing index", details: nil))
                return
            }
            setMediaSelectionTrack(for: .audible, index: index)
            result(nil)

        case "dispose":
            cleanup()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Playback

    private func play(
        url: String,
        headers: [String: String],
        title: String?,
        positionSeconds: Double,
        fallbackUrl: String?,
        result: @escaping FlutterResult
    ) {
        print("[NativePlayerView] play: \(url.prefix(100))...")

        guard let videoURL = URL(string: url) else {
            result(FlutterError(code: "URL", message: "Invalid URL", details: nil))
            return
        }

        // Clean up any previous session
        cleanupPlayer()
        configureAudioSession()

        currentURL = url
        fallbackURL = fallbackUrl
        currentHeaders = headers
        currentTitle = title
        hasTriedFallback = false

        // Build effective headers
        var effectiveHeaders = headers
        if effectiveHeaders["User-Agent"] == nil {
            effectiveHeaders["User-Agent"] = NativePlayerPlatformView.defaultUserAgent
        }

        loadAndPlay(
            url: videoURL,
            headers: effectiveHeaders,
            title: title,
            positionSeconds: positionSeconds,
            isFallback: false
        )

        result(true)
    }

    private func loadAndPlay(
        url: URL,
        headers: [String: String],
        title: String?,
        positionSeconds: Double,
        isFallback: Bool
    ) {
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ])
        let item = AVPlayerItem(asset: asset)

        // Title metadata (shows in PiP and Now Playing)
        if let title = title {
            let meta = AVMutableMetadataItem()
            meta.identifier = .commonIdentifierTitle
            meta.value = title as NSString
            item.externalMetadata = [meta]
        }

        if let existingPlayer = player {
            // Replace item on existing player
            existingPlayer.replaceCurrentItem(with: item)
        } else {
            let avPlayer = AVPlayer(playerItem: item)
            avPlayer.allowsExternalPlayback = true
            player = avPlayer
            playerVC.player = avPlayer
        }

        // Observe item status
        itemStatusObserver?.invalidate()
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            DispatchQueue.main.async {
                self?.handleItemStatus(observedItem, isFallback: isFallback)
            }
        }

        // Observe buffering
        itemBufferObserver?.invalidate()
        itemBufferObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] observedItem, _ in
            DispatchQueue.main.async {
                self?.channel.invokeMethod("onBufferingChanged", arguments: [
                    "isBuffering": !observedItem.isPlaybackLikelyToKeepUp
                ])
            }
        }

        // Observe rate (play/pause)
        rateObserver?.invalidate()
        rateObserver = player?.observe(\.rate, options: [.new]) { [weak self] observedPlayer, _ in
            DispatchQueue.main.async {
                self?.channel.invokeMethod("onPlaybackStateChanged", arguments: [
                    "isPlaying": observedPlayer.rate > 0
                ])
            }
        }

        // Periodic time observer (every 500ms)
        if let observer = periodicTimeObserver {
            player?.removeTimeObserver(observer)
        }
        periodicTimeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self, time.isValid else { return }
            self.channel.invokeMethod("onPositionChanged", arguments: [
                "positionSeconds": CMTimeGetSeconds(time),
                "durationSeconds": self.getCurrentDuration(),
            ])
        }

        // Seek to position
        if positionSeconds > 0 {
            player?.seek(to: CMTime(seconds: positionSeconds, preferredTimescale: 1000))
        }

        player?.play()
    }

    // MARK: - Status Handling

    private func handleItemStatus(_ item: AVPlayerItem, isFallback: Bool) {
        switch item.status {
        case .readyToPlay:
            print("[NativePlayerView] \(isFallback ? "Fallback r" : "R")eady to play")
            channel.invokeMethod("onReady", arguments: [
                "durationSeconds": getCurrentDuration()
            ])
            sendTracksInfo()

        case .failed:
            let errorMsg = item.error?.localizedDescription ?? "Unknown playback error"
            print("[NativePlayerView] \(isFallback ? "Fallback f" : "F")ailed: \(errorMsg)")

            if !isFallback && !hasTriedFallback, let fallback = fallbackURL, let fallbackURL = URL(string: fallback) {
                // Try fallback URL
                print("[NativePlayerView] Trying fallback: \(fallback.prefix(100))...")
                hasTriedFallback = true

                var effectiveHeaders = currentHeaders
                if effectiveHeaders["User-Agent"] == nil {
                    effectiveHeaders["User-Agent"] = NativePlayerPlatformView.defaultUserAgent
                }

                loadAndPlay(
                    url: fallbackURL,
                    headers: effectiveHeaders,
                    title: currentTitle,
                    positionSeconds: 0,
                    isFallback: true
                )
            } else {
                // Both failed — tell Flutter to fall back to media_kit
                channel.invokeMethod("onError", arguments: [
                    "error": errorMsg,
                    "needsFallback": true
                ])
            }

        default:
            break
        }
    }

    // MARK: - Track Selection

    private func sendTracksInfo() {
        let subtitles = getMediaSelectionTracks(for: .legible)
        let audioTracks = getMediaSelectionTracks(for: .audible)
        channel.invokeMethod("onTracksChanged", arguments: [
            "subtitles": subtitles,
            "audioTracks": audioTracks,
        ])
    }

    private func getMediaSelectionTracks(for characteristic: AVMediaCharacteristic) -> [[String: Any]] {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else {
            return []
        }
        return group.options.enumerated().map { (index, option) in
            [
                "index": index,
                "title": option.displayName,
                "language": option.locale?.languageCode ?? "",
            ]
        }
    }

    private func setMediaSelectionTrack(for characteristic: AVMediaCharacteristic, index: Int?) {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else {
            return
        }
        if let index = index, index >= 0, index < group.options.count {
            item.select(group.options[index], in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    // MARK: - Helpers

    private func getCurrentPosition() -> Double {
        guard let p = player, p.currentTime().isValid else { return 0 }
        return CMTimeGetSeconds(p.currentTime())
    }

    private func getCurrentDuration() -> Double {
        guard let item = player?.currentItem else { return 0 }
        let dur = item.duration
        return dur.isValid && !dur.isIndefinite ? CMTimeGetSeconds(dur) : 0
    }

    private func cleanupPlayer() {
        if let observer = periodicTimeObserver {
            player?.removeTimeObserver(observer)
            periodicTimeObserver = nil
        }
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemBufferObserver?.invalidate()
        itemBufferObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil
        _isPiPActive = false
        player?.pause()
        playerVC.player = nil
        player = nil
    }

    private func cleanup() {
        cleanupPlayer()
        channel.setMethodCallHandler(nil)
        playerVC.willMove(toParent: nil)
        playerVC.view.removeFromSuperview()
        playerVC.removeFromParent()
    }

    deinit {
        cleanup()
    }
}

// MARK: - AVPlayerViewControllerDelegate (PiP)

extension NativePlayerPlatformView: AVPlayerViewControllerDelegate {

    func playerViewControllerWillStartPictureInPicture(
        _ playerViewController: AVPlayerViewController
    ) {
        print("[NativePlayerView] PiP starting")
        _isPiPActive = true
        channel.invokeMethod("onPiPChanged", arguments: ["isActive": true])
    }

    func playerViewControllerDidStopPictureInPicture(
        _ playerViewController: AVPlayerViewController
    ) {
        print("[NativePlayerView] PiP stopped")
        _isPiPActive = false
        channel.invokeMethod("onPiPChanged", arguments: ["isActive": false])
    }

    func playerViewControllerFailedToStartPictureInPicture(
        _ playerViewController: AVPlayerViewController,
        withError error: Error
    ) {
        print("[NativePlayerView] PiP failed: \(error)")
        channel.invokeMethod("onPiPChanged", arguments: [
            "isActive": false,
            "error": error.localizedDescription,
        ])
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        print("[NativePlayerView] Restoring UI from PiP")
        channel.invokeMethod("onPiPRestoreUI", arguments: nil)
        completionHandler(true)
    }
}
