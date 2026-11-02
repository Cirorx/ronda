import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SignInWithGoogleFailure, () {
    test('defaults to ${SignInWithGoogleFailureReason.unknown}', () {
      expect(
        const SignInWithGoogleFailure().reason,
        equals(SignInWithGoogleFailureReason.unknown),
      );
    });

    group('fromCode', () {
      const expectations = {
        'popup-closed-by-user': SignInWithGoogleFailureReason.cancelled,
        'cancelled-popup-request': SignInWithGoogleFailureReason.cancelled,
        'web-context-cancelled': SignInWithGoogleFailureReason.cancelled,
        'web-context-canceled': SignInWithGoogleFailureReason.cancelled,
        'user-cancelled': SignInWithGoogleFailureReason.cancelled,
        'canceled': SignInWithGoogleFailureReason.cancelled,
        'network-request-failed': SignInWithGoogleFailureReason.network,
        'timeout': SignInWithGoogleFailureReason.network,
        'user-disabled': SignInWithGoogleFailureReason.userDisabled,
        'internal-error': SignInWithGoogleFailureReason.unknown,
      };

      for (final MapEntry(key: code, value: reason) in expectations.entries) {
        test('maps $code to $reason', () {
          expect(SignInWithGoogleFailure.fromCode(code).reason, equals(reason));
        });
      }
    });

    test('names its reason in toString', () {
      expect(
        const SignInWithGoogleFailure(SignInWithGoogleFailureReason.network)
            .toString(),
        equals(
          'SignInWithGoogleFailure(SignInWithGoogleFailureReason.network)',
        ),
      );
    });
  });

  group(SendPhoneCodeFailure, () {
    test('defaults to ${SendPhoneCodeFailureReason.unknown}', () {
      expect(
        const SendPhoneCodeFailure().reason,
        equals(SendPhoneCodeFailureReason.unknown),
      );
    });

    group('fromCode', () {
      const expectations = {
        'invalid-phone-number': SendPhoneCodeFailureReason.invalidNumber,
        'missing-phone-number': SendPhoneCodeFailureReason.invalidNumber,
        'too-many-requests': SendPhoneCodeFailureReason.tooManyRequests,
        'quota-exceeded': SendPhoneCodeFailureReason.unavailable,
        'operation-not-allowed': SendPhoneCodeFailureReason.unavailable,
        'app-not-authorized': SendPhoneCodeFailureReason.unavailable,
        'invalid-app-credential': SendPhoneCodeFailureReason.unavailable,
        'missing-client-identifier': SendPhoneCodeFailureReason.unavailable,
        'captcha-check-failed': SendPhoneCodeFailureReason.unavailable,
        'web-context-cancelled': SendPhoneCodeFailureReason.cancelled,
        'web-context-canceled': SendPhoneCodeFailureReason.cancelled,
        'user-cancelled': SendPhoneCodeFailureReason.cancelled,
        'network-request-failed': SendPhoneCodeFailureReason.network,
        'timeout': SendPhoneCodeFailureReason.network,
        'internal-error': SendPhoneCodeFailureReason.unknown,
      };

      for (final MapEntry(key: code, value: reason) in expectations.entries) {
        test('maps $code to $reason', () {
          expect(SendPhoneCodeFailure.fromCode(code).reason, equals(reason));
        });
      }
    });

    test('names its reason in toString', () {
      expect(
        const SendPhoneCodeFailure(SendPhoneCodeFailureReason.tooSoon)
            .toString(),
        equals('SendPhoneCodeFailure(SendPhoneCodeFailureReason.tooSoon)'),
      );
    });
  });

  group(ConfirmPhoneCodeFailure, () {
    test('defaults to ${ConfirmPhoneCodeFailureReason.unknown}', () {
      expect(
        const ConfirmPhoneCodeFailure().reason,
        equals(ConfirmPhoneCodeFailureReason.unknown),
      );
    });

    group('fromCode', () {
      const expectations = {
        'invalid-verification-code': ConfirmPhoneCodeFailureReason.invalidCode,
        'missing-verification-code': ConfirmPhoneCodeFailureReason.invalidCode,
        'session-expired': ConfirmPhoneCodeFailureReason.expired,
        'code-expired': ConfirmPhoneCodeFailureReason.expired,
        'invalid-verification-id': ConfirmPhoneCodeFailureReason.expired,
        'too-many-requests': ConfirmPhoneCodeFailureReason.tooManyRequests,
        'network-request-failed': ConfirmPhoneCodeFailureReason.network,
        'timeout': ConfirmPhoneCodeFailureReason.network,
        'user-disabled': ConfirmPhoneCodeFailureReason.userDisabled,
        'internal-error': ConfirmPhoneCodeFailureReason.unknown,
      };

      for (final MapEntry(key: code, value: reason) in expectations.entries) {
        test('maps $code to $reason', () {
          expect(ConfirmPhoneCodeFailure.fromCode(code).reason, equals(reason));
        });
      }
    });

    test('names its reason in toString', () {
      expect(
        const ConfirmPhoneCodeFailure(ConfirmPhoneCodeFailureReason.expired)
            .toString(),
        equals(
          'ConfirmPhoneCodeFailure(ConfirmPhoneCodeFailureReason.expired)',
        ),
      );
    });
  });

  group(AdminClaimFailure, () {
    test('is an $Exception', () {
      expect(const AdminClaimFailure(), isA<Exception>());
    });
  });
}
