import 'package:flutter_test/flutter_test.dart';
import 'package:needs_repository/needs_repository.dart';

void main() {
  group(Needs, () {
    test('are equal when they hold the same needs in any order', () {
      expect(
        const Needs({Need.noCar, Need.walkALot}),
        equals(const Needs({Need.walkALot, Need.noCar})),
      );
    });

    test('differ when they hold different needs', () {
      expect(
        const Needs({Need.noCar}),
        isNot(equals(const Needs({Need.climbStairs}))),
      );
    });

    test('none holds no needs', () {
      expect(Needs.none.values, isEmpty);
    });
  });
}
