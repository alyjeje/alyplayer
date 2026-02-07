import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/providers.dart';
import '../../core/database/database.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  final int seriesId;

  const SeriesDetailScreen({super.key, required this.seriesId});

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  int _selectedSeason = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final episodesAsync = ref.watch(seriesEpisodesProvider(widget.seriesId));

    return Scaffold(
      body: FutureBuilder<SeriesEntry?>(
        future: ref.read(databaseProvider).getSeriesById(widget.seriesId),
        builder: (context, snapshot) {
          final series = snapshot.data;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(series?.name ?? ''),
                  background: series?.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: series!.coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                ),
              ),

              // Plot/description
              if (series?.plot != null && series!.plot!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(series.plot!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),

              // Season selector + episodes
              episodesAsync.when(
                data: (episodes) {
                  if (episodes.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(child: Text(l10n.noEpisodes)),
                    );
                  }

                  // Get unique seasons
                  final seasons = episodes
                      .map((e) => e.seasonNumber ?? 1)
                      .toSet()
                      .toList()
                    ..sort();

                  if (!seasons.contains(_selectedSeason)) {
                    _selectedSeason = seasons.first;
                  }

                  final seasonEpisodes = episodes
                      .where((e) => (e.seasonNumber ?? 1) == _selectedSeason)
                      .toList();

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // Season chips
                      if (seasons.length > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Wrap(
                            spacing: 8,
                            children: seasons.map((s) {
                              return ChoiceChip(
                                label: Text('${l10n.season} $s'),
                                selected: _selectedSeason == s,
                                onSelected: (_) =>
                                    setState(() => _selectedSeason = s),
                              );
                            }).toList(),
                          ),
                        ),

                      // Episode list
                      ...seasonEpisodes.map((ep) => ListTile(
                            leading: ep.logoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: ep.logoUrl!,
                                      width: 64,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const SizedBox(
                                              width: 64,
                                              height: 40,
                                              child: Icon(Icons.play_circle)),
                                    ),
                                  )
                                : const SizedBox(
                                    width: 64,
                                    height: 40,
                                    child: Icon(Icons.play_circle)),
                            title: Text(ep.name),
                            subtitle: Text(l10n.seasonEpisode(
                                ep.seasonNumber ?? 1, ep.episodeNumber ?? 1)),
                            trailing: ep.watchProgress > 0
                                ? SizedBox(
                                    width: 40,
                                    child: CircularProgressIndicator(
                                      value: ep.watchProgress,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            onTap: () =>
                                context.push('/player', extra: ep.id),
                          )),
                    ]),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('${l10n.error}: $e')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
