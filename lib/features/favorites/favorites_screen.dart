import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.favorites),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.channels),
              Tab(text: l10n.collections),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FavoriteChannelsTab(),
            _CollectionsTab(),
          ],
        ),
      ),
    );
  }
}

class _FavoriteChannelsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favAsync = ref.watch(favoriteChannelsProvider);

    return favAsync.when(
      data: (channels) {
        if (channels.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(l10n.noFavorites),
                const SizedBox(height: 8),
                Text(l10n.noFavoritesHint,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: channels.length,
          itemBuilder: (context, i) {
            final ch = channels[i];
            return ListTile(
              leading: ch.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: ch.logoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.tv),
                      ),
                    )
                  : const CircleAvatar(child: Icon(Icons.tv)),
              title: Text(ch.name),
              subtitle: ch.groupTitle != null ? Text(ch.groupTitle!) : null,
              trailing: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () =>
                    ref.read(databaseProvider).toggleFavorite(ch.id, false),
              ),
              onTap: () => context.push('/player', extra: ch.id),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${l10n.error}: $e')),
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionsAsync = ref.watch(collectionsProvider);

    return collectionsAsync.when(
      data: (collections) {
        if (collections.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_outlined,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(l10n.noCollections),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: collections.length,
          itemBuilder: (context, i) {
            final col = collections[i];
            return ListTile(
              leading: CircleAvatar(
                child: Icon(_iconFromName(col.iconName)),
              ),
              title: Text(col.name),
              onTap: () {
                // TODO: navigate to collection detail
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${l10n.error}: $e')),
    );
  }

  IconData _iconFromName(String name) {
    return switch (name) {
      'sports' => Icons.sports_soccer,
      'news' => Icons.newspaper,
      'movies' => Icons.movie,
      'kids' => Icons.child_care,
      'music' => Icons.music_note,
      _ => Icons.folder,
    };
  }
}
