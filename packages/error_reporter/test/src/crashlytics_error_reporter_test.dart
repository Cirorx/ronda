import 'package:error_reporter/error_reporter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCrashlytics extends Mock implements FirebaseCrashlytics;

const _app = AppInfo(
  platform: 'android',
  version: '1.0.0',
  build: '3',
  flavor: 'production',
);

void main() {
  group(CrashlyticsErrorReporter, () {
    late FirebaseCrashlytics crashlytics;
    late CrashlyticsErrorReporter reporter;

    setUp(() {
      crashlytics = _MockCrashlytics();
      when(() => crashlytics.setCustomKey(any(), any()))
          .thenAnswer((_) async {});
      when(() => crashlytics.setUserIdentifier(any())).thenAnswer((_) async {});
      when(
        () => crashlytics.recordError(
          any<Object>(),
          any(),
          fatal: any(named: 'fatal'),
          printDetails: any(named: 'printDetails'),
        ),
      ).thenAnswer((_) async {});
      reporter = CrashlyticsErrorReporter(crashlytics: crashlytics, app: _app);
    });

    group('setUser', () {
      test('sets the hashed uid', () async {
        await reporter.setUser('abc');

        verify(() => crashlytics.setUserIdentifier(uidHash('abc'))).called(1);
      });

      test('clears it when signed out', () async {
        await reporter.setUser(null);

        verify(() => crashlytics.setUserIdentifier('')).called(1);
      });
    });

    group('recordError', () {
      test(
        'records the scrubbed error with the screen and step keys',
        () async {
          reporter.setScreen('/ronda');

          await reporter.recordError(
            Exception('mail vecina@example.com'),
            StackTrace.fromString('#0 main (package:ronda/main.dart:1:2)'),
            fatal: true,
            step: 'MyRondaCubit',
          );

          verify(() => crashlytics.setCustomKey('screen', '/ronda')).called(1);
          verify(() => crashlytics.setCustomKey('step', 'MyRondaCubit'))
              .called(1);
          final captured = verify(
            () => crashlytics.recordError(
              captureAny<Object>(),
              captureAny(),
              fatal: true,
              printDetails: false,
            ),
          ).captured;
          expect(
            captured.first.toString(),
            equals('_Exception: Exception: mail <email>'),
          );
          expect(captured.last.toString(), contains('package:ronda/main.dart'));
        },
      );

      test('records a typed failure with no stack', () async {
        await reporter.reportFailure(
          screen: '/onboarding',
          step: 'voiceUpload',
          code: 'voice/uploadFailed',
        );

        final captured = verify(
          () => crashlytics.recordError(
            captureAny<Object>(),
            captureAny(),
            printDetails: false,
          ),
        ).captured;
        expect(captured.first.toString(), equals('voice/uploadFailed'));
        expect(captured.last, isNull);
      });
    });
  });
}
