import 'package:error_reporter/error_reporter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _app = AppInfo(
  platform: 'web',
  version: '1.0.0',
  build: '3',
  flavor: 'production',
);

/// Keeps what it is sent, or throws when [failing].
class _Recording extends ErrorReporter {
  new({this.failing = false}) : super(app: _app);

  final bool failing;
  final sent = <ErrorReport>[];

  @override
  Future<void> send(ErrorReport report) async {
    if (failing) throw Exception('offline');
    sent.add(report);
  }
}

class const _Typed(final String text) {
  @override
  String toString() => text;
}

void main() {
  group(ErrorReporter, () {
    late _Recording reporter;

    setUp(() => reporter = _Recording());

    group('setScreen', () {
      test('scrubs and caps the screen', () {
        reporter.setScreen('/x?id=1 ${'s' * 200}');

        expect(reporter.screen, startsWith('/x'));
        expect(reporter.screen.length, equals(maxLabelLength));
      });
    });

    group('setUser', () {
      test('keeps nothing by default', () async {
        await expectLater(reporter.setUser('uid'), completes);
      });
    });

    group('recordError', () {
      test('sends the code, the scrubbed first line and stack, '
          'with the screen', () async {
        reporter.setScreen('/onboarding');

        await reporter.recordError(
          const _Typed('No "Marta" for vecina@example.com\nsecond line'),
          StackTrace.fromString('#0 main (package:ronda/main.dart:1:2)'),
          fatal: true,
          step: 'OnboardingCubit',
        );

        expect(
          reporter.sent.single,
          equals(
            const ErrorReport(
              app: _app,
              screen: '/onboarding',
              step: 'OnboardingCubit',
              code: '_Typed',
              message: 'No <text> for <email>',
              stack: '#0 main (package:ronda/main.dart:1:2)',
              fatal: true,
            ),
          ),
        );
      });

      test('sends an empty stack when there is none', () async {
        await reporter.recordError(Exception('x'), null);

        expect(reporter.sent.single.stack, isEmpty);
        expect(reporter.sent.single.fatal, isFalse);
      });

      test('swallows a failure to send', () async {
        final failing = _Recording(failing: true);

        await expectLater(failing.recordError(Exception('x'), null), completes);
      });
    });

    group('reportFailure', () {
      test('sends where and a typed code, with no message or stack', () async {
        await reporter.reportFailure(
          screen: '/onboarding',
          step: 'voiceUpload',
          code: 'voice/uploadFailed',
        );

        expect(
          reporter.sent.single,
          equals(
            const ErrorReport(
              app: _app,
              screen: '/onboarding',
              step: 'voiceUpload',
              code: 'voice/uploadFailed',
            ),
          ),
        );
      });
    });

    group('errorCode', () {
      test('is plugin/code for a Firebase error', () {
        expect(
          ErrorReporter.errorCode(
            FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
          ),
          equals('firebase_storage/unauthorized'),
        );
      });

      test("is the type's name for anything else", () {
        expect(
          ErrorReporter.errorCode(const FormatException()),
          equals('FormatException'),
        );
      });
    });
  });

  group(ErrorReport, () {
    test('has the shape report_client_error takes', () {
      expect(
        const ErrorReport(
          app: _app,
          screen: '/a',
          step: 'b',
          code: 'c',
          message: 'd',
          stack: 'e',
        ).toJson(),
        equals({
          'platform': 'web',
          'appVersion': '1.0.0',
          'build': '3',
          'flavor': 'production',
          'screen': '/a',
          'step': 'b',
          'code': 'c',
          'message': 'd',
          'stack': 'e',
          'fatal': false,
        }),
      );
    });
  });
}
