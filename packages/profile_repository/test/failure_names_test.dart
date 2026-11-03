import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const AcceptTermsFailure().toString(),
        equals('AcceptTermsFailure'),
      );
      expect(
        const SaveProfileFailure().toString(),
        equals('SaveProfileFailure'),
      );
      expect(
        const ReadPublishedSeatsFailure().toString(),
        equals('ReadPublishedSeatsFailure'),
      );
      expect(
        const SaveEligibleSeatIdsFailure().toString(),
        equals('SaveEligibleSeatIdsFailure'),
      );
      expect(
        const HoldOnPhoneFailure().toString(),
        equals('HoldOnPhoneFailure'),
      );
    });
  });
}
