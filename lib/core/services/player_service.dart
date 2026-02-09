/// Player state management service wrapping media_kit.
///
/// Provides a high-level API for playing channels, managing playback state,
/// tracking channel history, and handling auto-retry on stream errors.
library;

import 'dart:async';
import 'dart:collection';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:aly_player/core/database/database.dart';
import 'package:aly_player/core/models/dtos.dart';
import 'package:aly_player/core/services/pip_service.dart';

/// Service that wraps a media_kit [Player] and [VideoController], exposing a
/// simplified, reactive API for the UI layer.
class PlayerService {
  PlayerService({AppDatabase? database}) : _db = database {
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024, // 32 MB buffer for live streams
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController = VideoController(_player);
    _subscribeToPlayerStreams();
  }

  final AppDatabase? _db;
  final PiPService _pipService = PiPService();

  late final Player _player;
  late final VideoController _videoController;

  // ── State ─────────────────────────────────────────────────

  /// The channel currently loaded in the player (or `null` if idle).
  Channel? _currentChannel;
  Channel? get currentChannel => _currentChannel;

  /// The previously played channel, enabling quick-switch (e.g. "last channel"
  /// button on a remote).
  Channel? _previousChannel;
  Channel? get previousChannel => _previousChannel;

  /// Current discrete player state.
  AppPlayerState _playerState = AppPlayerState.idle;
  AppPlayerState get playerState => _playerState;

  /// Broadcast controller so the UI can react to state changes.
  final _stateController = StreamController<AppPlayerState>.broadcast();
  Stream<AppPlayerState> get stateStream => _stateController.stream;

  /// The underlying media_kit [VideoController] the UI should attach to a
  /// `Video` widget.
  VideoController get videoController => _videoController;

  /// The underlying media_kit [Player], exposed for advanced use cases.
  Player get player => _player;

  // ── Channel history ───────────────────────────────────────

  /// Maximum number of channels kept in history.
  static const _maxHistorySize = 50;

  final _history = Queue<Channel>();

  /// Unmodifiable view of the channel history (most recent first).
  List<Channel> get history => _history.toList();

  // ── Retry logic ───────────────────────────────────────────

  static const _maxRetryAttempts = 3;
  int _retryCount = 0;
  Timer? _retryTimer;

  // ── Stream subscriptions ──────────────────────────────────

  final _subscriptions = <StreamSubscription<dynamic>>[];

  // ── Public API ────────────────────────────────────────────

  /// Starts playing the given [channel].
  ///
  /// If a channel is already playing, it is saved as [previousChannel] for
  /// quick-switch and added to the history.
  Future<void> play(Channel channel) async {
    // Save current as previous.
    if (_currentChannel != null) {
      _previousChannel = _currentChannel;
    }

    _currentChannel = channel;
    _retryCount = 0;
    _retryTimer?.cancel();

    _addToHistory(channel);
    _setState(AppPlayerState.loading);

    await _player.open(Media(
      channel.streamUrl,
      httpHeaders: {
        'User-Agent': 'AlyPlayer/1.0',
        'Connection': 'keep-alive',
      },
    ));

    // Update last-watched timestamp in the database.
    _db?.updateLastWatched(channel.id);
  }

  /// Stops playback and resets state to idle.
  Future<void> stop() async {
    _retryTimer?.cancel();
    _retryCount = 0;
    await _player.stop();
    _currentChannel = null;
    _setState(AppPlayerState.idle);
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() async {
    await _player.playOrPause();
  }

  /// Quickly switches to the [previousChannel].
  ///
  /// If there is no previous channel, this method is a no-op.
  Future<void> quickSwitch() async {
    final prev = _previousChannel;
    if (prev == null) return;
    await play(prev);
  }

  /// Seeks to the given [position] within the current media.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Seeks forward by [seconds] from the current position.
  Future<void> seekForward([int seconds = 10]) async {
    final current = _player.state.position;
    final duration = _player.state.duration;
    final target = current + Duration(seconds: seconds);
    await _player.seek(target > duration ? duration : target);
  }

  /// Seeks backward by [seconds] from the current position.
  Future<void> seekBackward([int seconds = 10]) async {
    final current = _player.state.position;
    final target = current - Duration(seconds: seconds);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  /// Returns the list of available subtitle tracks.
  List<SubtitleTrack> get subtitleTracks => _player.state.tracks.subtitle;

  /// Sets the active subtitle track.
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
  }

  /// Disables subtitles.
  Future<void> disableSubtitles() async {
    await _player.setSubtitleTrack(SubtitleTrack.no());
  }

  /// Returns the list of available audio tracks.
  List<AudioTrack> get audioTracks => _player.state.tracks.audio;

  /// Sets the active audio track.
  Future<void> setAudioTrack(AudioTrack track) async {
    await _player.setAudioTrack(track);
  }

  /// Sets the playback speed [rate] (e.g. 1.0 for normal, 2.0 for double).
  Future<void> setRate(double rate) async {
    await _player.setRate(rate);
  }

  /// Whether PiP is supported on this device.
  Future<bool> get isPiPSupported => _pipService.isSupported;

  /// Activate Picture-in-Picture mode.
  ///
  /// Pauses media_kit, hands the stream URL to native AVPlayer for PiP,
  /// and resumes media_kit when PiP ends.
  Future<bool> startPiP() async {
    final channel = _currentChannel;
    if (channel == null) return false;

    final position = _player.state.position.inMilliseconds / 1000.0;

    _pipService.onPiPStarted = () {
      _player.pause();
    };

    _pipService.onPiPStopped = (positionSeconds) {
      final resumePosition = Duration(
        milliseconds: (positionSeconds * 1000).round(),
      );
      _player.seek(resumePosition);
      _player.play();
    };

    _pipService.onPiPRestoreUI = (positionSeconds) {
      final resumePosition = Duration(
        milliseconds: (positionSeconds * 1000).round(),
      );
      _player.seek(resumePosition);
      _player.play();
    };

    _pipService.onPiPError = (_) {
      _player.play();
    };

    return _pipService.startPiP(
      url: channel.streamUrl,
      positionSeconds: position,
      headers: {
        'User-Agent': 'AlyPlayer/1.0',
        'Connection': 'keep-alive',
      },
    );
  }

  /// Stop Picture-in-Picture mode.
  Future<void> stopPiP() async {
    await _pipService.stopPiP();
  }

  /// Releases all resources held by this service.
  ///
  /// After calling dispose, this instance must not be used again.
  Future<void> dispose() async {
    _retryTimer?.cancel();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _pipService.dispose();
    await _stateController.close();
    await _player.dispose();
  }

  // ── Private helpers ────────────────────────────────────────

  void _setState(AppPlayerState state) {
    _playerState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _addToHistory(Channel channel) {
    // Remove duplicate if already present so it moves to front.
    _history.removeWhere((c) => c.id == channel.id);
    _history.addFirst(channel);

    // Trim to maximum size.
    while (_history.length > _maxHistorySize) {
      _history.removeLast();
    }
  }

  /// Subscribes to media_kit player streams to map them to our [AppPlayerState].
  void _subscribeToPlayerStreams() {
    // Playing state.
    _subscriptions.add(
      _player.stream.playing.listen((isPlaying) {
        if (isPlaying) {
          _retryCount = 0; // reset on successful playback
          _setState(AppPlayerState.playing);
        } else if (_playerState == AppPlayerState.playing) {
          _setState(AppPlayerState.paused);
        }
      }),
    );

    // Buffering state.
    _subscriptions.add(
      _player.stream.buffering.listen((isBuffering) {
        if (isBuffering && _playerState != AppPlayerState.idle) {
          _setState(AppPlayerState.loading);
        }
      }),
    );

    // Completed -- stream ended.
    _subscriptions.add(
      _player.stream.completed.listen((isCompleted) {
        if (isCompleted) {
          _setState(AppPlayerState.idle);
        }
      }),
    );

    // Error handling with auto-retry.
    _subscriptions.add(
      _player.stream.error.listen((error) {
        _handlePlaybackError(error);
      }),
    );
  }

  /// Handles a playback error by attempting automatic retry with exponential
  /// backoff, up to [_maxRetryAttempts].
  void _handlePlaybackError(String error) {
    if (_currentChannel == null) {
      _setState(AppPlayerState.error);
      return;
    }

    _retryCount++;

    if (_retryCount > _maxRetryAttempts) {
      _setState(AppPlayerState.failed);
      return;
    }

    _setState(AppPlayerState.error);

    // Exponential backoff: 1s, 2s, 4s.
    final delay = Duration(seconds: 1 << (_retryCount - 1));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      final channel = _currentChannel;
      if (channel != null && _playerState != AppPlayerState.failed) {
        _setState(AppPlayerState.loading);
        _player.open(Media(
          channel.streamUrl,
          httpHeaders: {
            'User-Agent': 'AlyPlayer/1.0',
            'Connection': 'keep-alive',
          },
        ));
      }
    });
  }
}
