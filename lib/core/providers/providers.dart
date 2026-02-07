/// Riverpod providers for the AlyPlayer application.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aly_player/core/database/database.dart';
import 'package:aly_player/core/services/player_service.dart';
import 'package:aly_player/core/services/playlist_service.dart';
import 'package:aly_player/core/services/epg_service.dart';
import 'package:aly_player/core/services/subscription_service.dart';
import 'package:aly_player/core/services/xtream_service.dart';

// ─── Singleton Services ──────────────────────────────────────

/// Global [AppDatabase] instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// [PlaylistService] for importing, refreshing, and deleting playlists.
final playlistServiceProvider = Provider<PlaylistService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = PlaylistService(database: db);
  ref.onDispose(() => service.dispose());
  return service;
});

/// [XtreamService] for Xtream Codes API imports.
final xtreamServiceProvider = Provider<XtreamService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = XtreamService(database: db);
  ref.onDispose(() => service.dispose());
  return service;
});

/// [PlayerService] wrapping media_kit for playback control and state.
final playerServiceProvider = Provider<PlayerService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = PlayerService(database: db);
  ref.onDispose(() => service.dispose());
  return service;
});

/// [EpgService] for managing EPG sources and program data.
final epgServiceProvider = Provider<EpgService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = EpgService(database: db);
  ref.onDispose(() => service.dispose());
  return service;
});

/// [SubscriptionService] for in-app purchase management.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Reactive Data Streams ───────────────────────────────────

/// Stream of all live channels, sorted by sort order.
final liveChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLiveChannels();
});

/// Stream of all movie (film) channels, sorted by name.
final movieChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchMovieChannels();
});

/// Stream of all favourite channels, sorted by name.
final favoriteChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchFavoriteChannels();
});

/// Stream of all playlists, sorted by sort order.
final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllPlaylists();
});

/// Stream of all EPG sources.
final epgSourcesProvider = StreamProvider<List<EpgSource>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchEpgSources();
});

/// Stream of all collections, sorted by sort order.
final collectionsProvider = StreamProvider<List<Collection>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchCollections();
});

/// Stream of all series entries, sorted by name.
final allSeriesProvider = StreamProvider<List<SeriesEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllSeries();
});

/// Stream of episodes for a specific series, sorted by season then episode.
final seriesEpisodesProvider = StreamProvider.family<List<Channel>, int>((ref, seriesId) {
  final db = ref.watch(databaseProvider);
  return db.watchEpisodesForSeries(seriesId);
});

/// Stream of channels the user is currently watching (watch progress 0-95%).
final continueWatchingProvider = StreamProvider<List<Channel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchContinueWatching();
});

/// Stream of trending (recently added) movies.
final trendingMoviesProvider = StreamProvider<List<Channel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTrendingMovies();
});

/// Stream of trending (recently added) series.
final trendingSeriesProvider = StreamProvider<List<SeriesEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTrendingSeries();
});
