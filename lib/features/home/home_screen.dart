import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/providers.dart';
import '../../core/database/database.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final continueWatching = ref.watch(continueWatchingProvider);
    final trendingSeries = ref.watch(trendingSeriesProvider);
    final trendingMovies = ref.watch(trendingMoviesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/import'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Continue Watching
          continueWatching.when(
            data: (channels) {
              if (channels.isEmpty) return const SizedBox.shrink();
              return _ContentRow(
                title: l10n.continueWatching,
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: channels.length,
                    itemBuilder: (context, i) => _ChannelCard(
                      channel: channels[i],
                      onTap: () => context.push('/player', extra: channels[i].id),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Trending Series
          trendingSeries.when(
            data: (series) {
              if (series.isEmpty) return const SizedBox.shrink();
              return _ContentRow(
                title: l10n.trendingSeries,
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: series.length,
                    itemBuilder: (context, i) => _SeriesCard(
                      series: series[i],
                      onTap: () => context.push('/series/${series[i].id}'),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Trending Films
          trendingMovies.when(
            data: (movies) {
              if (movies.isEmpty) return const SizedBox.shrink();
              return _ContentRow(
                title: l10n.trendingFilms,
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: movies.length,
                    itemBuilder: (context, i) => _ChannelCard(
                      channel: movies[i],
                      showProgress: false,
                      onTap: () => context.push('/player', extra: movies[i].id),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Empty state when nothing to show
          continueWatching.when(
            data: (cw) => trendingSeries.when(
              data: (ts) => trendingMovies.when(
                data: (tm) {
                  if (cw.isEmpty && ts.isEmpty && tm.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.movie_outlined,
                                size: 80,
                                color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(l10n.noChannels,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => context.push('/import'),
                              icon: const Icon(Icons.add),
                              label: Text(l10n.importPlaylist),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ContentRow extends StatelessWidget {
  final String title;
  final Widget child;

  const _ContentRow({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        child,
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool showProgress;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: channel.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: channel.logoUrl!,
                      width: 120,
                      height: showProgress ? 120 : 160,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 120,
                        height: showProgress ? 120 : 160,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie, size: 40),
                      ),
                    )
                  : Container(
                      width: 120,
                      height: showProgress ? 120 : 160,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.movie, size: 40),
                    ),
            ),
            if (showProgress && channel.watchProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(
                  value: channel.watchProgress,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final SeriesEntry series;
  final VoidCallback onTap;

  const _SeriesCard({required this.series, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: series.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: series.coverUrl!,
                      width: 130,
                      height: 160,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 130,
                        height: 160,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.tv, size: 40),
                      ),
                    )
                  : Container(
                      width: 130,
                      height: 160,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.tv, size: 40),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              series.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
