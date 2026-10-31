import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:error_reporter/src/client_error_log.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ClientErrorLog, () {
    group('watchRecent', () {
      test('reads the newest reports first', () async {
        final firestore = FakeFirebaseFirestore();
        final errors = firestore.collection(ClientErrorLog.collection);
        await errors.doc('old').set({
          'platform': 'web',
          'appVersion': '1.0.0',
          'build': '3',
          'flavor': 'production',
          'screen': '/onboarding',
          'step': 'voiceUpload',
          'code': 'voice/uploadFailed',
          'message': '',
          'stack': '',
          'fatal': false,
          'at': Timestamp.fromDate(DateTime.utc(2026, 10, 30, 20)),
        });
        await errors.doc('new').set({
          'code': 42,
          'fatal': true,
          'at': Timestamp.fromDate(DateTime.utc(2026, 10, 30, 21)),
        });

        final log = ClientErrorLog(firestore: firestore);
        final recent = await log.watchRecent(limit: 2).first;

        expect(recent.map((error) => error.id), ['new', 'old']);
        expect(recent.first.code, isEmpty);
        expect(recent.first.fatal, isTrue);
        expect(
          recent.last,
          equals(
            ClientError(
              id: 'old',
              platform: 'web',
              appVersion: '1.0.0',
              build: '3',
              flavor: 'production',
              screen: '/onboarding',
              step: 'voiceUpload',
              code: 'voice/uploadFailed',
              message: '',
              stack: '',
              fatal: false,
              at: DateTime.utc(2026, 10, 30, 20).toLocal(),
            ),
          ),
        );
      });

      test('reads a report with no time as the epoch', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection(ClientErrorLog.collection).doc('a').set({
          'code': 'x',
        });

        final recent = await ClientErrorLog(firestore: firestore)
            .watchRecent()
            .first;

        expect(
          recent.single.at,
          equals(DateTime.fromMillisecondsSinceEpoch(0)),
        );
      });

      for (final (code, reason) in [
        ('permission-denied', ClientErrorLogFailureReason.forbidden),
        ('unavailable', ClientErrorLogFailureReason.other),
      ]) {
        test('fails with ${reason.name} on $code', () async {
          final failing = Stream<int>.error(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          );

          await expectLater(
            failing.transform(failuresAsClientErrorLogFailure()),
            emitsError(
              isA<ClientErrorLogFailure>().having(
                (failure) => failure.reason,
                'reason',
                reason,
              ),
            ),
          );
        });
      }
    });
  });

  group(ClientErrorLogFailure, () {
    test('names its reason', () {
      expect(
        const ClientErrorLogFailure(ClientErrorLogFailureReason.forbidden)
            .toString(),
        equals('ClientErrorLogFailure(forbidden)'),
      );
    });
  });
}
