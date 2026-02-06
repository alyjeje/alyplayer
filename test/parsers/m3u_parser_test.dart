import 'package:flutter_test/flutter_test.dart';
import 'package:aly_player/core/parsers/m3u_parser.dart';

void main() {
  group('M3UParser', () {
    test('parses basic M3U with EXTM3U header', () {
      const content = '''#EXTM3U
#EXTINF:-1 tvg-id="ch1" tvg-name="Channel 1" tvg-logo="https://logo.com/1.png" group-title="News",Channel 1
http://stream.example.com/ch1.m3u8
#EXTINF:-1 tvg-id="ch2" tvg-name="Channel 2" group-title="Sports",Channel 2
http://stream.example.com/ch2.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 2);
      expect(result.channels[0].name, 'Channel 1');
      expect(result.channels[0].streamUrl, 'http://stream.example.com/ch1.m3u8');
      expect(result.channels[0].tvgId, 'ch1');
      expect(result.channels[0].tvgName, 'Channel 1');
      expect(result.channels[0].tvgLogo, 'https://logo.com/1.png');
      expect(result.channels[0].groupTitle, 'News');
      expect(result.channels[1].name, 'Channel 2');
      expect(result.channels[1].groupTitle, 'Sports');
    });

    test('handles missing EXTM3U header', () {
      const content = '''#EXTINF:-1,Simple Channel
http://stream.example.com/simple.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 1);
      expect(result.channels[0].name, 'Simple Channel');
      expect(result.channels[0].streamUrl, 'http://stream.example.com/simple.m3u8');
    });

    test('handles missing attributes gracefully', () {
      const content = '''#EXTM3U
#EXTINF:-1,No Attributes Channel
http://stream.example.com/noattr.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 1);
      expect(result.channels[0].name, 'No Attributes Channel');
      expect(result.channels[0].tvgId, isNull);
      expect(result.channels[0].tvgLogo, isNull);
      expect(result.channels[0].groupTitle, isNull);
    });

    test('detects VOD content by file extension', () {
      const content = '''#EXTM3U
#EXTINF:-1 group-title="Action",Movie Title
http://stream.example.com/movie.mp4
#EXTINF:-1 group-title="Live",Live Channel
http://stream.example.com/live.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 2);
      expect(result.channels[0].isVod, true);
      expect(result.channels[1].isVod, false);
    });

    test('detects VOD content by group title keyword', () {
      const content = '''#EXTM3U
#EXTINF:-1 group-title="VOD Movies",My Movie
http://stream.example.com/stream1.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 1);
      expect(result.channels[0].isVod, true);
    });

    test('skips empty lines and comments', () {
      const content = '''#EXTM3U
# This is a comment

#EXTINF:-1,Channel 1
http://stream.example.com/ch1.m3u8

# Another comment
#EXTINF:-1,Channel 2
http://stream.example.com/ch2.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 2);
    });

    test('handles quoted attributes correctly', () {
      const content = '''#EXTM3U
#EXTINF:-1 tvg-id="id1" tvg-logo="https://logo.com/1.png" group-title="Group 1",Channel With Quotes
http://stream.example.com/ch1.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 1);
      expect(result.channels[0].tvgId, 'id1');
      expect(result.channels[0].tvgLogo, 'https://logo.com/1.png');
      expect(result.channels[0].groupTitle, 'Group 1');
    });

    test('throws FormatException for empty content', () {
      expect(
        () => M3UParser.parse(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('treats bare text lines as URLs (no FormatException)', () {
      // The parser treats any non-directive line as a URL, so bare text
      // becomes a channel with that text as the stream URL.
      final result = M3UParser.parse('This is not an M3U file at all');
      expect(result.channels.length, 1);
    });

    test('handles Windows-style line endings (CRLF)', () {
      const content =
          '#EXTM3U\r\n#EXTINF:-1,Channel 1\r\nhttp://stream.example.com/ch1.m3u8\r\n';

      final result = M3UParser.parse(content);

      expect(result.channels.length, 1);
      expect(result.channels[0].name, 'Channel 1');
      expect(result.channels[0].streamUrl, 'http://stream.example.com/ch1.m3u8');
    });

    test('handles large channel count', () {
      final buffer = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 1000; i++) {
        buffer.writeln(
            '#EXTINF:-1 tvg-id="ch$i" group-title="Group ${i % 10}",Channel $i');
        buffer.writeln('http://stream.example.com/ch$i.m3u8');
      }

      final result = M3UParser.parse(buffer.toString());

      expect(result.channels.length, 1000);
      expect(result.channels[999].name, 'Channel 999');
      expect(result.channels[500].groupTitle, 'Group 0');
    });

    test('stores sourceUrl on returned PlaylistDTO', () {
      const content = '''#EXTM3U
#EXTINF:-1,Channel 1
http://stream.example.com/ch1.m3u8
''';

      final result = M3UParser.parse(content, sourceUrl: 'https://my.list/playlist.m3u');

      expect(result.url, 'https://my.list/playlist.m3u');
    });

    test('convenience getters: liveChannels and vodChannels', () {
      const content = '''#EXTM3U
#EXTINF:-1 group-title="Live",Live 1
http://stream.example.com/live.m3u8
#EXTINF:-1 group-title="Action",Movie 1
http://stream.example.com/movie.mp4
#EXTINF:-1 group-title="Live",Live 2
http://stream.example.com/live2.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.liveChannels.length, 2);
      expect(result.vodChannels.length, 1);
      expect(result.channelCount, 3);
    });

    test('categories getter returns sorted unique groups', () {
      const content = '''#EXTM3U
#EXTINF:-1 group-title="Sports",Ch 1
http://stream.example.com/1.m3u8
#EXTINF:-1 group-title="News",Ch 2
http://stream.example.com/2.m3u8
#EXTINF:-1 group-title="Sports",Ch 3
http://stream.example.com/3.m3u8
#EXTINF:-1,Ch 4 No Group
http://stream.example.com/4.m3u8
''';

      final result = M3UParser.parse(content);

      expect(result.categories, ['News', 'Sports']);
    });

    test('extractAttribute works for quoted and unquoted values', () {
      const line = '#EXTINF:-1 tvg-id="abc" tvg-logo="http://x.com/a.png" group-title="News",Name';

      expect(M3UParser.extractAttribute(line, 'tvg-id'), 'abc');
      expect(M3UParser.extractAttribute(line, 'tvg-logo'), 'http://x.com/a.png');
      expect(M3UParser.extractAttribute(line, 'group-title'), 'News');
      expect(M3UParser.extractAttribute(line, 'nonexistent'), isNull);
    });
  });
}
