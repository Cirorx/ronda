import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/cuaderno/cuaderno.dart';

// 2026-10-26 is a Monday; the ronda meets on Saturday 2026-10-31.
DateTime _oct(int day) => DateTime(2026, 10, day);
DateTime _nov(int day) => DateTime(2026, 11, day);

/// Monday 2026-10-26 to Sunday 2026-11-01.
final List<DateTime> _week = [for (var day = 26; day <= 32; day++) _oct(day)];

void main() {
  group(CardHook, () {
    test('turns with the day of the week, Monday first', () {
      expect([for (final day in _week) CardHook.on(day)], CardHook.values);
    });

    test('asks the same on the same weekday a week later', () {
      expect(CardHook.on(_nov(2)), CardHook.on(_oct(26)));
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

      test('turns through the rotation by weekday with no ronda', () {
        expect(
          [for (final day in _week) pick(day)],
          [
            EntryHook.rambla,
            EntryHook.corner,
            EntryHook.learned,
            EntryHook.bizcochos,
            EntryHook.bring,
            EntryHook.rambla,
            EntryHook.corner,
          ],
        );
      });

      test('never offers the postcard with no ronda to meet', () {
        expect(pick(_oct(28), weekLines: 6), EntryHook.learned);
      });

      test('asks about the meeting the day after and the one after that', () {
        expect(pick(_nov(1), meetingDate: _oct(31)), EntryHook.afterMeeting);
        expect(pick(_nov(2), meetingDate: _oct(31)), EntryHook.afterMeeting);
      });

      test('asks about the meeting once the next one is the one shown', () {
        expect(pick(_nov(1), meetingDate: _nov(7)), EntryHook.afterMeeting);
      });

      test('stops asking about the meeting on the third day', () {
        expect(pick(_nov(3), meetingDate: _nov(7)), EntryHook.corner);
      });

      test('does not ask about the meeting on the day itself', () {
        expect(pick(_oct(31), meetingDate: _oct(31)), EntryHook.rambla);
      });

      test('asks for the postcard from three lines in the week', () {
        expect(
          pick(_oct(28), meetingDate: _oct(31), weekLines: 3),
          EntryHook.postcard,
        );
        expect(
          pick(_oct(28), meetingDate: _oct(31), weekLines: 2),
          EntryHook.learned,
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
