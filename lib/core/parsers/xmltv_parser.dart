/// XMLTV (Electronic Programme Guide) parser.
///
/// Parses XMLTV-formatted XML documents into structured [EPGParseResult]
/// objects containing channel metadata and programme listings.
///
/// Conforms to the XMLTV DTD specification:
/// - `<channel>` elements with `id`, `<display-name>`, and optional `<icon>`
/// - `<programme>` elements with `start`, `stop`, `channel` attributes and
///   child elements `<title>`, `<sub-title>`, `<desc>`, `<category>`, `<icon>`
///
/// Date/time attributes are parsed from the common XMLTV format:
/// `"YYYYMMDDHHmmss +HHMM"` and the variant without a timezone offset.
library;

import 'package:xml/xml.dart';

import 'package:aly_player/core/models/dtos.dart';

/// Static utility class for parsing XMLTV content.
class XMLTVParser {
  XMLTVParser._(); // prevent instantiation

  /// Parses raw XMLTV content into an [EPGParseResult].
  ///
  /// Throws [FormatException] if [content] is empty or not valid XML.
  static EPGParseResult parse(String content) {
    if (content.trim().isEmpty) {
      throw const FormatException('XMLTV content is empty.');
    }

    final XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } on XmlException catch (e) {
      throw FormatException('Invalid XMLTV XML: ${e.message}');
    }

    final tv = document.rootElement;

    // Parse channels.
    final channels = <EPGChannelDTO>[];
    for (final element in tv.findElements('channel')) {
      final channel = _parseChannel(element);
      if (channel != null) {
        channels.add(channel);
      }
    }

    // Parse programmes.
    final programs = <EPGProgramDTO>[];
    for (final element in tv.findElements('programme')) {
      final program = _parseProgramme(element);
      if (program != null) {
        programs.add(program);
      }
    }

    return EPGParseResult(
      channels: channels,
      programs: programs,
    );
  }

  // ── Private helpers ────────────────────────────────────────

  /// Parses a single `<channel>` element.
  ///
  /// Returns `null` if the element is missing the required `id` attribute
  /// or has no `<display-name>`.
  static EPGChannelDTO? _parseChannel(XmlElement element) {
    final id = element.getAttribute('id');
    if (id == null || id.isEmpty) return null;

    // A channel may have multiple <display-name> elements; take the first.
    final displayNameElement = element.findElements('display-name').firstOrNull;
    if (displayNameElement == null) return null;
    final displayName = displayNameElement.innerText.trim();
    if (displayName.isEmpty) return null;

    // Optional icon.
    String? iconUrl;
    final iconElement = element.findElements('icon').firstOrNull;
    if (iconElement != null) {
      iconUrl = iconElement.getAttribute('src');
    }

    return EPGChannelDTO(
      id: id,
      displayName: displayName,
      iconUrl: iconUrl,
    );
  }

  /// Parses a single `<programme>` element.
  ///
  /// Returns `null` if required attributes/elements are missing or if the
  /// date strings are unparseable. Programmes without a `<title>` are
  /// skipped per the requirements.
  static EPGProgramDTO? _parseProgramme(XmlElement element) {
    final channelId = element.getAttribute('channel');
    final startStr = element.getAttribute('start');
    final stopStr = element.getAttribute('stop');

    if (channelId == null || channelId.isEmpty) return null;
    if (startStr == null || stopStr == null) return null;

    final startTime = _parseXmltvDate(startStr);
    final endTime = _parseXmltvDate(stopStr);
    if (startTime == null || endTime == null) return null;

    // Title is required.
    final titleElement = element.findElements('title').firstOrNull;
    if (titleElement == null) return null;
    final title = titleElement.innerText.trim();
    if (title.isEmpty) return null;

    // Optional fields.
    final subtitle = _textOfFirst(element, 'sub-title');
    final description = _textOfFirst(element, 'desc');
    final category = _textOfFirst(element, 'category');

    String? iconUrl;
    final iconElement = element.findElements('icon').firstOrNull;
    if (iconElement != null) {
      iconUrl = iconElement.getAttribute('src');
    }

    return EPGProgramDTO(
      channelId: channelId,
      title: title,
      subtitle: subtitle,
      description: description,
      startTime: startTime,
      endTime: endTime,
      category: category,
      iconUrl: iconUrl,
    );
  }

  /// Returns the trimmed inner text of the first child element with the given
  /// [tagName], or `null` if no such element exists or the text is empty.
  static String? _textOfFirst(XmlElement parent, String tagName) {
    final el = parent.findElements(tagName).firstOrNull;
    if (el == null) return null;
    final text = el.innerText.trim();
    return text.isEmpty ? null : text;
  }

  /// Parses an XMLTV date/time string into a UTC [DateTime].
  ///
  /// Supported formats:
  /// - `"20250115120000 +0100"` (with timezone offset)
  /// - `"20250115120000"`       (no timezone, assumed UTC)
  ///
  /// Returns `null` if the string cannot be parsed.
  static DateTime? _parseXmltvDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < 14) return null;

    try {
      final year = int.parse(trimmed.substring(0, 4));
      final month = int.parse(trimmed.substring(4, 6));
      final day = int.parse(trimmed.substring(6, 8));
      final hour = int.parse(trimmed.substring(8, 10));
      final minute = int.parse(trimmed.substring(10, 12));
      final second = int.parse(trimmed.substring(12, 14));

      var dateTime = DateTime.utc(year, month, day, hour, minute, second);

      // Parse optional timezone offset: " +0100" or " -0530".
      if (trimmed.length > 14) {
        final offsetPart = trimmed.substring(14).trim();
        if (offsetPart.isNotEmpty) {
          final offset = _parseTimezoneOffset(offsetPart);
          if (offset != null) {
            // Subtract the offset to convert local time to UTC.
            dateTime = dateTime.subtract(offset);
          }
        }
      }

      return dateTime;
    } catch (_) {
      return null;
    }
  }

  /// Parses a timezone offset string like "+0100" or "-0530" into a
  /// [Duration]. Returns `null` if the format is invalid.
  static Duration? _parseTimezoneOffset(String offset) {
    final match = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(offset);
    if (match == null) return null;

    final sign = match.group(1) == '+' ? 1 : -1;
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);

    return Duration(hours: hours * sign, minutes: minutes * sign);
  }
}
