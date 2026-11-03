import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(const SignOutFailure().toString(), equals('SignOutFailure'));
      expect(const AdminClaimFailure().toString(), equals('AdminClaimFailure'));
      expect(
        const OpenCreateAccountFailure().toString(),
        equals('OpenCreateAccountFailure'),
      );
    });
  });
}
