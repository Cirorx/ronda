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
}
