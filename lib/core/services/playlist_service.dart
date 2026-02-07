/// Playlist business-logic service.
///
/// Handles importing M3U playlists from URLs or raw content, refreshing
/// existing playlists, and managing playlist lifecycle (delete, favorites).
///
/// This service sits between the UI / provider layer and the drift database,
/// orchestrating HTTP fetching, M3U parsing, and batch database writes.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:aly_player/core/database/database.dart';
import 'package:aly_player/core/models/dtos.dart';
import 'package:aly_player/core/parsers/m3u_parser.dart';

/// Service responsible for playlist import, refresh, and management operations.
class PlaylistService {
  PlaylistService({
    required AppDatabase database,
    http.Client? httpClient,
  })  : _db = database,
        _httpClient = httpClient ?? http.Client();

  final AppDatabase _db;
  final http.Client _httpClient;

  static const _uuid = Uuid();

  /// HTTP request timeout per attempt.
  static const _requestTimeout = Duration(seconds: 15);

  /// Maximum number of HTTP fetch attempts (initial + retries).
  static const _maxAttempts = 3;

  // ─── Public API ──────────────────────────────────────────

  /// Imports a playlist from a remote URL.
  ///
  /// Downloads the M3U content, parses it, and inserts the playlist and its
  /// channels into the database.
  ///
  /// [name] overrides the auto-derived playlist name. If not provided, the
  /// name is derived from the URL host/path.
  ///
  /// Returns the newly created [Playlist] database entity.
  ///
  /// Throws [PlaylistImportException] on network or parse errors.
  Future<Playlist> importFromUrl(String url, {String? name}) async {
    final content = await _fetchWithRetry(url);

    final playlistDto = M3UParser.parse(content, sourceUrl: url);

    final effectiveName = name ?? _nameFromUrl(url);

    return _insertPlaylist(
      playlistDto,
      name: effectiveName,
      url: url,
    );
  }

  /// Imports a playlist from raw M3U content (e.g. pasted from clipboard or
  /// read from a local file).
  ///
  /// [name] is required as there is no URL to derive a name from; defaults
  /// to "Imported Playlist" if not supplied.
  ///
  /// [sourceUrl] is an optional hint stored for bookkeeping.
  ///
  /// Returns the newly created [Playlist] database entity.
  Future<Playlist> importFromContent(
    String content, {
    String? name,
    String? sourceUrl,
  }) async {
    final playlistDto = M3UParser.parse(content, sourceUrl: sourceUrl);

    return _insertPlaylist(
      playlistDto,
      name: name ?? 'Imported Playlist',
      url: sourceUrl,
    );
  }

  /// Re-downloads an existing playlist from its stored URL and replaces all
  /// of its channels in the database.
  ///
  /// Throws [PlaylistImportException] if the playlist has no URL (i.e. it was
  /// imported from a file or clipboard).
  Future<void> refreshPlaylist(int playlistId) async {
    final playlists = await _db.getAllPlaylists();
    final playlist = playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => throw PlaylistImportException(
        'Playlist with id $playlistId not found.',
      ),
    );

    final url = playlist.url;
    if (url == null || url.isEmpty) {
      throw PlaylistImportException(
        'Cannot refresh playlist "${playlist.name}" -- no source URL stored.',
      );
    }

    final content = await _fetchWithRetry(url);
    final playlistDto = M3UParser.parse(content, sourceUrl: url);

    // Replace channels in a single transaction.
    await _db.transaction(() async {
      await _db.deleteChannelsForPlaylist(playlistId);

      final companions = _buildChannelCompanions(playlistDto.channels, playlistId);
      await _db.insertChannelsBatch(companions);

      // Update playlist metadata.
      await _db.updatePlaylist(
        playlist.copyWith(
          lastUpdated: Value(DateTime.now()),
          channelCount: playlistDto.channelCount,
        ),
      );
    });
  }

  /// Permanently deletes a playlist and all of its associated channels.
  Future<void> deletePlaylist(int playlistId) async {
    await _db.deletePlaylistById(playlistId);
  }

  /// Imports a playlist from a local file path.
  ///
  /// Reads the file content and delegates to [importFromContent].
  Future<Playlist> importFromFile(String filePath, {String? name}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw PlaylistImportException('File not found: $filePath');
    }
    final content = await file.readAsString();
    final effectiveName = name ?? file.uri.pathSegments.last.replaceAll(RegExp(r'\.(m3u8?|txt)$'), '');
    return importFromContent(content, name: effectiveName);
  }

  /// Imports a single direct stream URL as a playlist with one channel.
  ///
  /// Creates a playlist with `playlistType` set to `'direct'` and a single
  /// live channel entry pointing to [url].
  ///
  /// Returns the newly created [Playlist] database entity.
  Future<Playlist> importFromDirectUrl(String url, {String? name}) async {
    final effectiveName = name ?? _nameFromUrl(url);

    // Determine sort order (append to end).
    final existing = await _db.getAllPlaylists();
    final nextSort = existing.isEmpty
        ? 0
        : existing.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final playlist = await _db.insertPlaylist(
      PlaylistsCompanion.insert(
        uuid: _uuid.v4(),
        name: effectiveName,
        url: Value(url),
        playlistType: Value('direct'),
        channelCount: Value(1),
        sortOrder: Value(nextSort),
        lastUpdated: Value(DateTime.now()),
      ),
    );

    await _db.insertChannelsBatch([
      ChannelsCompanion.insert(
        uuid: _uuid.v4(),
        name: effectiveName,
        streamUrl: url,
        contentType: Value('live'),
        sortOrder: Value(0),
        playlistId: playlist.id,
      ),
    ]);

    return playlist;
  }

  /// Toggles the favorite status of a channel.
  Future<void> toggleFavorite(int channelId) async {
    final channel = await _db.getChannelById(channelId);
    if (channel == null) return;

    await _db.toggleFavorite(channelId, !channel.isFavorite);
  }

  /// Releases any resources held by this service (e.g. the HTTP client).
  void dispose() {
    _httpClient.close();
  }

  // ─── Private helpers ───────────────────────────────────────

  /// Fetches [url] with [_maxAttempts] attempts and exponential backoff.
  ///
  /// Throws [PlaylistImportException] if all attempts fail.
  Future<String> _fetchWithRetry(String url) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _httpClient
            .get(Uri.parse(url))
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          return response.body;
        }

        lastError = PlaylistImportException(
          'HTTP ${response.statusCode} when fetching playlist.',
        );
      } on TimeoutException {
        lastError = PlaylistImportException(
          'Request timed out after ${_requestTimeout.inSeconds}s '
          '(attempt $attempt/$_maxAttempts).',
        );
      } on SocketException catch (e) {
        lastError = PlaylistImportException(
          'Network error: ${e.message} (attempt $attempt/$_maxAttempts).',
        );
      } on http.ClientException catch (e) {
        lastError = PlaylistImportException(
          'HTTP client error: ${e.message} (attempt $attempt/$_maxAttempts).',
        );
      }

      // Exponential backoff: 1s, 2s, 4s, ...
      if (attempt < _maxAttempts) {
        await Future<void>.delayed(
          Duration(seconds: 1 << (attempt - 1)),
        );
      }
    }

    throw lastError!;
  }

  /// Inserts a parsed [PlaylistDTO] into the database.
  Future<Playlist> _insertPlaylist(
    PlaylistDTO dto, {
    required String name,
    String? url,
  }) async {
    // Determine sort order (append to end).
    final existing = await _db.getAllPlaylists();
    final nextSort = existing.isEmpty
        ? 0
        : existing.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final playlist = await _db.insertPlaylist(
      PlaylistsCompanion.insert(
        uuid: _uuid.v4(),
        name: name,
        url: Value(url),
        playlistType: Value('m3u'),
        channelCount: Value(dto.channelCount),
        sortOrder: Value(nextSort),
        lastUpdated: Value(DateTime.now()),
      ),
    );

    // Batch-insert channels.
    final companions = _buildChannelCompanions(dto.channels, playlist.id);
    await _db.insertChannelsBatch(companions);

    // Group series channels and create SeriesEntries.
    final seriesChannels = dto.channels
        .where((c) => c.contentType == ContentType.series && c.seriesName != null)
        .toList();

    if (seriesChannels.isNotEmpty) {
      final seriesNames = <String>{};
      for (final ch in seriesChannels) {
        seriesNames.add(ch.seriesName!);
      }

      for (final seriesName in seriesNames) {
        await _db.insertSeries(
          SeriesEntriesCompanion.insert(
            uuid: _uuid.v4(),
            name: seriesName,
            playlistId: playlist.id,
          ),
        );
      }
    }

    return playlist;
  }

  /// Converts a list of [ChannelDTO] objects into drift companion objects
  /// ready for batch insertion.
  List<ChannelsCompanion> _buildChannelCompanions(
    List<ChannelDTO> channels,
    int playlistId,
  ) {
    return [
      for (var i = 0; i < channels.length; i++)
        ChannelsCompanion.insert(
          uuid: _uuid.v4(),
          name: channels[i].name,
          streamUrl: channels[i].streamUrl,
          logoUrl: Value(channels[i].tvgLogo),
          groupTitle: Value(channels[i].groupTitle),
          tvgId: Value(channels[i].tvgId),
          tvgName: Value(channels[i].tvgName),
          contentType: Value(channels[i].contentType.value),
          seasonNumber: Value(channels[i].seasonNumber),
          episodeNumber: Value(channels[i].episodeNumber),
          sortOrder: Value(i),
          playlistId: playlistId,
        ),
    ];
  }

  /// Derives a readable playlist name from a URL.
  static String _nameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        // Use the host without common prefixes.
        var host = uri.host;
        if (host.startsWith('www.')) {
          host = host.substring(4);
        }
        return host;
      }
    } catch (_) {
      // Fall through.
    }
    return 'Playlist';
  }
}

/// Exception thrown when a playlist import or refresh operation fails.
class PlaylistImportException implements Exception {
  const PlaylistImportException(this.message);

  final String message;

  @override
  String toString() => 'PlaylistImportException: $message';
}
