import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:aly_player/core/database/database.dart';
import 'package:aly_player/core/parsers/xmltv_parser.dart';

class EpgService {
  EpgService({required AppDatabase database, http.Client? httpClient})
      : _db = database,
        _httpClient = httpClient ?? http.Client();

  final AppDatabase _db;
  final http.Client _httpClient;
  static const _uuid = Uuid();
  static const _requestTimeout = Duration(seconds: 30);

  Future<EpgSource> addSource(String name, String url) async {
    final source = await _db.insertEpgSource(
      EpgSourcesCompanion.insert(
        uuid: _uuid.v4(),
        name: name,
        url: url,
      ),
    );
    // Immediately fetch programs for the new source
    await refreshSource(source);
    return source;
  }

  Future<void> refreshSource(EpgSource source) async {
    try {
      final response = await _httpClient
          .get(Uri.parse(source.url))
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return;

      final result = XMLTVParser.parse(response.body);

      // Convert to drift companions
      final companions = result.programs.map((p) => EpgProgramsCompanion.insert(
        channelId: p.channelId,
        title: p.title,
        subtitle: Value(p.subtitle),
        description: Value(p.description),
        startTime: p.startTime,
        endTime: p.endTime,
        category: Value(p.category),
        iconUrl: Value(p.iconUrl),
        sourceId: source.id,
      )).toList();

      // Delete old programs for this source and insert new ones
      await _db.transaction(() async {
        await (_db.delete(_db.epgPrograms)
          ..where((t) => t.sourceId.equals(source.id))).go();
        if (companions.isNotEmpty) {
          await _db.insertEpgProgramsBatch(companions);
        }
      });

      // Update lastUpdated on the source
      await (_db.update(_db.epgSources)..where((t) => t.id.equals(source.id)))
        .write(EpgSourcesCompanion(lastUpdated: Value(DateTime.now())));

      // Clean up programs older than 7 days
      await _db.deleteOldEpgPrograms();
    } on TimeoutException catch (_) {
      // Silently fail - EPG is non-critical
    } on SocketException catch (_) {
      // Network error - silently fail
    } on FormatException catch (_) {
      // Invalid XML - silently fail
    }
  }

  Future<void> refreshAllSources() async {
    final sources = await _db.getAllEpgSources();
    for (final source in sources) {
      if (source.isActive) {
        await refreshSource(source);
      }
    }
  }

  Future<void> deleteSource(int id) async {
    await _db.deleteEpgSource(id);
  }

  void dispose() {
    _httpClient.close();
  }
}
