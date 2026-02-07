import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/providers.dart';

class FilmsScreen extends ConsumerStatefulWidget {
  const FilmsScreen({super.key});

  @override
  ConsumerState<FilmsScreen> createState() => _FilmsScreenState();
}

class _FilmsScreenState extends ConsumerState<FilmsScreen> {
  String _searchQuery = '';
  String? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final moviesAsync = ref.watch(movieChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.films),
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
              hintText: l10n.searchFilms,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          moviesAsync.when(
            data: (movies) {
              final groups = movies
                  .map((c) => c.groupTitle)
                  .where((g) => g != null)
                  .toSet()
                  .toList()
                ..sort();

              final filtered = movies.where((c) {
                final matchSearch = _searchQuery.isEmpty ||
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchGroup =
                    _selectedGroup == null || c.groupTitle == _selectedGroup;
                return matchSearch && matchGroup;
              }).toList();

              return Expanded(
                child: Column(
                  children: [
                    if (groups.isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(l10n.all),
                                selected: _selectedGroup == null,
                                onSelected: (_) =>
                                    setState(() => _selectedGroup = null),
                              ),
                            ),
                            ...groups.map((g) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: FilterChip(
                                    label: Text(g!),
                                    selected: _selectedGroup == g,
                                    onSelected: (_) =>
                                        setState(() => _selectedGroup = g),
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
                                  Icon(Icons.movie_outlined,
                                      size: 64,
                                      color:
                                          Theme.of(context).colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text(l10n.noFilms),
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
                                final movie = filtered[i];
                                return GestureDetector(
                                  onTap: () => context.push('/player',
                                      extra: movie.id),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: movie.logoUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: movie.logoUrl!,
                                                  fit: BoxFit.cover,
                                                  errorWidget:
                                                      (_, __, ___) =>
                                                          Container(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                        Icons.movie,
                                                        size: 40),
                                                  ),
                                                )
                                              : Container(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  child: const Icon(
                                                      Icons.movie,
                                                      size: 40),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        movie.name,
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
