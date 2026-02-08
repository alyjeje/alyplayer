import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/providers/providers.dart';

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

  // Double-tap seek feedback
  _SeekDirection? _seekDirection;

  @override
  void initState() {
    super.initState();
    _loadChannel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

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
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  void _onDoubleTapLeft() {
    final playerService = ref.read(playerServiceProvider);
    playerService.seekBackward();
    setState(() => _seekDirection = _SeekDirection.backward);
    _clearSeekFeedback();
  }

  void _onDoubleTapRight() {
    final playerService = ref.read(playerServiceProvider);
    playerService.seekForward();
    setState(() => _seekDirection = _SeekDirection.forward);
    _clearSeekFeedback();
  }

  void _clearSeekFeedback() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _seekDirection = null);
      }
    });
  }

  void _showSubtitlePicker() {
    final playerService = ref.read(playerServiceProvider);
    final tracks = playerService.subtitleTracks;
    final l10n = AppLocalizations.of(context)!;

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
                      leading: const Icon(Icons.subtitles,
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
                        playerService.setSubtitleTrack(track);
                        Navigator.pop(ctx);
                      },
                    )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerService = ref.watch(playerServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video layer
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

          // Double-tap zones (left and right halves)
          if (!_isLoading && _error == null)
            Row(
              children: [
                // Left half - seek backward
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: _onDoubleTapLeft,
                    child: const SizedBox.expand(),
                  ),
                ),
                // Right half - seek forward
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: _onDoubleTapRight,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),

          // Seek feedback overlay
          if (_seekDirection != null)
            Center(
              child: Align(
                alignment: _seekDirection == _SeekDirection.backward
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: _SeekFeedbackWidget(
                    direction: _seekDirection!,
                  ),
                ),
              ),
            ),

          // Controls overlay
          if (_controlsVisible)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
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
                child: SafeArea(
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
                      // Center play/pause
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
                                onPressed: () =>
                                    playerService.seekBackward(),
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
                                onPressed: () =>
                                    playerService.togglePlayPause(),
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(Icons.forward_10,
                                    color: Colors.white),
                                onPressed: () =>
                                    playerService.seekForward(),
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
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    Expanded(
                                      child: Slider(
                                        value: progress.clamp(0.0, 1.0),
                                        onChanged: (v) {
                                          final target = Duration(
                                              milliseconds:
                                                  (v * duration.inMilliseconds)
                                                      .round());
                                          playerService.seek(target);
                                        },
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.white24,
                                      ),
                                    ),
                                    Text(_formatDuration(duration),
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // Bottom bar: quick switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (playerService.previousChannel != null)
                            TextButton.icon(
                              icon: const Icon(Icons.swap_horiz,
                                  color: Colors.white),
                              label: Text(
                                playerService.previousChannel!.name,
                                style:
                                    const TextStyle(color: Colors.white70),
                              ),
                              onPressed: () =>
                                  playerService.quickSwitch(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
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
