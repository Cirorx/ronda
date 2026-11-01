import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/phone_login/phone_login.dart';

// Invented numbers, nobody's phone.
void main() {
  group(PhoneNumberInput, () {
    test('starts with +598 and no number', () {
      const input = PhoneNumberInput.pure();

      expect(input.value, equals('+598 '));
      expect(input.phoneNumber, isNull);
      expect(input.error, equals(PhoneNumberError.empty));
    });

    test('reads a valid number', () {
      const input = PhoneNumberInput.dirty('+598 99 000 001');

      expect(input.isValid, isTrue);
      expect(input.phoneNumber?.e164, equals('+59899000001'));
    });

    test('says why a number is not valid', () {
      expect(
        const PhoneNumberInput.dirty('2 000 0001').error,
        equals(PhoneNumberError.notMobile),
      );
    });

    test('defaults a dirty field to empty', () {
      expect(const PhoneNumberInput.dirty().value, isEmpty);
    });
  });

  group(SmsCode, () {
    test('takes six digits, spaces apart', () {
      const code = SmsCode.dirty('123 456');

      expect(code.isValid, isTrue);
      expect(code.digits, equals('123456'));
    });

    for (final typed in ['', '12345', '1234567', '12a456']) {
      test('refuses "$typed"', () {
        expect(
          SmsCode.dirty(typed).error,
          equals(SmsCodeValidationError.invalid),
        );
      });
    }

    test('starts empty', () {
      expect(const SmsCode.pure().value, isEmpty);
    });
  });
}
