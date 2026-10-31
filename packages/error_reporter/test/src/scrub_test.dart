import 'package:error_reporter/src/scrub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scrub', () {
    for (final (text, expected) in [
      ('mail vecina@example.com now', 'mail <email> now'),
      ('call 099 123 456', 'call <number>'),
      ('call +598 99 123 456', 'call <number>'),
      (
        'GET https://x.test/y?token=abc&a=1 failed',
        'GET https://x.test/y?<query> failed',
      ),
      ('https://x.test/y stays', 'https://x.test/y stays'),
      ('said "me duele la rodilla" today', 'said <text> today'),
      ("said 'hola' and «chau»", 'said <text> and <text>'),
      (
        'users/Xy7k2PqR9sT1uV3wZ5aB8cD0eF4g/private/eligible',
        'users/<id>/private/eligible',
      ),
      (
        '_OnboardingVoiceRecorderState stays',
        '_OnboardingVoiceRecorderState stays',
      ),
      ('package:ronda/app.dart:123:45', 'package:ronda/app.dart:123:45'),
    ]) {
      test('turns "$text" into "$expected"', () {
        expect(scrub(text), equals(expected));
      });
    }
  });

  group('scrubMessage', () {
    test('keeps the first line only', () {
      expect(
        scrubMessage('FormatException: bad\nMarta, 60-69, Solymar\n^'),
        equals('FormatException: bad'),
      );
    });

    test('caps the length', () {
      expect(scrubMessage('a' * 1000).length, equals(maxMessageLength));
    });
  });

  group('scrubStack', () {
    test('is empty for an empty stack', () {
      expect(scrubStack('  '), isEmpty);
    });

    test('keeps $maxStackLines frames at most', () {
      final stack = [for (var n = 0; n < 100; n++) '#$n frame'].join('\n');
      expect(scrubStack(stack).split('\n'), hasLength(maxStackLines));
    });

    test('caps the length', () {
      expect(scrubStack('a' * 5000).length, equals(maxStackLength));
    });
  });

  group('uidHash', () {
    test('matches the server hash', () {
      // functions/tests/test_client_errors.py checks the same value.
      expect(uidHash('abc'), equals('21679a36ee4baa70'));
    });
  });
}
