import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ─── Tables ───────────────────────────────────────────────

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get url => text().nullable()();
  TextColumn get filePath => text().nullable()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdated => dateTime().nullable()();
  BoolColumn get autoRefresh => boolean().withDefault(const Constant(false))();
  IntColumn get refreshIntervalHours => integer().withDefault(const Constant(6))();
  TextColumn get colorTag => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get channelCount => integer().withDefault(const Constant(0))();
  TextColumn get playlistType => text().withDefault(const Constant('m3u'))(); // 'm3u', 'xtream', 'direct'
  TextColumn get xtreamServer => text().nullable()();
  TextColumn get xtreamUsername => text().nullable()();
  TextColumn get xtreamPassword => text().nullable()();
}

class Channels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get streamUrl => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get groupTitle => text().nullable()();
  TextColumn get tvgId => text().nullable()();
  TextColumn get tvgName => text().nullable()();
  TextColumn get contentType => text().withDefault(const Constant('live'))(); // 'live', 'movie', 'series'
  IntColumn get seriesId => integer().nullable().references(SeriesEntries, #id)();
  IntColumn get seasonNumber => integer().nullable()();
  IntColumn get episodeNumber => integer().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastWatched => dateTime().nullable()();
  RealColumn get watchProgress => real().withDefault(const Constant(0.0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get playlistId => integer().references(Playlists, #id)();
}

class EpgSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get url => text()();
  DateTimeColumn get lastUpdated => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class EpgPrograms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get channelId => text()();
  TextColumn get title => text()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  TextColumn get category => text().nullable()();
  TextColumn get iconUrl => text().nullable()();
  IntColumn get sourceId => integer().references(EpgSources, #id)();
}

class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get iconName => text().withDefault(const Constant('folder'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class CollectionChannels extends Table {
  IntColumn get collectionId => integer().references(Collections, #id)();
  IntColumn get channelId => integer().references(Channels, #id)();

  @override
  Set<Column> get primaryKey => {collectionId, channelId};
}

class SeriesEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get plot => text().nullable()();
  IntColumn get playlistId => integer().references(Playlists, #id)();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

// ─── Database ─────────────────────────────────────────────

@DriftDatabase(tables: [
  Playlists,
  Channels,
  EpgSources,
  EpgPrograms,
  Collections,
  CollectionChannels,
  SeriesEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing with in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(seriesEntries);
        await m.addColumn(channels, channels.contentType);
        await m.addColumn(channels, channels.seriesId);
        await m.addColumn(channels, channels.seasonNumber);
        await m.addColumn(channels, channels.episodeNumber);
        await m.addColumn(playlists, playlists.playlistType);
        await m.addColumn(playlists, playlists.xtreamServer);
        await m.addColumn(playlists, playlists.xtreamUsername);
        await m.addColumn(playlists, playlists.xtreamPassword);
        // Migrate existing data
        await customStatement("UPDATE channels SET content_type = 'movie' WHERE is_vod = 1");
        await customStatement("UPDATE channels SET content_type = 'live' WHERE is_vod = 0");
      }
    },
  );

  // ─── Playlist Queries ───

  Future<List<Playlist>> getAllPlaylists() =>
      (select(playlists)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Stream<List<Playlist>> watchAllPlaylists() =>
      (select(playlists)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Future<Playlist> insertPlaylist(PlaylistsCompanion entry) =>
      into(playlists).insertReturning(entry);

  Future<void> deletePlaylistById(int id) async {
    // Delete channels first (they may reference series)
    await (delete(channels)..where((t) => t.playlistId.equals(id))).go();
    // Delete series for this playlist
    await (delete(seriesEntries)..where((t) => t.playlistId.equals(id))).go();
    // Delete the playlist itself
    await (delete(playlists)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updatePlaylist(Playlist entry) =>
      update(playlists).replace(entry);

  // ─── Channel Queries ───

  Stream<List<Channel>> watchLiveChannels() =>
      (select(channels)
            ..where((t) => t.contentType.equals('live'))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Stream<List<Channel>> watchMovieChannels() =>
      (select(channels)
            ..where((t) => t.contentType.equals('movie'))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<List<Channel>> watchFavoriteChannels() =>
      (select(channels)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<Channel?> getChannelById(int id) =>
      (select(channels)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> toggleFavorite(int channelId, bool isFav) =>
      (update(channels)..where((t) => t.id.equals(channelId)))
          .write(ChannelsCompanion(isFavorite: Value(isFav)));

  Future<void> updateLastWatched(int channelId) =>
      (update(channels)..where((t) => t.id.equals(channelId)))
          .write(ChannelsCompanion(lastWatched: Value(DateTime.now())));

  Future<void> insertChannelsBatch(List<ChannelsCompanion> entries) async {
    await batch((b) {
      b.insertAll(channels, entries);
    });
  }

  Future<void> deleteChannelsForPlaylist(int playlistId) =>
      (delete(channels)..where((t) => t.playlistId.equals(playlistId))).go();

  // ─── Series Queries ───

  Stream<List<SeriesEntry>> watchAllSeries() =>
      (select(seriesEntries)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<SeriesEntry?> getSeriesById(int id) =>
      (select(seriesEntries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Channel>> watchEpisodesForSeries(int seriesId) =>
      (select(channels)
        ..where((t) => t.seriesId.equals(seriesId))
        ..orderBy([
          (t) => OrderingTerm.asc(t.seasonNumber),
          (t) => OrderingTerm.asc(t.episodeNumber),
        ]))
      .watch();

  Future<SeriesEntry> insertSeries(SeriesEntriesCompanion entry) =>
      into(seriesEntries).insertReturning(entry);

  Future<void> insertSeriesBatch(List<SeriesEntriesCompanion> entries) async {
    await batch((b) => b.insertAll(seriesEntries, entries));
  }

  Future<void> deleteSeriesForPlaylist(int playlistId) =>
      (delete(seriesEntries)..where((t) => t.playlistId.equals(playlistId))).go();

  // ─── Home Screen Queries ───

  Stream<List<Channel>> watchContinueWatching() =>
      (select(channels)
        ..where((t) =>
            t.contentType.isIn(['movie', 'series']) &
            t.watchProgress.isBiggerThanValue(0.0) &
            t.watchProgress.isSmallerThanValue(0.95))
        ..orderBy([(t) => OrderingTerm.desc(t.lastWatched)])
        ..limit(20))
      .watch();

  Stream<List<Channel>> watchTrendingMovies() =>
      (select(channels)
        ..where((t) => t.contentType.equals('movie'))
        ..orderBy([(t) => OrderingTerm.desc(t.id)])
        ..limit(20))
      .watch();

  Stream<List<SeriesEntry>> watchTrendingSeries() =>
      (select(seriesEntries)
        ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)])
        ..limit(20))
      .watch();

  // ─── EPG Queries ───

  Future<List<EpgSource>> getAllEpgSources() => select(epgSources).get();

  Stream<List<EpgSource>> watchEpgSources() => select(epgSources).watch();

  Future<EpgSource> insertEpgSource(EpgSourcesCompanion entry) =>
      into(epgSources).insertReturning(entry);

  Future<void> deleteEpgSource(int id) async {
    await (delete(epgPrograms)..where((t) => t.sourceId.equals(id))).go();
    await (delete(epgSources)..where((t) => t.id.equals(id))).go();
  }

  Future<void> insertEpgProgramsBatch(List<EpgProgramsCompanion> entries) async {
    await batch((b) {
      b.insertAll(epgPrograms, entries);
    });
  }

  Future<void> deleteOldEpgPrograms() =>
      (delete(epgPrograms)
            ..where((t) => t.endTime.isSmallerThanValue(
                DateTime.now().subtract(const Duration(days: 7)))))
          .go();

  Stream<List<EpgProgram>> watchProgramsForChannel(String tvgId, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(epgPrograms)
          ..where((t) =>
              t.channelId.equals(tvgId) &
              t.startTime.isBiggerOrEqualValue(dayStart) &
              t.startTime.isSmallerThanValue(dayEnd))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .watch();
  }

  Future<EpgProgram?> getCurrentProgram(String tvgId) {
    final now = DateTime.now();
    return (select(epgPrograms)
          ..where((t) =>
              t.channelId.equals(tvgId) &
              t.startTime.isSmallerOrEqualValue(now) &
              t.endTime.isBiggerThanValue(now))
          ..limit(1))
        .getSingleOrNull();
  }

  // ─── Collection Queries ───

  Stream<List<Collection>> watchCollections() =>
      (select(collections)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Future<Collection> insertCollection(CollectionsCompanion entry) =>
      into(collections).insertReturning(entry);

  Future<void> deleteCollection(int id) async {
    await (delete(collectionChannels)..where((t) => t.collectionId.equals(id))).go();
    await (delete(collections)..where((t) => t.id.equals(id))).go();
  }
}

// ─── Connection ───────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'aly_player.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
