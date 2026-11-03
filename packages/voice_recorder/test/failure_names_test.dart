import 'package:flutter_test/flutter_test.dart';
import 'package:voice_recorder/voice_recorder.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const VoiceRecorderException().toString(),
        equals('VoiceRecorderException'),
      );
    });
  });
}
