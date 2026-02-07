import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/providers.dart';

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  String _searchQuery = '';
  String? _selectedGenre;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final seriesAsync = ref.watch(allSeriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.series),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              hintText: l10n.searchSeries,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          seriesAsync.when(
            data: (seriesList) {
              // Extract unique genres
              final genres = seriesList
                  .map((s) => s.genre)
                  .where((g) => g != null && g.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

              final filtered = seriesList.where((s) {
                final matchSearch = _searchQuery.isEmpty ||
                    s.name.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchGenre =
                    _selectedGenre == null || s.genre == _selectedGenre;
                return matchSearch && matchGenre;
              }).toList();

              return Expanded(
                child: Column(
                  children: [
                    if (genres.isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(l10n.all),
                                selected: _selectedGenre == null,
                                onSelected: (_) =>
                                    setState(() => _selectedGenre = null),
                              ),
                            ),
                            ...genres.map((g) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: FilterChip(
                                    label: Text(g!),
                                    selected: _selectedGenre == g,
                                    onSelected: (_) =>
                                        setState(() => _selectedGenre = g),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tv,
                                      size: 64,
                                      color:
                                          Theme.of(context).colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text(l10n.noSeries),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.6,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final s = filtered[i];
                                return GestureDetector(
                                  onTap: () => context.push('/series/${s.id}'),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: s.coverUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: s.coverUrl!,
                                                  fit: BoxFit.cover,
                                                  errorWidget:
                                                      (_, __, ___) =>
                                                          Container(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                        Icons.tv,
                                                        size: 40),
                                                  ),
                                                )
                                              : Container(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  child: const Icon(Icons.tv,
                                                      size: 40),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        s.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                Expanded(child: Center(child: Text('${l10n.error}: $e'))),
          ),
        ],
      ),
    );
  }
}
