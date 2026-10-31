import 'package:error_reporter/error_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _app = AppInfo(
  platform: 'web',
  version: '1.0.0',
  build: '3',
  flavor: 'production',
);

class _Recording extends ErrorReporter {
  new() : super(app: _app);

  final sent = <ErrorReport>[];

  @override
  Future<void> send(ErrorReport report) async => sent.add(report);
}

void main() {
  group('installErrorHooks', () {
    late _Recording reporter;
    late FlutterExceptionHandler? flutterBefore;
    late PlatformDispatcher dispatcher;

    setUp(() {
      reporter = _Recording();
      flutterBefore = FlutterError.onError;
      // The test binding's own dispatcher drops an onError it is given.
      TestWidgetsFlutterBinding.ensureInitialized();
      dispatcher = PlatformDispatcher.instance;
    });

    tearDown(() {
      FlutterError.onError = flutterBefore;
      dispatcher.onError = null;
    });

    test(
      'reports framework errors as fatal, after the handler before',
      () async {
        final seen = <FlutterErrorDetails>[];
        FlutterError.onError = seen.add;
        installErrorHooks(reporter, dispatcher: dispatcher);

        FlutterError.onError!(
          FlutterErrorDetails(
            exception: Exception('Marta'),
            stack: StackTrace.empty,
          ),
        );
        await pumpEventQueue();

        expect(seen, hasLength(1));
        expect(reporter.sent.single.step, equals('framework'));
        expect(reporter.sent.single.fatal, isTrue);
      },
    );

    test('reports uncaught errors as fatal and handles them', () async {
      final seen = <Object>[];
      dispatcher.onError = (error, _) {
        seen.add(error);
        return false;
      };
      installErrorHooks(reporter, dispatcher: dispatcher);

      final handled = dispatcher.onError!(Exception('x'), StackTrace.empty);
      await pumpEventQueue();

      expect(handled, isTrue);
      expect(seen, hasLength(1));
      expect(reporter.sent.single.step, equals('uncaught'));
    });

    test('works with no handler before', () async {
      FlutterError.onError = null;
      installErrorHooks(reporter);
      final platform = PlatformDispatcher.instance;
      addTearDown(() => platform.onError = null);

      FlutterError.onError!(FlutterErrorDetails(exception: Exception('x')));
      platform.onError!(Exception('y'), StackTrace.empty);
      await pumpEventQueue();

      expect(reporter.sent, hasLength(2));
    });
  });
}
