/// Controller for the inline native iOS AVPlayerViewController (UiKitView).
///
/// Communicates with [NativePlayerPlatformView] via a per-instance
/// MethodChannel. Exposes reactive streams so the Flutter controls overlay
/// can bind to playback state, position, buffering, PiP, and track info.
library;

import 'dart:async';

import 'package:flutter/services.dart';

class NativePlayerController {
  MethodChannel? _channel;
  Completer<void>? _viewReadyCompleter;

  // ── State ──────────────────────────────────────────────────
  bool _isPlaying = false;
  bool _isBuffering = true;
  double _position = 0;
  double _duration = 0;
  bool _isPiPActive = false;
  bool _isReady = false;
  List<TrackInfo> _subtitleTracks = [];
  List<TrackInfo> _audioTracks = [];

  // ── Stream controllers ─────────────────────────────────────
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _errorController = StreamController<PlayerError>.broadcast();
  final _pipController = StreamController<bool>.broadcast();
  final _tracksController = StreamController<void>.broadcast();
  final _readyController = StreamController<void>.broadcast();

  // ── Public streams ─────────────────────────────────────────
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<PlayerError> get errorStream => _errorController.stream;
  Stream<bool> get pipStream => _pipController.stream;
  Stream<void> get tracksStream => _tracksController.stream;
  Stream<void> get readyStream => _readyController.stream;

  // ── Public getters ─────────────────────────────────────────
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isReady => _isReady;
  double get positionSeconds => _position;
  double get durationSeconds => _duration;
  Duration get position => Duration(milliseconds: (_position * 1000).round());
  Duration get duration => Duration(milliseconds: (_duration * 1000).round());
  bool get isPiPActive => _isPiPActive;
  List<TrackInfo> get subtitleTracks => _subtitleTracks;
  List<TrackInfo> get audioTracks => _audioTracks;

  // ── Platform view lifecycle ────────────────────────────────

  /// Called by [UiKitView.onPlatformViewCreated].
  void onPlatformViewCreated(int viewId) {
    _channel = MethodChannel('com.alyplayer/native_player_view_$viewId');
    _channel!.setMethodCallHandler(_handleMethodCall);
    // Unblock any pending play() call that was waiting for the view.
    _viewReadyCompleter?.complete();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = call.arguments as Map?;

    switch (call.method) {
      case 'onPlaybackStateChanged':
        _isPlaying = args?['isPlaying'] == true;
        if (!_playingController.isClosed) _playingController.add(_isPlaying);

      case 'onBufferingChanged':
        _isBuffering = args?['isBuffering'] == true;
        if (!_bufferingController.isClosed) {
          _bufferingController.add(_isBuffering);
        }

      case 'onPositionChanged':
        _position = (args?['positionSeconds'] as num?)?.toDouble() ?? 0;
        _duration = (args?['durationSeconds'] as num?)?.toDouble() ?? 0;
        if (!_positionController.isClosed) {
          _positionController.add(position);
        }
        if (!_durationController.isClosed) {
          _durationController.add(duration);
        }

      case 'onReady':
        _isReady = true;
        _isBuffering = false;
        _duration = (args?['durationSeconds'] as num?)?.toDouble() ?? 0;
        if (!_durationController.isClosed) {
          _durationController.add(duration);
        }
        if (!_readyController.isClosed) _readyController.add(null);
        if (!_bufferingController.isClosed) _bufferingController.add(false);

      case 'onError':
        final error = args?['error'] as String? ?? 'Unknown error';
        final needsFallback = args?['needsFallback'] == true;
        if (!_errorController.isClosed) {
          _errorController.add(PlayerError(error, needsFallback: needsFallback));
        }

      case 'onPiPChanged':
        _isPiPActive = args?['isActive'] == true;
        if (!_pipController.isClosed) _pipController.add(_isPiPActive);

      case 'onPiPRestoreUI':
        _isPiPActive = false;
        if (!_pipController.isClosed) _pipController.add(false);

      case 'onTracksChanged':
        _subtitleTracks = _parseTracks(args?['subtitles']);
        _audioTracks = _parseTracks(args?['audioTracks']);
        if (!_tracksController.isClosed) _tracksController.add(null);
    }
  }

  List<TrackInfo> _parseTracks(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      final map = e as Map;
      return TrackInfo(
        index: map['index'] as int,
        title: (map['title'] as String?) ?? '',
        language: (map['language'] as String?) ?? '',
      );
    }).toList();
  }

  // ── Playback commands ──────────────────────────────────────

  /// Start playing a URL. [fallbackUrl] is tried if the primary fails.
  /// If the UiKitView hasn't been created yet, this will wait for it.
  Future<bool> play({
    required String url,
    Map<String, String> headers = const {},
    String? title,
    double positionSeconds = 0,
    String? fallbackUrl,
  }) async {
    _isReady = false;
    _isBuffering = true;
    if (!_bufferingController.isClosed) _bufferingController.add(true);

    // Wait for the platform view to be created if it hasn't been yet.
    if (_channel == null) {
      _viewReadyCompleter = Completer<void>();
      await _viewReadyCompleter!.future;
    }

    try {
      final result = await _channel?.invokeMethod('play', {
        'url': url,
        'headers': headers,
        'title': title,
        'positionSeconds': positionSeconds,
        'fallbackUrl': fallbackUrl,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('[NativePlayerController] play error: ${e.message}');
      return false;
    }
  }

  Future<void> pause() async => _channel?.invokeMethod('pause');

  Future<void> resume() async => _channel?.invokeMethod('resume');

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration target) async {
    await _channel?.invokeMethod('seek', {
      'positionSeconds': target.inMilliseconds / 1000.0,
    });
  }

  Future<void> seekForward([int seconds = 10]) async {
    final target = _position + seconds;
    await seek(Duration(milliseconds: (target * 1000).round()));
  }

  Future<void> seekBackward([int seconds = 10]) async {
    final target = (_position - seconds).clamp(0, double.infinity);
    await seek(Duration(milliseconds: (target * 1000).round()));
  }

  Future<void> setSubtitleTrack(int? index) async {
    await _channel?.invokeMethod('setSubtitleTrack', {'index': index});
  }

  Future<void> disableSubtitles() async {
    await _channel?.invokeMethod('setSubtitleTrack', {'index': null});
  }

  Future<void> setAudioTrack(int index) async {
    await _channel?.invokeMethod('setAudioTrack', {'index': index});
  }

  Future<void> setPlaybackSpeed(double rate) async {
    await _channel?.invokeMethod('setPlaybackSpeed', {'rate': rate});
  }

  // ── Cleanup ────────────────────────────────────────────────

  void dispose() {
    _channel?.invokeMethod('dispose');
    _channel?.setMethodCallHandler(null);
    _playingController.close();
    _bufferingController.close();
    _positionController.close();
    _durationController.close();
    _errorController.close();
    _pipController.close();
    _tracksController.close();
    _readyController.close();
  }
}

// ── Supporting types ──────────────────────────────────────────

class TrackInfo {
  final int index;
  final String title;
  final String language;

  const TrackInfo({
    required this.index,
    required this.title,
    required this.language,
  });

  /// Display label: title if available, else language, else "Track N".
  String get displayName {
    if (title.isNotEmpty) return title;
    if (language.isNotEmpty) return language;
    return 'Track ${index + 1}';
  }
}

class PlayerError {
  final String message;
  final bool needsFallback;

  const PlayerError(this.message, {this.needsFallback = false});
}
