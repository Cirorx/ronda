import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding_repository/onboarding_repository.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const NoMicrophoneFailure().toString(),
        equals('NoMicrophoneFailure'),
      );
      expect(
        const MicrophoneDeniedFailure().toString(),
        equals('MicrophoneDeniedFailure'),
      );
      expect(
        const StartVoiceNoteFailure().toString(),
        equals('StartVoiceNoteFailure'),
      );
      expect(
        const RecordVoiceNoteFailure().toString(),
        equals('RecordVoiceNoteFailure'),
      );
      expect(
        const TermsNotAcceptedFailure().toString(),
        equals('TermsNotAcceptedFailure'),
      );
      expect(
        const VoiceNoteNotUnderstoodFailure().toString(),
        equals('VoiceNoteNotUnderstoodFailure'),
      );
      expect(
        const ReadVoiceNoteFailure().toString(),
        equals('ReadVoiceNoteFailure'),
      );
    });
  });
}
