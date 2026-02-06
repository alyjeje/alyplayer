/// Data transfer objects and enums used across the AlyPlayer application.
///
/// These DTOs serve as intermediate representations between raw parsed data
/// (M3U files, XMLTV feeds) and the drift database entities. They are
/// intentionally decoupled from the database layer so parsers remain pure
/// and independently testable.
library;

// ─── Enums ─────────────────────────────────────────────────

/// The mechanism by which a playlist was imported into the app.
enum PlaylistImportSource {
  url('url'),
  file('file'),
  clipboard('clipboard'),
  qrCode('qr_code');

  const PlaylistImportSource(this.value);

  /// Stable string representation persisted in storage / analytics.
  final String value;

  /// Resolve from a stored string value, defaulting to [url] if unknown.
  static PlaylistImportSource fromValue(String raw) {
    return PlaylistImportSource.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => PlaylistImportSource.url,
    );
  }
}

/// Discrete states the video player can be in.
enum AppPlayerState {
  /// Player has been created but has no media loaded.
  idle,

  /// Media is being opened / buffered.
  loading,

  /// Media is actively rendering frames.
  playing,

  /// Playback has been paused by the user.
  paused,

  /// A recoverable error occurred (e.g. temporary network issue).
  error,

  /// An unrecoverable failure (e.g. unsupported codec, 404 stream).
  failed,
}

/// In-app subscription tier.
enum SubscriptionTier {
  free,
  premium,
}

// ─── Channel DTO ───────────────────────────────────────────

/// Lightweight representation of a single channel / VOD entry parsed from an
/// M3U playlist. Contains only the raw data extracted from the file -- no
/// database IDs or user-specific state (favorites, watch progress, etc.).
class ChannelDTO {
  const ChannelDTO({
    required this.name,
    required this.streamUrl,
    this.groupTitle,
    this.tvgId,
    this.tvgName,
    this.tvgLogo,
    this.isVod = false,
    this.extras = const {},
  });

  /// Display name of the channel extracted from the #EXTINF line.
  final String name;

  /// The stream / file URL following the #EXTINF metadata line.
  final String streamUrl;

  /// Group title attribute, used for categorisation (e.g. "Sports", "News").
  final String? groupTitle;

  /// EPG identifier used to match EPG programme data to this channel.
  final String? tvgId;

  /// Alternative channel name used by some EPG providers.
  final String? tvgName;

  /// URL to the channel logo / thumbnail image.
  final String? tvgLogo;

  /// Whether this entry is a Video-On-Demand item rather than a live stream.
  final bool isVod;

  /// Catch-all map for any additional parsed attributes not covered above
  /// (e.g. `tvg-shift`, `tvg-language`, `radio`, custom VLCOPT values).
  final Map<String, String> extras;

  @override
  String toString() =>
      'ChannelDTO(name: $name, url: $streamUrl, group: $groupTitle, '
      'vod: $isVod)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelDTO &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          streamUrl == other.streamUrl;

  @override
  int get hashCode => Object.hash(name, streamUrl);
}

// ─── Playlist DTO ──────────────────────────────────────────

/// Represents a fully parsed M3U playlist containing zero or more channels.
class PlaylistDTO {
  const PlaylistDTO({
    required this.channels,
    this.name,
    this.url,
  });

  /// All channel / VOD entries contained in this playlist.
  final List<ChannelDTO> channels;

  /// Optional human-readable playlist name (derived from filename, URL, or
  /// user input).
  final String? name;

  /// The URL the playlist was originally fetched from, if applicable.
  final String? url;

  // ── Convenience getters ──

  /// Only live (non-VOD) channels.
  List<ChannelDTO> get liveChannels =>
      channels.where((c) => !c.isVod).toList(growable: false);

  /// Only Video-On-Demand entries.
  List<ChannelDTO> get vodChannels =>
      channels.where((c) => c.isVod).toList(growable: false);

  /// Distinct, sorted set of group titles (categories) present in this
  /// playlist. Channels without a group are excluded.
  List<String> get categories {
    final groups = <String>{};
    for (final channel in channels) {
      if (channel.groupTitle != null && channel.groupTitle!.isNotEmpty) {
        groups.add(channel.groupTitle!);
      }
    }
    final sorted = groups.toList()..sort();
    return sorted;
  }

  /// Total number of channels (live + VOD).
  int get channelCount => channels.length;

  @override
  String toString() =>
      'PlaylistDTO(name: $name, channels: $channelCount, '
      'live: ${liveChannels.length}, vod: ${vodChannels.length})';
}

// ─── EPG DTOs ──────────────────────────────────────────────

/// A single programme entry parsed from an XMLTV feed.
class EPGProgramDTO {
  const EPGProgramDTO({
    required this.channelId,
    required this.title,
    this.subtitle,
    this.description,
    required this.startTime,
    required this.endTime,
    this.category,
    this.iconUrl,
  });

  /// The XMLTV channel id this programme belongs to (matches
  /// [EPGChannelDTO.id]).
  final String channelId;

  /// Programme title.
  final String title;

  /// Optional sub-title / episode name.
  final String? subtitle;

  /// Long-form programme description.
  final String? description;

  /// Scheduled start time (UTC).
  final DateTime startTime;

  /// Scheduled end time (UTC).
  final DateTime endTime;

  /// Genre / category tag (e.g. "Sports", "Drama").
  final String? category;

  /// URL to a programme poster / thumbnail.
  final String? iconUrl;

  /// Whether this programme is currently airing.
  bool get isLive {
    final now = DateTime.now().toUtc();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Duration of the programme.
  Duration get duration => endTime.difference(startTime);

  @override
  String toString() => 'EPGProgramDTO($title, $startTime - $endTime)';
}

/// Metadata for a channel as declared in an XMLTV feed.
class EPGChannelDTO {
  const EPGChannelDTO({
    required this.id,
    required this.displayName,
    this.iconUrl,
  });

  /// Unique channel identifier within the XMLTV file (used to link programmes).
  final String id;

  /// Human-readable channel name.
  final String displayName;

  /// Optional channel logo URL.
  final String? iconUrl;

  @override
  String toString() => 'EPGChannelDTO($id: $displayName)';
}

/// Aggregate result of parsing an XMLTV document.
class EPGParseResult {
  const EPGParseResult({
    required this.channels,
    required this.programs,
  });

  /// All <channel> elements found in the feed.
  final List<EPGChannelDTO> channels;

  /// All <programme> elements found in the feed.
  final List<EPGProgramDTO> programs;

  /// Whether the parse yielded any usable data.
  bool get isEmpty => channels.isEmpty && programs.isEmpty;

  @override
  String toString() =>
      'EPGParseResult(channels: ${channels.length}, '
      'programs: ${programs.length})';
}
