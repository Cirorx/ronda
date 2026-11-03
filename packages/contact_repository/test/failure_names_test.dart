import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(const ContactFailure().toString(), equals('ContactFailure'));
    });
  });
}
