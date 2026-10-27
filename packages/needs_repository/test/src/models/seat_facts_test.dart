import 'package:flutter_test/flutter_test.dart';
import 'package:needs_repository/needs_repository.dart';

void main() {
  group(SeatFacts, () {
    SeatFacts seat({bool hasStairs = false}) => SeatFacts(
      seatId: 'seat-1',
      walkDistance: WalkDistance.medium,
      hasStairs: hasStairs,
      endsAfterDark: false,
      needsCar: false,
    );

    test('are equal when every fact matches', () {
      expect(seat(), equals(seat()));
    });

    test('differ when one fact differs', () {
      expect(seat(), isNot(equals(seat(hasStairs: true))));
    });
  });
}
