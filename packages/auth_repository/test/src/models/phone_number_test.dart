import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Every number here is invented for the tests; none is anyone's phone.
void main() {
  group(PhoneNumber, () {
    group('tryParse', () {
      const mobiles = {
        '+598 99 000 001': '+59899000001',
        '+59899000001': '+59899000001',
        '+598 099 000 001': '+59899000001',
        '099 000 001': '+59899000001',
        '99000001': '+59899000001',
        '099-000-001': '+59899000001',
        '(099) 000.001': '+59899000001',
        '+1 650 555 0100': '+16505550100',
        '+44 7700 900000': '+447700900000',
      };

      for (final MapEntry(key: typed, value: e164) in mobiles.entries) {
        test('reads "$typed" as $e164', () {
          expect(PhoneNumber.tryParse(typed)?.e164, equals(e164));
          expect(PhoneNumber.validate(typed), isNull);
        });
      }

      const errors = {
        '': PhoneNumberError.empty,
        '   ': PhoneNumberError.empty,
        '+598': PhoneNumberError.empty,
        '+598 ': PhoneNumberError.empty,
        '+598 2 000 0001': PhoneNumberError.notMobile,
        '4000 0001': PhoneNumberError.notMobile,
        '+598 99 000 00': PhoneNumberError.invalid,
        '+598 99 000 0011': PhoneNumberError.invalid,
        '+598 abc': PhoneNumberError.invalid,
        '+598 3000 0001': PhoneNumberError.invalid,
        '+': PhoneNumberError.invalid,
        '+0 650 555 0100': PhoneNumberError.invalid,
        '+1 555': PhoneNumberError.invalid,
        '+1 650 555 0100 0000 00': PhoneNumberError.invalid,
      };

      for (final MapEntry(key: typed, value: error) in errors.entries) {
        test('refuses "$typed" with $error', () {
          expect(PhoneNumber.tryParse(typed), isNull);
          expect(PhoneNumber.validate(typed), equals(error));
        });
      }
    });

    group('display', () {
      test('groups a Uruguayan mobile as +598 9X XXX XXX', () {
        expect(
          PhoneNumber.tryParse('099000001')!.display,
          equals('+598 99 000 001'),
        );
      });

      test('shows any other number as E.164', () {
        expect(
          PhoneNumber.tryParse('+1 650 555 0100')!.display,
          equals('+16505550100'),
        );
      });
    });

    test('compares by value', () {
      expect(
        PhoneNumber.tryParse('099 000 001'),
        equals(PhoneNumber.tryParse('+59899000001')),
      );
    });

    test('hides the number in toString', () {
      final number = PhoneNumber.tryParse('099 000 001')!;

      expect(number.toString(), equals('PhoneNumber(hidden)'));
      expect(number.toString(), isNot(contains('000')));
    });
  });
}
