import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SignInAccount, () {
    test('supports value equality', () {
      expect(
        const SignInAccount(method: SignInMethod.google, address: 'a@b.uy'),
        equals(
          const SignInAccount(method: SignInMethod.google, address: 'a@b.uy'),
        ),
      );
      expect(
        const SignInAccount(method: SignInMethod.google, address: 'a@b.uy'),
        isNot(equals(const SignInAccount(method: SignInMethod.phone))),
      );
    });

    group('displayAddress', () {
      test('spaces a Uruguayan mobile', () {
        expect(
          const SignInAccount(
            method: SignInMethod.phone,
            address: '+59899123456',
          ).displayAddress,
          equals('+598 99 123 456'),
        );
      });

      test("keeps another country's number as it is", () {
        expect(
          const SignInAccount(
            method: SignInMethod.phone,
            address: '+5491112345678',
          ).displayAddress,
          equals('+5491112345678'),
        );
      });

      test('keeps the email as it is', () {
        expect(
          const SignInAccount(
            method: SignInMethod.google,
            address: 'vecina@example.com',
          ).displayAddress,
          equals('vecina@example.com'),
        );
      });

      test('is null without an address', () {
        expect(
          const SignInAccount(method: SignInMethod.phone).displayAddress,
          isNull,
        );
      });
    });

    test('hides the address from toString', () {
      expect(
        const SignInAccount(
          method: SignInMethod.google,
          address: 'vecina@example.com',
        ).toString(),
        isNot(contains('vecina')),
      );
    });
  });
}
