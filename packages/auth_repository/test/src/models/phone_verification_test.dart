import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// An invented number, nobody's phone.
final PhoneNumber _number = PhoneNumber.tryParse('099 000 001')!;
final _sentAt = DateTime.utc(2026, 11, 2, 10);

void main() {
  group(PhoneVerification, () {
    group('resendAvailableAt', () {
      for (final (sends, wait) in [
        (1, const Duration(seconds: 30)),
        (2, const Duration(seconds: 60)),
        (3, const Duration(seconds: 120)),
      ]) {
        test('is ${wait.inSeconds} s after code $sends', () {
          final verification = PhoneVerification(
            phoneNumber: _number,
            sentAt: _sentAt,
            sends: sends,
          );

          expect(verification.resendAvailableAt, equals(_sentAt.add(wait)));
        });
      }

      test('is null after the fourth code', () {
        final verification = PhoneVerification(
          phoneNumber: _number,
          sentAt: _sentAt,
          sends: 4,
        );

        expect(verification.resendAvailableAt, isNull);
      });
    });

    test('starts at one code sent', () {
      expect(
        PhoneVerification(phoneNumber: _number, sentAt: _sentAt).sends,
        equals(1),
      );
    });

    test('compares by value', () {
      expect(
        PhoneVerification(
          phoneNumber: _number,
          sentAt: _sentAt,
          verificationId: 'id',
        ),
        equals(
          PhoneVerification(
            phoneNumber: _number,
            sentAt: _sentAt,
            verificationId: 'id',
          ),
        ),
      );
    });

    test('hides the number in toString', () {
      expect(
        PhoneVerification(
          phoneNumber: _number,
          sentAt: _sentAt,
          sends: 2,
        ).toString(),
        equals('PhoneVerification(sends: 2)'),
      );
    });
  });
}
