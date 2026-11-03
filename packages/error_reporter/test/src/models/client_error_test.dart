import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ClientError, () {
    ClientError error({
      String message = 'RsvpFailure(offline)',
      String stack = '#0 a',
    }) => ClientError(
      id: '1',
      platform: 'web',
      appVersion: '1.0.0',
      build: '3',
      flavor: 'production',
      screen: '/ronda',
      step: 'AttendanceCubit',
      code: 'RsvpFailure',
      message: message,
      stack: stack,
      fatal: false,
      at: DateTime.utc(2026, 11, 2, 22, 5),
    );

    group('reportText', () {
      test('names screen, step, code, message, build, time and stack', () {
        expect(
          error().reportText,
          equals(
            'screen: /ronda\n'
            'step: AttendanceCubit\n'
            'code: RsvpFailure\n'
            'message: RsvpFailure(offline)\n'
            'platform: web\n'
            'build: 1.0.0 (3) production\n'
            'fatal: false\n'
            'time: 2026-11-02T22:05:00.000Z\n'
            'stack:\n'
            '#0 a',
          ),
        );
      });

      test('writes a dash for what is empty', () {
        final text = error(message: '', stack: '').reportText;

        expect(text, contains('message: -'));
        expect(text, endsWith('stack:\n-'));
      });

      test('writes a dash for no screen or step', () {
        final empty = ClientError(
          id: '1',
          platform: 'web',
          appVersion: '1',
          build: '1',
          flavor: 'production',
          screen: '',
          step: '',
          code: 'x',
          message: '',
          stack: '',
          fatal: true,
          at: DateTime.utc(2026),
        );

        expect(
          empty.reportText,
          allOf(contains('screen: -'), contains('step: -')),
        );
      });
    });
  });
}
