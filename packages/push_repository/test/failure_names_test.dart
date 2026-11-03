import 'package:flutter_test/flutter_test.dart';
import 'package:push_repository/push_repository.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const RegisterDeviceFailure().toString(),
        equals('RegisterDeviceFailure'),
      );
      expect(
        const UnregisterDeviceFailure().toString(),
        equals('UnregisterDeviceFailure'),
      );
      expect(
        const SnoozePromptFailure().toString(),
        equals('SnoozePromptFailure'),
      );
      expect(
        const PushPermissionFailure().toString(),
        equals('PushPermissionFailure'),
      );
    });
  });
}
