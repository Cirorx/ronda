import 'package:flutter_test/flutter_test.dart';
import 'package:safety_repository/safety_repository.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const SafetyFailure(SafetyFailureReason.forbidden).toString(),
        equals('SafetyFailure(forbidden)'),
      );
    });
  });
}
