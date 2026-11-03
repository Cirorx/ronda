import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/cuaderno/cuaderno.dart';

// 2026-10-26 is a Monday; the ronda meets on Saturday 2026-10-31.
DateTime _oct(int day) => DateTime(2026, 10, day);
DateTime _nov(int day) => DateTime(2026, 11, day);

/// [count] days in a row from Monday 2026-10-26 (`_oct` rolls into November).
List<DateTime> _days(int count) => [
  for (var day = 26; day < 26 + count; day++) _oct(day),
];

void main() {
  group(CardHook, () {
    test('has ten more that invite something good from the barrio', () {
      expect(CardHook.values, hasLength(17));
      expect(
        CardHook.values.skip(7),
        containsAll([
          CardHook.helped,
          CardHook.laugh,
          CardHook.smell,
          CardHook.sound,
          CardHook.kindWord,
          CardHook.rondaLearned,
          CardHook.lookedNice,
          CardHook.smallWin,
          CardHook.thank,
          CardHook.goodNews,
        ]),
      );
    });

    test('turns through every hook, one a day, never the same two days in '
        'a row', () {
      final turn = [for (final day in _days(17)) CardHook.on(day)];

      expect(turn.toSet(), CardHook.values.toSet());
      for (var i = 1; i < turn.length; i++) {
        expect(turn[i], isNot(turn[i - 1]));
      }
    });

    test('asks the same on the same day, and again after a full turn', () {
      expect(CardHook.on(_oct(26)), CardHook.on(DateTime(2026, 10, 26, 18)));
      expect(CardHook.on(_oct(26 + 17)), CardHook.on(_oct(26)));
    });

    test('keeps turning across a clock change', () {
      // Uruguay has no daylight saving, but a UTC-count must not skip a day
      // where another zone does.
      final turn = [for (final day in _days(40)) CardHook.on(day)];
      for (var i = 1; i < turn.length; i++) {
        expect(
          turn[i],
          CardHook.values[(CardHook.values.indexOf(turn[i - 1]) + 1) % 17],
        );
      }
    });
  });

  group(EntryHook, () {
    group('pick', () {
      EntryHook pick(
        DateTime today, {
        DateTime? meetingDate,
        int weekLines = 0,
      }) => EntryHook.pick(
        today: today,
        meetingDate: meetingDate,
        weekLines: weekLines,
      );

      test('has ten more that invite something good from the barrio', () {
        expect(EntryHook.rotation, hasLength(15));
        expect(
          EntryHook.rotation.skip(5),
          containsAll([
            EntryHook.helped,
            EntryHook.laugh,
            EntryHook.smell,
            EntryHook.sound,
            EntryHook.kindWord,
            EntryHook.rondaLearned,
            EntryHook.lookedNice,
            EntryHook.smallWin,
            EntryHook.thank,
            EntryHook.goodNews,
          ]),
        );
      });

      test('turns through the whole rotation, one a day, with no ronda', () {
        final turn = [for (final day in _days(15)) pick(day)];

        expect(turn.toSet(), EntryHook.rotation.toSet());
        for (var i = 1; i < turn.length; i++) {
          final next =
              (EntryHook.rotation.indexOf(turn[i - 1]) + 1) %
              EntryHook.rotation.length;
          expect(turn[i], EntryHook.rotation[next]);
        }
      });

      test('asks the same on the same day, and again after a full turn', () {
        expect(pick(_oct(26)), pick(DateTime(2026, 10, 26)));
        expect(pick(_oct(26 + 15)), pick(_oct(26)));
      });

      test('never offers the postcard with no ronda to meet', () {
        expect(pick(_oct(28), weekLines: 6), EntryHook.kindWord);
      });

      test('asks about the meeting the day after and the one after that', () {
        expect(pick(_nov(1), meetingDate: _oct(31)), EntryHook.afterMeeting);
        expect(pick(_nov(2), meetingDate: _oct(31)), EntryHook.afterMeeting);
      });

      test('asks about the meeting once the next one is the one shown', () {
        expect(pick(_nov(1), meetingDate: _nov(7)), EntryHook.afterMeeting);
      });

      test('stops asking about the meeting on the third day', () {
        expect(pick(_nov(3), meetingDate: _nov(7)), EntryHook.rambla);
      });

      test('does not ask about the meeting on the day itself', () {
        expect(pick(_oct(31), meetingDate: _oct(31)), EntryHook.smallWin);
      });

      test('asks for the postcard from three lines in the week', () {
        expect(
          pick(_oct(28), meetingDate: _oct(31), weekLines: 3),
          EntryHook.postcard,
        );
        expect(
          pick(_oct(28), meetingDate: _oct(31), weekLines: 2),
          EntryHook.kindWord,
        );
      });

      test('puts the meeting before the postcard', () {
        expect(
          pick(_nov(1), meetingDate: _nov(7), weekLines: 5),
          EntryHook.afterMeeting,
        );
      });
    });
  });

  group(CuadernoState, () {
    group('hook', () {
      test('is the first of the rotation before the cuaderno is read', () {
        expect(const CuadernoState().hook, EntryHook.rambla);
      });

      test("counts the week's lines toward the postcard", () {
        final state = CuadernoState(
          status: CuadernoStatus.ready,
          today: _oct(30),
          meetingDate: _oct(31),
          cuaderno: Cuaderno(
            entries: [
              for (final day in [30, 28, 26])
                CuadernoEntry(day: _oct(day), text: 'Llovió.'),
            ],
          ),
        );

        expect(state.hook, EntryHook.postcard);
      });
    });
  });
}
