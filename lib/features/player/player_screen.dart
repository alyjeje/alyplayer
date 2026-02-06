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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerService = ref.watch(playerServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video
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
                          ],
                        ),
                        const Spacer(),
                        // Center play/pause
                        StreamBuilder<bool>(
                          stream: playerService.player.stream.playing,
                          builder: (context, snapshot) {
                            final playing = snapshot.data ?? false;
                            return IconButton(
                              iconSize: 64,
                              icon: Icon(
                                playing
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  playerService.togglePlayPause(),
                            );
                          },
                        ),
                        const Spacer(),
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
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
