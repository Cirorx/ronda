import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

const _app = AppInfo(
  platform: 'android',
  version: '1.0.0',
  build: '3',
  flavor: 'development',
);

void main() {
  group(LocalErrorReporter, () {
    test('logs the code, screen and step only', () async {
      final lines = <String>[];
      final reporter = LocalErrorReporter(app: _app, logger: lines.add)
        ..setScreen('/ronda');

      await reporter.recordError(
        Exception('Marta'),
        null,
        step: 'MyRondaCubit',
      );
      await reporter.recordError(Exception('x'), null, fatal: true);

      expect(lines, [
        'error report: _Exception on "/ronda" (MyRondaCubit)',
        'error report: _Exception on "/ronda" (), fatal',
      ]);
    });

    test('logs with dart:developer by default', () async {
      await expectLater(
        LocalErrorReporter(app: _app).recordError(Exception('x'), null),
        completes,
      );
    });
  });
}
