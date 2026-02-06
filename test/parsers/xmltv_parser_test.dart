import 'package:flutter_test/flutter_test.dart';
import 'package:aly_player/core/parsers/xmltv_parser.dart';

void main() {
  group('XMLTVParser', () {
    test('parses basic XMLTV document', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="ch1">
    <display-name>Channel 1</display-name>
  </channel>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>News at Noon</title>
    <desc>Daily news broadcast</desc>
    <category>News</category>
  </programme>
  <programme start="20250115130000 +0000" stop="20250115140000 +0000" channel="ch1">
    <title>Afternoon Show</title>
    <sub-title>Episode 5</sub-title>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.channels.length, 1);
      expect(result.channels[0].id, 'ch1');
      expect(result.channels[0].displayName, 'Channel 1');

      expect(result.programs.length, 2);
      expect(result.programs[0].channelId, 'ch1');
      expect(result.programs[0].title, 'News at Noon');
      expect(result.programs[0].description, 'Daily news broadcast');
      expect(result.programs[0].category, 'News');
      expect(result.programs[1].title, 'Afternoon Show');
      expect(result.programs[1].subtitle, 'Episode 5');
    });

    test('parses XMLTV date format correctly (UTC)', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20250615080000 +0000" stop="20250615090000 +0000" channel="test">
    <title>Morning Show</title>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.programs.length, 1);
      expect(result.programs[0].startTime.year, 2025);
      expect(result.programs[0].startTime.month, 6);
      expect(result.programs[0].startTime.day, 15);
      expect(result.programs[0].startTime.hour, 8);
      expect(result.programs[0].endTime.hour, 9);
    });

    test('converts timezone offset to UTC', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20250115120000 +0100" stop="20250115130000 +0100" channel="ch1">
    <title>Noon Show</title>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      // 12:00 +0100 should become 11:00 UTC
      expect(result.programs[0].startTime.hour, 11);
      expect(result.programs[0].endTime.hour, 12);
    });

    test('handles missing optional fields', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Simple Program</title>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.programs.length, 1);
      expect(result.programs[0].title, 'Simple Program');
      expect(result.programs[0].description, isNull);
      expect(result.programs[0].subtitle, isNull);
      expect(result.programs[0].category, isNull);
      expect(result.programs[0].iconUrl, isNull);
    });

    test('handles programme with icon', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show with Icon</title>
    <icon src="https://example.com/icon.png"/>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.programs.length, 1);
      expect(result.programs[0].iconUrl, 'https://example.com/icon.png');
    });

    test('returns empty result for XML with no programmes', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv></tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.isEmpty, true);
      expect(result.channels, isEmpty);
      expect(result.programs, isEmpty);
    });

    test('throws FormatException for invalid XML', () {
      expect(
        () => XMLTVParser.parse('not xml at all'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty content', () {
      expect(
        () => XMLTVParser.parse(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles multiple channels', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="ch1"><display-name>Channel 1</display-name></channel>
  <channel id="ch2"><display-name>Channel 2</display-name></channel>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Program on Ch1</title>
  </programme>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch2">
    <title>Program on Ch2</title>
  </programme>
  <programme start="20250115130000 +0000" stop="20250115140000 +0000" channel="ch1">
    <title>Next on Ch1</title>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.channels.length, 2);
      expect(result.programs.length, 3);

      final ch1Programs =
          result.programs.where((p) => p.channelId == 'ch1').toList();
      final ch2Programs =
          result.programs.where((p) => p.channelId == 'ch2').toList();
      expect(ch1Programs.length, 2);
      expect(ch2Programs.length, 1);
    });

    test('parses date without timezone offset (assumed UTC)', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20250115120000" stop="20250115130000" channel="ch1">
    <title>No Timezone</title>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.programs.length, 1);
      expect(result.programs[0].startTime.hour, 12);
      expect(result.programs[0].startTime.isUtc, true);
    });

    test('channel with icon is parsed', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="ch1">
    <display-name>Channel 1</display-name>
    <icon src="https://example.com/ch1-logo.png"/>
  </channel>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.channels.length, 1);
      expect(result.channels[0].iconUrl, 'https://example.com/ch1-logo.png');
    });

    test('programme duration getter works', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20250115120000 +0000" stop="20250115133000 +0000" channel="ch1">
    <title>90 Minute Show</title>
  </programme>
</tv>''';

      final result = XMLTVParser.parse(xml);

      expect(result.programs[0].duration, const Duration(hours: 1, minutes: 30));
    });
  });
}
