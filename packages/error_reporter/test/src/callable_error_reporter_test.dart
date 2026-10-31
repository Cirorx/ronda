import 'package:cloud_functions/cloud_functions.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions;

class _MockCallable extends Mock implements HttpsCallable;

class _MockResult extends Mock implements HttpsCallableResult<Object?>;

const _app = AppInfo(
  platform: 'web',
  version: '1.0.0',
  build: '3',
  flavor: 'production',
);

void main() {
  group(CallableErrorReporter, () {
    late FirebaseFunctions functions;
    late HttpsCallable callable;

    setUp(() {
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(CallableErrorReporter.callableName))
          .thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => _MockResult());
    });

    List<List<Object?>> calls() => [
      for (final data in verify(
        () => callable.call<Object?>(captureAny<Object?>()),
      ).captured)
        ((data as Map<String, Object>)['reports']! as List<Object?>),
    ];

    Future<void> report(CallableErrorReporter reporter, String code) =>
        reporter.reportFailure(screen: '/s', step: 'x', code: code);

    test('sends the reports together after the delay', () async {
      final reporter = CallableErrorReporter(
        functions: functions,
        app: _app,
        flushDelay: Duration.zero,
      );

      await report(reporter, 'a');
      await report(reporter, 'b');
      verifyNever(() => callable.call<Object?>(any<Object?>()));
      await pumpEventQueue();

      final sent = calls().single;
      expect(sent, hasLength(2));
      expect(sent.first, containsPair('code', 'a'));
    });

    test('sends a fatal error at once', () async {
      final reporter = CallableErrorReporter(functions: functions, app: _app);

      await reporter.recordError(Exception('x'), null, fatal: true);

      expect(calls().single.single, containsPair('fatal', true));
    });

    test('sends each code and screen once', () async {
      final reporter = CallableErrorReporter(functions: functions, app: _app);

      await report(reporter, 'a');
      await report(reporter, 'a');
      await reporter.flush();

      expect(calls().single, hasLength(1));
    });

    test('sends at most maxPerSession reports, '
        '${CallableErrorReporter.batchSize} a call', () async {
      final reporter = CallableErrorReporter(
        functions: functions,
        app: _app,
        maxPerSession: 12,
      );

      for (var n = 0; n < 30; n++) {
        await report(reporter, 'code$n');
      }
      await reporter.flush();

      expect(calls().map((batch) => batch.length), [10, 2]);
    });

    test('drops what waits when a call fails', () async {
      when(() => callable.call<Object?>(any<Object?>())).thenThrow(
        FirebaseFunctionsException(message: 'no', code: 'unavailable'),
      );
      final reporter = CallableErrorReporter(functions: functions, app: _app);

      for (var n = 0; n < 15; n++) {
        await report(reporter, 'code$n');
      }
      await reporter.flush();
      await reporter.flush();

      verify(() => callable.call<Object?>(any<Object?>())).called(1);
    });
  });
}
