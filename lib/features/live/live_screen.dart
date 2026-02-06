import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/providers.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  String _searchQuery = '';
  String? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(liveChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.liveTV),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/import'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              hintText: l10n.searchChannels,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          channelsAsync.when(
            data: (channels) {
              final groups = channels
                  .map((c) => c.groupTitle)
                  .where((g) => g != null)
                  .toSet()
                  .toList()
                ..sort();

              final filtered = channels.where((c) {
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
                              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                  Icon(Icons.live_tv,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                  const SizedBox(height: 16),
                                  Text(l10n.noChannels),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final ch = filtered[i];
                                return ListTile(
                                  leading: ch.logoUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: ch.logoUrl!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const Icon(Icons.tv),
                                          ),
                                        )
                                      : const CircleAvatar(
                                          child: Icon(Icons.tv)),
                                  title: Text(ch.name),
                                  subtitle: ch.groupTitle != null
                                      ? Text(ch.groupTitle!)
                                      : null,
                                  trailing: IconButton(
                                    icon: Icon(
                                      ch.isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: ch.isFavorite
                                          ? Theme.of(context)
                                              .colorScheme
                                              .error
                                          : null,
                                    ),
                                    onPressed: () => ref
                                        .read(databaseProvider)
                                        .toggleFavorite(
                                            ch.id, !ch.isFavorite),
                                  ),
                                  onTap: () =>
                                      context.push('/player', extra: ch.id),
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
            error: (e, _) => Expanded(
                child: Center(child: Text('${l10n.error}: $e'))),
          ),
        ],
      ),
    );
  }
}
