import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(User, () {
    test('supports value equality', () {
      expect(const User(id: 'a'), equals(const User(id: 'a')));
      expect(const User(id: 'a'), isNot(equals(const User(id: 'b'))));
    });

    group('isEmpty', () {
      test('is true for ${User.empty}', () {
        expect(User.empty.isEmpty, isTrue);
        expect(User.empty.isNotEmpty, isFalse);
      });

      test('is false for a signed-in $User', () {
        expect(const User(id: 'a').isEmpty, isFalse);
        expect(const User(id: 'a').isNotEmpty, isTrue);
      });
    });
  });
}
