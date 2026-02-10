import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/providers/providers.dart';
import '../../core/services/native_player_service.dart';
import '../../l10n/app_localizations.dart';

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
  Timer? _hideTimer;
  Offset? _doubleTapPosition;
  _SeekDirection? _seekDirection;

  // iOS native player
  NativePlayerService? _nativePlayer;
  bool _useNativePlayer = false;

  @override
  void initState() {
    super.initState();

    if (Platform.isIOS) {
      // iOS: use native AVPlayerViewController for PiP/AirPlay support
      _useNativePlayer = true;
      _presentNativePlayer();
    } else {
      // Android: use media_kit with custom controls
      _loadChannel();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _startHideTimer();
    }
  }

  /// iOS: Load channel info, present native AVPlayerViewController, then pop.
  Future<void> _presentNativePlayer() async {
    try {
      final db = ref.read(databaseProvider);
      final channel = await db.getChannelById(widget.channelId);
      if (channel == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // AVPlayer doesn't support .mkv or .avi — fall back to media_kit
      final url = channel.streamUrl.toLowerCase();
      if (url.endsWith('.mkv') || url.endsWith('.avi')) {
        _fallbackToMediaKit();
        return;
      }

      // AVPlayer can't play raw .ts (MPEG-TS) but Xtream servers serve HLS
      // when you change the extension to .m3u8
      var playerUrl = channel.streamUrl;
      if (playerUrl.endsWith('.ts')) {
        playerUrl = '${playerUrl.substring(0, playerUrl.length - 3)}.m3u8';
      }

      _nativePlayer = NativePlayerService();

      // When native player is dismissed (user taps Done), pop this screen
      _nativePlayer!.onDismissed = (_) {
        if (mounted) Navigator.of(context).pop();
      };

      final success = await _nativePlayer!.presentPlayer(
        url: playerUrl,
        title: channel.name,
      );

      if (!success && mounted) {
        _fallbackToMediaKit();
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Fall back to media_kit player (Android-style controls).
  void _fallbackToMediaKit() {
    setState(() => _useNativePlayer = false);
    _loadChannel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideTimer();
  }

  /// Android: Load channel into media_kit player.
  Future<void> _loadChannel() async {
    try {
      final db = ref.read(databaseProvider);
      final channel = await db.getChannelById(widget.channelId);
      if (channel == null) {
        setState(() {
          _error = 'Channel not found';
          _isLoading = false;
        });
        return;
      }
      final playerService = ref.read(playerServiceProvider);
      await playerService.play(channel);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _nativePlayer?.dispose();
    if (!_useNativePlayer) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

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
    final playerService = ref.read(playerServiceProvider);

    if (_doubleTapPosition!.dx < screenWidth / 2) {
      playerService.seekBackward();
      setState(() => _seekDirection = _SeekDirection.backward);
    } else {
      playerService.seekForward();
      setState(() => _seekDirection = _SeekDirection.forward);
    }
    if (_controlsVisible) _startHideTimer();
    _clearSeekFeedback();
  }

  void _clearSeekFeedback() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekDirection = null);
    });
  }

  void _showSubtitlePicker() {
    final playerService = ref.read(playerServiceProvider);
    final tracks = playerService.subtitleTracks;
    final l10n = AppLocalizations.of(context)!;

    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.subtitles,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    final playerService = ref.read(playerServiceProvider);
    final tracks = playerService.audioTracks;
    final l10n = AppLocalizations.of(context)!;

    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.audioTrack,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...tracks
                .where((t) => t.id != 'auto' && t.id != 'no')
                .map((track) => ListTile(
                      leading: const Icon(Icons.audiotrack,
                          color: Colors.white70),
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

  @override
  Widget build(BuildContext context) {
    // iOS with native player: show black screen while native player is on top
    if (_useNativePlayer) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Android: full custom player UI with media_kit
    final l10n = AppLocalizations.of(context)!;
    final playerService = ref.watch(playerServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video layer
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : _error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error,
                              color: Colors.white, size: 48),
                          const SizedBox(height: 16),
                          Text(_error!,
                              style: const TextStyle(color: Colors.white)),
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
                      )
                    : Video(controller: playerService.videoController),
          ),

          // 2. Buffering indicator
          if (!_isLoading && _error == null)
            StreamBuilder<bool>(
              stream: playerService.player.stream.buffering,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                );
              },
            ),

          // 3. Gesture detector (tap = toggle controls, double-tap = seek)
          if (!_isLoading && _error == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                onDoubleTapDown: (details) =>
                    _doubleTapPosition = details.localPosition,
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

          // 6. Controls
          if (_controlsVisible && !_isLoading && _error == null)
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () {
                          playerService.stop();
                          Navigator.of(context).pop();
                        },
                      ),
                      if (playerService.currentChannel != null)
                        Expanded(
                          child: Text(
                            playerService.currentChannel!.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const Spacer(),
                      // Audio track button
                      IconButton(
                        icon: const Icon(Icons.audiotrack,
                            color: Colors.white),
                        tooltip: l10n.audioTrack,
                        onPressed: _showAudioTrackPicker,
                      ),
                      // Subtitle button
                      IconButton(
                        icon: const Icon(Icons.subtitles,
                            color: Colors.white),
                        tooltip: l10n.subtitles,
                        onPressed: _showSubtitlePicker,
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Center play/pause & seek buttons
                  StreamBuilder<bool>(
                    stream: playerService.player.stream.playing,
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.replay_10,
                                color: Colors.white),
                            onPressed: () {
                              playerService.seekBackward();
                              _startHideTimer();
                            },
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 64,
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              playerService.togglePlayPause();
                              _startHideTimer();
                            },
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.forward_10,
                                color: Colors.white),
                            onPressed: () {
                              playerService.seekForward();
                              _startHideTimer();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  // Progress bar
                  StreamBuilder<Duration>(
                    stream: playerService.player.stream.position,
                    builder: (context, posSnap) {
                      return StreamBuilder<Duration>(
                        stream: playerService.player.stream.duration,
                        builder: (context, durSnap) {
                          final position = posSnap.data ?? Duration.zero;
                          final duration = durSnap.data ?? Duration.zero;
                          final progress = duration.inMilliseconds > 0
                              ? position.inMilliseconds /
                                  duration.inMilliseconds
                              : 0.0;

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(_formatDuration(position),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: progress.clamp(0.0, 1.0),
                                    onChanged: (v) {
                                      final target = Duration(
                                          milliseconds:
                                              (v * duration.inMilliseconds)
                                                  .round());
                                      playerService.seek(target);
                                      _startHideTimer();
                                    },
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white24,
                                  ),
                                ),
                                Text(_formatDuration(duration),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
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
