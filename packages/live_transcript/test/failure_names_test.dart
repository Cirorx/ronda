import 'package:flutter_test/flutter_test.dart';
import 'package:live_transcript/live_transcript.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const LiveTranscriptException().toString(),
        equals('LiveTranscriptException'),
      );
    });
  });
}
