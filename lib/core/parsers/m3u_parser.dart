/// Robust M3U / M3U8 playlist parser.
///
/// Handles the wide variety of M3U files found in the wild, including:
/// - Standard and extended M3U formats (#EXTM3U / #EXTINF)
/// - Quoted and unquoted tag attributes (tvg-id, tvg-name, tvg-logo, etc.)
/// - VLCOPT directives between #EXTINF and the stream URL
/// - Bare URLs without any #EXTINF metadata
/// - Mixed line endings (CRLF, LF, CR)
/// - Malformed or incomplete entries (skipped gracefully)
library;

import 'package:aly_player/core/models/dtos.dart';

/// Static utility class for parsing M3U playlist content into a [PlaylistDTO].
///
/// Usage:
/// ```dart
/// final playlist = M3UParser.parse(rawM3UContent, sourceUrl: 'https://...');
/// ```
class M3UParser {
  M3UParser._(); // prevent instantiation

  // ── VOD detection ──────────────────────────────────────────

  /// File extensions that indicate a Video-On-Demand entry rather than a live
  /// stream.
  static const _vodExtensions = <String>{
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
    '.mpg',
    '.mpeg',
    '.ts',
    '.vob',
    '.3gp',
    '.ogv',
  };

  /// Case-insensitive keywords in the group-title that suggest VOD content.
  static const _vodGroupKeywords = <String>[
    'vod',
    'movie',
    'movies',
    'film',
    'films',
    'series',
    'serie',
    'episode',
    'episodes',
  ];

  // ── Series detection ──────────────────────────────────────

  /// Regex patterns that identify series episode numbering in channel names.
  static final _seriesPatterns = <RegExp>[
    RegExp(r'[Ss](\d+)[Ee](\d+)'),        // S01E02 or s01e02
    RegExp(r'Season\s*(\d+).*Episode\s*(\d+)', caseSensitive: false),
    RegExp(r'(\d+)x(\d+)'),                // 1x02 format
  ];

  /// Detects series information (season/episode) in a channel name.
  ///
  /// Returns a record with the series name (text before the match), season
  /// number, and episode number, or `null` if no pattern matches.
  static ({String seriesName, int season, int episode})? parseSeriesInfo(
    String name,
  ) {
    for (final pattern in _seriesPatterns) {
      final match = pattern.firstMatch(name);
      if (match != null) {
        final seriesName = name.substring(0, match.start).trim();
        final season = int.tryParse(match.group(1)!) ?? 1;
        final episode = int.tryParse(match.group(2)!) ?? 1;
        return (
          seriesName: seriesName.isNotEmpty ? seriesName : name,
          season: season,
          episode: episode,
        );
      }
    }
    return null;
  }

  // ── Public API ─────────────────────────────────────────────

  /// Parses raw M3U content into a [PlaylistDTO].
  ///
  /// [content] is the full text of the M3U file.
  /// [sourceUrl] is an optional URL the playlist was downloaded from; it is
  /// stored on the returned DTO for bookkeeping.
  ///
  /// Throws [FormatException] if [content] is empty or yields no channels.
  static PlaylistDTO parse(String content, {String? sourceUrl}) {
    if (content.trim().isEmpty) {
      throw const FormatException('M3U content is empty.');
    }

    // Normalise line endings to LF.
    final normalised = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final lines = normalised.split('\n');
    final channels = <ChannelDTO>[];

    String? pendingExtInf;
    final pendingVlcOpts = <String, String>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip empty lines and the #EXTM3U header.
      if (line.isEmpty) continue;
      if (line.toUpperCase().startsWith('#EXTM3U')) continue;

      // Capture #EXTINF lines for the next URL.
      if (line.startsWith('#EXTINF:')) {
        pendingExtInf = line;
        pendingVlcOpts.clear();
        continue;
      }

      // Capture #EXTVLCOPT lines (appear between #EXTINF and the URL).
      if (line.startsWith('#EXTVLCOPT:')) {
        final optValue = line.substring('#EXTVLCOPT:'.length).trim();
        final eqIndex = optValue.indexOf('=');
        if (eqIndex > 0) {
          final key = optValue.substring(0, eqIndex).trim();
          final val = optValue.substring(eqIndex + 1).trim();
          pendingVlcOpts[key] = val;
        }
        continue;
      }

      // Skip other directives / comments.
      if (line.startsWith('#')) continue;

      // At this point the line should be a URL (or path).
      final url = line;
      if (url.isEmpty) continue;

      // Build the ChannelDTO.
      if (pendingExtInf != null) {
        final channel = _parseExtInfLine(pendingExtInf, url, pendingVlcOpts);
        if (channel != null) {
          channels.add(channel);
        }
        pendingExtInf = null;
        pendingVlcOpts.clear();
      } else {
        // Bare URL without #EXTINF -- derive a name from the URL.
        final name = _nameFromUrl(url);
        final isVodContent = _isVodUrl(url);
        ContentType contentType;
        String? seriesName;
        int? seasonNumber;
        int? episodeNumber;

        if (isVodContent) {
          final seriesInfo = parseSeriesInfo(name);
          if (seriesInfo != null) {
            contentType = ContentType.series;
            seriesName = seriesInfo.seriesName;
            seasonNumber = seriesInfo.season;
            episodeNumber = seriesInfo.episode;
          } else {
            contentType = ContentType.movie;
          }
        } else {
          contentType = ContentType.live;
        }

        channels.add(ChannelDTO(
          name: name,
          streamUrl: url,
          contentType: contentType,
          seriesName: seriesName,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        ));
      }
    }

    if (channels.isEmpty) {
      throw const FormatException(
        'No valid channels found in the M3U content.',
      );
    }

    return PlaylistDTO(
      channels: channels,
      url: sourceUrl,
    );
  }

  /// Extracts a single attribute value from an #EXTINF tag line.
  ///
  /// Supports both quoted (`tvg-id="ABC"`) and unquoted (`tvg-id=ABC`)
  /// attribute values. Returns `null` if the attribute is not present.
  ///
  /// This method is public so it can be used in unit tests.
  static String? extractAttribute(String line, String attribute) {
    // Try quoted value first: attribute="value"
    // The regex handles commas and spaces inside quoted values.
    final quotedPattern = RegExp(
      '${RegExp.escape(attribute)}\\s*=\\s*"([^"]*)"',
      caseSensitive: false,
    );
    final quotedMatch = quotedPattern.firstMatch(line);
    if (quotedMatch != null) {
      return quotedMatch.group(1);
    }

    // Try unquoted value: attribute=value (terminated by space or end of
    // the attribute section, i.e. before the comma that precedes the
    // channel name).
    final unquotedPattern = RegExp(
      '${RegExp.escape(attribute)}\\s*=\\s*([^\\s",]+)',
      caseSensitive: false,
    );
    final unquotedMatch = unquotedPattern.firstMatch(line);
    if (unquotedMatch != null) {
      return unquotedMatch.group(1);
    }

    return null;
  }

  // ── Private helpers ────────────────────────────────────────

  /// Parses an #EXTINF line + its associated URL into a [ChannelDTO].
  ///
  /// Returns `null` if the line is too malformed to extract a usable channel.
  static ChannelDTO? _parseExtInfLine(
    String extInfLine,
    String url,
    Map<String, String> vlcOpts,
  ) {
    // #EXTINF:-1 tvg-id="..." tvg-name="..." tvg-logo="..." group-title="...",Channel Name
    // Find the *last* comma that separates attributes from the display name.
    // We search for the last comma because channel names typically follow
    // it, and attribute values may themselves contain commas when quoted.
    final commaIndex = _findNameSeparatorComma(extInfLine);
    String name;
    String attributeSection;

    if (commaIndex != -1) {
      name = extInfLine.substring(commaIndex + 1).trim();
      attributeSection = extInfLine.substring(0, commaIndex);
    } else {
      // No comma found -- use URL-derived name as fallback.
      name = _nameFromUrl(url);
      attributeSection = extInfLine;
    }

    // If the name is empty after trimming, fall back to URL.
    if (name.isEmpty) {
      name = _nameFromUrl(url);
    }

    final tvgId = extractAttribute(attributeSection, 'tvg-id');
    final tvgName = extractAttribute(attributeSection, 'tvg-name');
    final tvgLogo = extractAttribute(attributeSection, 'tvg-logo');
    final groupTitle = extractAttribute(attributeSection, 'group-title');

    // Collect any extra known attributes into the extras map.
    final extras = <String, String>{...vlcOpts};

    final tvgShift = extractAttribute(attributeSection, 'tvg-shift');
    if (tvgShift != null) extras['tvg-shift'] = tvgShift;

    final tvgLanguage = extractAttribute(attributeSection, 'tvg-language');
    if (tvgLanguage != null) extras['tvg-language'] = tvgLanguage;

    final radio = extractAttribute(attributeSection, 'radio');
    if (radio != null) extras['radio'] = radio;

    final isVodContent = _isVodUrl(url) || _isVodGroup(groupTitle);
    ContentType contentType;
    String? seriesName;
    int? seasonNumber;
    int? episodeNumber;

    if (isVodContent) {
      final seriesInfo = parseSeriesInfo(name);
      if (seriesInfo != null) {
        contentType = ContentType.series;
        seriesName = seriesInfo.seriesName;
        seasonNumber = seriesInfo.season;
        episodeNumber = seriesInfo.episode;
      } else {
        contentType = ContentType.movie;
      }
    } else {
      contentType = ContentType.live;
    }

    return ChannelDTO(
      name: name,
      streamUrl: url,
      groupTitle: groupTitle,
      tvgId: tvgId,
      tvgName: tvgName,
      tvgLogo: tvgLogo,
      contentType: contentType,
      seriesName: seriesName,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      extras: extras,
    );
  }

  /// Finds the comma index that separates the attribute section from the
  /// channel display name in an #EXTINF line.
  ///
  /// This correctly skips commas that appear inside double-quoted attribute
  /// values.
  static int _findNameSeparatorComma(String line) {
    var inQuotes = false;
    var lastComma = -1;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        lastComma = i;
      }
    }

    return lastComma;
  }

  /// Determines whether a URL points to a VOD file based on its extension.
  static bool _isVodUrl(String url) {
    try {
      // Strip query parameters and fragments before checking the extension.
      final path = Uri.parse(url).path.toLowerCase();
      for (final ext in _vodExtensions) {
        if (path.endsWith(ext)) return true;
      }
    } catch (_) {
      // If the URL is malformed, fall through to false.
    }
    return false;
  }

  /// Determines whether a group title suggests VOD content.
  static bool _isVodGroup(String? groupTitle) {
    if (groupTitle == null || groupTitle.isEmpty) return false;
    final lower = groupTitle.toLowerCase();
    return _vodGroupKeywords.any(
      (keyword) => lower.contains(keyword),
    );
  }

  /// Derives a human-readable name from a URL, used as a fallback when no
  /// #EXTINF display name is available.
  static String _nameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        var last = segments.last;
        // Remove file extension for cleaner display.
        final dotIndex = last.lastIndexOf('.');
        if (dotIndex > 0) {
          last = last.substring(0, dotIndex);
        }
        // Replace common separators with spaces.
        return last
            .replaceAll(RegExp(r'[_\-+]'), ' ')
            .replaceAll(RegExp(r'%20'), ' ')
            .trim();
      }
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }
}
