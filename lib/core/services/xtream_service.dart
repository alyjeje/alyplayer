/// Xtream Codes API service for importing IPTV playlists.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:aly_player/core/database/database.dart';
import 'package:aly_player/core/models/dtos.dart';

class XtreamService {
  XtreamService({
    required AppDatabase database,
    http.Client? httpClient,
  })  : _db = database,
        _httpClient = httpClient ?? http.Client();

  final AppDatabase _db;
  final http.Client _httpClient;
  static const _uuid = Uuid();
  static const _requestTimeout = Duration(seconds: 15);

  /// Authenticates against an Xtream server and returns user info.
  /// Throws [XtreamException] on failure.
  Future<Map<String, dynamic>> authenticate(XtreamCredentials credentials) async {
    final url = '${credentials.apiUrl}?username=${credentials.username}&password=${credentials.password}';
    final response = await _httpClient.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw XtreamException('Authentication failed: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final userInfo = data['user_info'] as Map<String, dynamic>?;
    if (userInfo == null || userInfo['auth'] == 0) {
      throw XtreamException('Authentication failed: invalid credentials');
    }
    return data;
  }

  /// Full import: authenticate, fetch live + vod + series, insert into database.
  Future<Playlist> importFromXtream(XtreamCredentials credentials, {String? name}) async {
    await authenticate(credentials);

    // Determine sort order
    final existing = await _db.getAllPlaylists();
    final nextSort = existing.isEmpty
        ? 0
        : existing.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final effectiveName = name ?? _nameFromServer(credentials.server);

    final playlist = await _db.insertPlaylist(
      PlaylistsCompanion.insert(
        uuid: _uuid.v4(),
        name: effectiveName,
        url: Value(credentials.server),
        playlistType: Value('xtream'),
        xtreamServer: Value(credentials.server),
        xtreamUsername: Value(credentials.username),
        xtreamPassword: Value(credentials.password),
        sortOrder: Value(nextSort),
        lastUpdated: Value(DateTime.now()),
      ),
    );

    try {
      // Fetch and insert live streams
      final liveChannels = await _fetchLiveStreams(credentials);
      if (liveChannels.isNotEmpty) {
        await _db.insertChannelsBatch(
          _buildCompanions(liveChannels, playlist.id, 'live', credentials),
        );
      }

      // Fetch and insert VOD/movies
      final vodChannels = await _fetchVodStreams(credentials);
      if (vodChannels.isNotEmpty) {
        await _db.insertChannelsBatch(
          _buildCompanions(vodChannels, playlist.id, 'movie', credentials),
        );
      }

      // Fetch and insert series
      await _importSeries(credentials, playlist.id);

      // Update channel count
      // Count total channels inserted for this playlist
      final allPlaylists = await _db.getAllPlaylists();
      final updated = allPlaylists.firstWhere((p) => p.id == playlist.id);
      // We don't have a direct count query, so just update with the totals
      final totalCount = liveChannels.length + vodChannels.length;
      await _db.updatePlaylist(
        updated.copyWith(channelCount: totalCount),
      );
    } catch (e) {
      // If import fails mid-way, clean up
      await _db.deletePlaylistById(playlist.id);
      rethrow;
    }

    return playlist;
  }

  /// Refresh an existing Xtream playlist.
  Future<void> refreshXtreamPlaylist(int playlistId) async {
    final playlists = await _db.getAllPlaylists();
    final playlist = playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => throw XtreamException('Playlist not found'),
    );

    if (playlist.xtreamServer == null || playlist.xtreamUsername == null || playlist.xtreamPassword == null) {
      throw XtreamException('Not an Xtream playlist');
    }

    final credentials = XtreamCredentials(
      server: playlist.xtreamServer!,
      username: playlist.xtreamUsername!,
      password: playlist.xtreamPassword!,
    );

    await authenticate(credentials);

    await _db.transaction(() async {
      await _db.deleteChannelsForPlaylist(playlistId);
      await _db.deleteSeriesForPlaylist(playlistId);

      final liveChannels = await _fetchLiveStreams(credentials);
      if (liveChannels.isNotEmpty) {
        await _db.insertChannelsBatch(
          _buildCompanions(liveChannels, playlistId, 'live', credentials),
        );
      }

      final vodChannels = await _fetchVodStreams(credentials);
      if (vodChannels.isNotEmpty) {
        await _db.insertChannelsBatch(
          _buildCompanions(vodChannels, playlistId, 'movie', credentials),
        );
      }

      await _importSeries(credentials, playlistId);
    });
  }

  void dispose() {
    _httpClient.close();
  }

  // ── Private helpers ──

  Future<List<_XtreamStream>> _fetchLiveStreams(XtreamCredentials creds) async {
    final url = '${creds.apiUrl}?username=${creds.username}&password=${creds.password}&action=get_live_streams';
    return _fetchStreams(url);
  }

  Future<List<_XtreamStream>> _fetchVodStreams(XtreamCredentials creds) async {
    final url = '${creds.apiUrl}?username=${creds.username}&password=${creds.password}&action=get_vod_streams';
    return _fetchStreams(url);
  }

  Future<List<_XtreamStream>> _fetchStreams(String url) async {
    try {
      final response = await _httpClient.get(Uri.parse(url)).timeout(_requestTimeout);
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return _XtreamStream(
          id: '${map['stream_id'] ?? map['num']}',
          name: (map['name'] ?? 'Unknown') as String,
          logoUrl: map['stream_icon'] as String?,
          groupTitle: map['category_name'] as String?,
          containerExtension: map['container_extension'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _importSeries(XtreamCredentials creds, int playlistId) async {
    final url = '${creds.apiUrl}?username=${creds.username}&password=${creds.password}&action=get_series';
    try {
      final response = await _httpClient.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return;
      final list = jsonDecode(response.body) as List<dynamic>;

      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final seriesId = map['series_id'];
        final seriesName = (map['name'] ?? 'Unknown') as String;
        final cover = map['cover'] as String?;
        final genre = map['genre'] as String?;
        final plot = map['plot'] as String?;

        // Insert series entry
        final seriesEntry = await _db.insertSeries(
          SeriesEntriesCompanion.insert(
            uuid: _uuid.v4(),
            name: seriesName,
            coverUrl: Value(cover),
            genre: Value(genre),
            plot: Value(plot),
            playlistId: playlistId,
          ),
        );

        // Fetch series info (episodes) - optional, may fail for some series
        try {
          final infoUrl = '${creds.apiUrl}?username=${creds.username}&password=${creds.password}&action=get_series_info&series_id=$seriesId';
          final infoResponse = await _httpClient.get(Uri.parse(infoUrl)).timeout(_requestTimeout);
          if (infoResponse.statusCode == 200) {
            final infoData = jsonDecode(infoResponse.body) as Map<String, dynamic>;
            final episodes = infoData['episodes'] as Map<String, dynamic>?;
            if (episodes != null) {
              final companions = <ChannelsCompanion>[];
              var sortOrder = 0;
              for (final seasonEntry in episodes.entries) {
                final seasonNum = int.tryParse(seasonEntry.key) ?? 1;
                final episodeList = seasonEntry.value as List<dynamic>;
                for (final ep in episodeList) {
                  final epMap = ep as Map<String, dynamic>;
                  final epId = '${epMap['id']}';
                  final epTitle = (epMap['title'] ?? 'Episode') as String;
                  final epNum = int.tryParse('${epMap['episode_num'] ?? 0}') ?? 0;
                  final ext = (epMap['container_extension'] ?? 'mp4') as String;
                  final streamUrl = creds.seriesStreamUrl(epId, ext);

                  companions.add(ChannelsCompanion.insert(
                    uuid: _uuid.v4(),
                    name: epTitle,
                    streamUrl: streamUrl,
                    logoUrl: Value(cover),
                    groupTitle: Value(genre),
                    contentType: Value('series'),
                    seriesId: Value(seriesEntry.id),
                    seasonNumber: Value(seasonNum),
                    episodeNumber: Value(epNum),
                    sortOrder: Value(sortOrder++),
                    playlistId: playlistId,
                  ));
                }
              }
              if (companions.isNotEmpty) {
                await _db.insertChannelsBatch(companions);
              }
            }
          }
        } catch (_) {
          // Skip episodes if fetch fails for this series
        }
      }
    } catch (_) {
      // Series import is best-effort
    }
  }

  List<ChannelsCompanion> _buildCompanions(
    List<_XtreamStream> streams,
    int playlistId,
    String contentType,
    XtreamCredentials creds,
  ) {
    return [
      for (var i = 0; i < streams.length; i++)
        ChannelsCompanion.insert(
          uuid: _uuid.v4(),
          name: streams[i].name,
          streamUrl: contentType == 'live'
              ? creds.liveStreamUrl(streams[i].id)
              : creds.vodStreamUrl(streams[i].id, streams[i].containerExtension ?? 'mp4'),
          logoUrl: Value(streams[i].logoUrl),
          groupTitle: Value(streams[i].groupTitle),
          contentType: Value(contentType),
          sortOrder: Value(i),
          playlistId: playlistId,
        ),
    ];
  }

  static String _nameFromServer(String server) {
    try {
      final uri = Uri.parse(server);
      return uri.host.isNotEmpty ? uri.host : 'Xtream Playlist';
    } catch (_) {
      return 'Xtream Playlist';
    }
  }
}

class _XtreamStream {
  final String id;
  final String name;
  final String? logoUrl;
  final String? groupTitle;
  final String? containerExtension;

  _XtreamStream({
    required this.id,
    required this.name,
    this.logoUrl,
    this.groupTitle,
    this.containerExtension,
  });
}

class XtreamException implements Exception {
  const XtreamException(this.message);
  final String message;

  @override
  String toString() => 'XtreamException: $message';
}
