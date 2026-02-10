import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/providers/providers.dart';
import '../../l10n/app_localizations.dart';
import 'native_player_controller.dart';
import 'native_player_view.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final int channelId;
  const PlayerScreen({super.key, required this.channelId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _controlsVisible = true;
  bool _isLoading = true;
  String? _error;
  String _title = '';
  Timer? _hideTimer;
  Offset? _doubleTapPosition;
  _SeekDirection? _seekDirection;

  // iOS inline native player (UiKitView)
  NativePlayerController? _nativeController;
  StreamSubscription<PlayerError>? _errorSub;
  StreamSubscription<void>? _readySub;

  // true = native AVPlayer inline (iOS primary)
  // false = media_kit (Android, or iOS fallback)
  bool _useNative = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (Platform.isIOS) {
      _useNative = true;
      _nativeController = NativePlayerController();
      _setupNativeListeners();
    }

    _loadChannel();
    _startHideTimer();
  }

  void _setupNativeListeners() {
    final nc = _nativeController!;

    _readySub = nc.readyStream.listen((_) {
      if (mounted) setState(() => _isLoading = false);
    });

    _errorSub = nc.errorStream.listen((error) {
      if (error.needsFallback) {
        _fallbackToMediaKit();
      } else if (mounted) {
        setState(() {
          _error = error.message;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadChannel() async {
    try {
      final db = ref.read(databaseProvider);
      final channel = await db.getChannelById(widget.channelId);
      if (channel == null) {
        if (mounted) {
          setState(() {
            _error = 'Channel not found';
            _isLoading = false;
          });
        }
        return;
      }

      _title = channel.name;

      if (_useNative) {
        _loadNative(channel.streamUrl, channel.name);
      } else {
        await _loadMediaKit();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// iOS: Start playback in inline native AVPlayerViewController.
  void _loadNative(String streamUrl, String name) {
    final lowerUrl = streamUrl.toLowerCase();

    // AVPlayer can't play .mkv/.avi — skip straight to media_kit
    if (lowerUrl.endsWith('.mkv') || lowerUrl.endsWith('.avi')) {
      _fallbackToMediaKit();
      return;
    }

    // URL strategy: primary + fallback
    String primaryUrl;
    String? fallbackUrl;

    if (lowerUrl.endsWith('.ts')) {
      // Xtream live: try .m3u8 (HLS) first, fall back to original .ts
      primaryUrl =
          '${streamUrl.substring(0, streamUrl.length - 3)}.m3u8';
      fallbackUrl = streamUrl;
    } else {
      primaryUrl = streamUrl;
      fallbackUrl = null;
    }

    // play() internally waits for the UiKitView to be created
    _nativeController!.play(
      url: primaryUrl,
      title: name,
      fallbackUrl: fallbackUrl,
    );
  }

  /// Android (or iOS fallback): Load into media_kit.
  Future<void> _loadMediaKit() async {
    final db = ref.read(databaseProvider);
    final channel = await db.getChannelById(widget.channelId);
    if (channel == null) return;
    final playerService = ref.read(playerServiceProvider);
    await playerService.play(channel);
    if (mounted) setState(() => _isLoading = false);
  }

  /// Switch from native AVPlayer to media_kit when format is unsupported.
  void _fallbackToMediaKit() {
    if (!mounted) return;
    _errorSub?.cancel();
    _readySub?.cancel();
    _nativeController?.dispose();
    _nativeController = null;
    setState(() {
      _useNative = false;
      _isLoading = true;
    });
    _loadMediaKit().catchError((e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _errorSub?.cancel();
    _readySub?.cancel();
    _nativeController?.dispose();
    if (!_useNative) {
      ref.read(playerServiceProvider).stop();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Controls ───────────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _handleDoubleTap() {
    if (_doubleTapPosition == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    if (_doubleTapPosition!.dx < screenWidth / 2) {
      _seekBackward();
      setState(() => _seekDirection = _SeekDirection.backward);
    } else {
      _seekForward();
      setState(() => _seekDirection = _SeekDirection.forward);
    }
    if (_controlsVisible) _startHideTimer();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekDirection = null);
    });
  }

  void _seekForward() {
    if (_useNative) {
      _nativeController?.seekForward();
    } else {
      ref.read(playerServiceProvider).seekForward();
    }
  }

  void _seekBackward() {
    if (_useNative) {
      _nativeController?.seekBackward();
    } else {
      ref.read(playerServiceProvider).seekBackward();
    }
  }

  void _togglePlayPause() {
    if (_useNative) {
      _nativeController?.togglePlayPause();
    } else {
      ref.read(playerServiceProvider).togglePlayPause();
    }
    _startHideTimer();
  }

  void _seekTo(Duration target) {
    if (_useNative) {
      _nativeController?.seek(target);
    } else {
      ref.read(playerServiceProvider).seek(target);
    }
    _startHideTimer();
  }

  void _onBack() {
    if (!_useNative) {
      ref.read(playerServiceProvider).stop();
    }
    Navigator.of(context).pop();
  }

  // ── Track pickers ──────────────────────────────────────────

  void _showSubtitlePicker() {
    final l10n = AppLocalizations.of(context)!;
    _hideTimer?.cancel();
    if (_useNative) {
      _showNativeSubtitlePicker(l10n);
    } else {
      _showMediaKitSubtitlePicker(l10n);
    }
  }

  void _showNativeSubtitlePicker(AppLocalizations l10n) {
    final tracks = _nativeController?.subtitleTracks ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.subtitles,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_off, color: Colors.white70),
              title: Text(l10n.off,
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                _nativeController?.disableSubtitles();
                Navigator.pop(ctx);
              },
            ),
            ...tracks.map((t) => ListTile(
                  leading: const Icon(Icons.subtitles, color: Colors.white70),
                  title: Text(t.displayName,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: t.language.isNotEmpty
                      ? Text(t.language,
                          style: const TextStyle(color: Colors.white38))
                      : null,
                  onTap: () {
                    _nativeController?.setSubtitleTrack(t.index);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted && _controlsVisible) _startHideTimer();
    });
  }

  void _showMediaKitSubtitlePicker(AppLocalizations l10n) {
    final playerService = ref.read(playerServiceProvider);
    final tracks = playerService.subtitleTracks;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.subtitles,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_off, color: Colors.white70),
              title: Text(l10n.off,
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                playerService.disableSubtitles();
                Navigator.pop(ctx);
              },
            ),
            ...tracks
                .where((t) => t.id != 'auto' && t.id != 'no')
                .map((track) => ListTile(
                      leading:
                          const Icon(Icons.subtitles, color: Colors.white70),
                      title: Text(
                        track.title ?? track.language ?? track.id,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: track.language != null && track.title != null
                          ? Text(track.language!,
                              style: const TextStyle(color: Colors.white38))
                          : null,
                      onTap: () {
                        playerService.setSubtitleTrack(track);
                        Navigator.pop(ctx);
                      },
                    )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted && _controlsVisible) _startHideTimer();
    });
  }

  void _showAudioTrackPicker() {
    final l10n = AppLocalizations.of(context)!;
    _hideTimer?.cancel();
    if (_useNative) {
      _showNativeAudioTrackPicker(l10n);
    } else {
      _showMediaKitAudioTrackPicker(l10n);
    }
  }

  void _showNativeAudioTrackPicker(AppLocalizations l10n) {
    final tracks = _nativeController?.audioTracks ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.audioTrack,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ...tracks.map((t) => ListTile(
                  leading: const Icon(Icons.audiotrack, color: Colors.white70),
                  title: Text(t.displayName,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: t.language.isNotEmpty
                      ? Text(t.language,
                          style: const TextStyle(color: Colors.white38))
                      : null,
                  onTap: () {
                    _nativeController?.setAudioTrack(t.index);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted && _controlsVisible) _startHideTimer();
    });
  }

  void _showMediaKitAudioTrackPicker(AppLocalizations l10n) {
    final playerService = ref.read(playerServiceProvider);
    final tracks = playerService.audioTracks;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.audioTrack,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ...tracks
                .where((t) => t.id != 'auto' && t.id != 'no')
                .map((track) => ListTile(
                      leading:
                          const Icon(Icons.audiotrack, color: Colors.white70),
                      title: Text(
                        track.title ?? track.language ?? track.id,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: track.language != null && track.title != null
                          ? Text(track.language!,
                              style: const TextStyle(color: Colors.white38))
                          : null,
                      onTap: () {
                        playerService.setAudioTrack(track);
                        Navigator.pop(ctx);
                      },
                    )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted && _controlsVisible) _startHideTimer();
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video layer
          Positioned.fill(child: _buildVideoLayer(l10n)),

          // 2. Buffering indicator
          if (!_isLoading && _error == null) _buildBufferingIndicator(),

          // 3. Gesture detector (tap = toggle, double-tap = seek)
          if (!_isLoading && _error == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                onDoubleTapDown: (d) =>
                    _doubleTapPosition = d.localPosition,
                onDoubleTap: _handleDoubleTap,
              ),
            ),

          // 4. Seek feedback
          if (_seekDirection != null)
            IgnorePointer(
              child: Center(
                child: Align(
                  alignment: _seekDirection == _SeekDirection.backward
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: _SeekFeedbackWidget(direction: _seekDirection!),
                  ),
                ),
              ),
            ),

          // 5. Controls gradient
          if (_controlsVisible && !_isLoading && _error == null)
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                    ],
                  ),
                ),
              ),
            ),

          // 6. Controls overlay
          if (_controlsVisible && !_isLoading && _error == null)
            _buildControls(l10n),
        ],
      ),
    );
  }

  Widget _buildVideoLayer(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child:
                  Text(_error!, style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadChannel();
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_useNative && _nativeController != null) {
      return NativePlayerView(controller: _nativeController!);
    }
    final playerService = ref.watch(playerServiceProvider);
    return Video(controller: playerService.videoController);
  }

  Widget _buildBufferingIndicator() {
    if (_useNative) {
      return StreamBuilder<bool>(
        stream: _nativeController?.bufferingStream,
        builder: (context, snapshot) {
          if (snapshot.data != true) return const SizedBox.shrink();
          return const Center(
              child: CircularProgressIndicator(color: Colors.white70));
        },
      );
    }
    final playerService = ref.watch(playerServiceProvider);
    return StreamBuilder<bool>(
      stream: playerService.player.stream.buffering,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return const Center(
            child: CircularProgressIndicator(color: Colors.white70));
      },
    );
  }

  Widget _buildControls(AppLocalizations l10n) {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _onBack,
              ),
              Expanded(
                child: Text(
                  _title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.audiotrack, color: Colors.white),
                tooltip: l10n.audioTrack,
                onPressed: _showAudioTrackPicker,
              ),
              IconButton(
                icon: const Icon(Icons.subtitles, color: Colors.white),
                tooltip: l10n.subtitles,
                onPressed: _showSubtitlePicker,
              ),
            ],
          ),
          const Spacer(),
          // Center play/pause & seek
          _buildCenterControls(),
          const Spacer(),
          // Progress bar
          _buildProgressBar(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    if (_useNative) {
      return StreamBuilder<bool>(
        stream: _nativeController?.playingStream,
        initialData: false,
        builder: (context, snapshot) => _CenterButtons(
          playing: snapshot.data ?? false,
          onPlayPause: _togglePlayPause,
          onSeekBack: () {
            _seekBackward();
            _startHideTimer();
          },
          onSeekFwd: () {
            _seekForward();
            _startHideTimer();
          },
        ),
      );
    }
    final playerService = ref.watch(playerServiceProvider);
    return StreamBuilder<bool>(
      stream: playerService.player.stream.playing,
      builder: (context, snapshot) => _CenterButtons(
        playing: snapshot.data ?? false,
        onPlayPause: _togglePlayPause,
        onSeekBack: () {
          _seekBackward();
          _startHideTimer();
        },
        onSeekFwd: () {
          _seekForward();
          _startHideTimer();
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_useNative) {
      return StreamBuilder<Duration>(
        stream: _nativeController?.positionStream,
        builder: (context, posSnap) => StreamBuilder<Duration>(
          stream: _nativeController?.durationStream,
          builder: (context, durSnap) => _ProgressBar(
            position: posSnap.data ?? Duration.zero,
            duration: durSnap.data ?? Duration.zero,
            onSeek: _seekTo,
          ),
        ),
      );
    }
    final playerService = ref.watch(playerServiceProvider);
    return StreamBuilder<Duration>(
      stream: playerService.player.stream.position,
      builder: (context, posSnap) => StreamBuilder<Duration>(
        stream: playerService.player.stream.duration,
        builder: (context, durSnap) => _ProgressBar(
          position: posSnap.data ?? Duration.zero,
          duration: durSnap.data ?? Duration.zero,
          onSeek: _seekTo,
        ),
      ),
    );
  }
}

// ── Extracted widgets ──────────────────────────────────────────

class _CenterButtons extends StatelessWidget {
  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekFwd;

  const _CenterButtons({
    required this.playing,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekFwd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.replay_10, color: Colors.white),
          onPressed: onSeekBack,
        ),
        const SizedBox(width: 24),
        IconButton(
          iconSize: 64,
          icon: Icon(
            playing ? Icons.pause_circle : Icons.play_circle,
            color: Colors.white,
          ),
          onPressed: onPlayPause,
        ),
        const SizedBox(width: 24),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.forward_10, color: Colors.white),
          onPressed: onSeekFwd,
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(_fmt(position),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Expanded(
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                onSeek(Duration(
                    milliseconds:
                        (v * duration.inMilliseconds).round()));
              },
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
            ),
          ),
          Text(_fmt(duration),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

enum _SeekDirection { forward, backward }

class _SeekFeedbackWidget extends StatelessWidget {
  final _SeekDirection direction;
  const _SeekFeedbackWidget({required this.direction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            direction == _SeekDirection.backward
                ? Icons.replay_10
                : Icons.forward_10,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 8),
          Text(
            direction == _SeekDirection.backward ? '-10s' : '+10s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
