/// Riverpod providers for the AlyPlayer application.
///
/// This file centralises all top-level providers so that features and screens
/// can depend on a single, well-documented import for their data needs.
///
/// Provider naming convention:
/// - Singleton services: `<name>Provider`       (e.g. `databaseProvider`)
/// - Reactive streams:   `<name>Provider`       (e.g. `liveChannelsProvider`)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aly_player/core/database/database.dart';
import 'package:aly_player/core/services/player_service.dart';
import 'package:aly_player/core/services/playlist_service.dart';
import 'package:aly_player/core/services/epg_service.dart';
import 'package:aly_player/core/services/subscription_service.dart';

// ─── Singleton Services ──────────────────────────────────────

/// Global [AppDatabase] instance.
///
/// The database is created once and shared across the entire app. Drift
/// handles connection pooling and background isolate execution internally.
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

/// Stream of all live (non-VOD) channels, sorted by sort order.
final liveChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLiveChannels();
});

/// Stream of all VOD channels, sorted by name.
final vodChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchVodChannels();
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
