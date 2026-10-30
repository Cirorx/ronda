import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  Map<String, Object?> week() => {
    'week': '2026-W44',
    'date': '2026-10-31',
    'members': 5,
    'yes': 3,
    'no': 1,
    'unanswered': 1,
    'came': 3,
    'marked': 4,
  };

  Map<String, Object?> ronda({Object? seguimos, Object? cameBack}) => {
    'rondaId': 'r1',
    'line': 'Sábado a la tarde · mate en la rambla',
    'status': 'active',
    'members': 5,
    'cap': 6,
    'weeks': [week()],
    'cameBack': cameBack,
    'seguimos': seguimos,
  };

  Map<String, Object?> numbers({List<Object?>? rondas, Object? cameBack}) => {
    'signUps': {'profiles': 9, 'of': 10},
    'seated': {'members': 6, 'of': 9},
    'rondas': rondas ?? [ronda()],
    'cameBack': cameBack,
  };

  group(PilotNumbersDocument, () {
    test('reads every count', () {
      final document = PilotNumbersDocument.fromJson(
        numbers(
          cameBack: {'came': 1, 'of': 3},
          rondas: [
            ronda(
              cameBack: {'came': 1, 'of': 3},
              seguimos: {
                'status': 'season',
                'asked': 4,
                'yes': 3,
                'no': 1,
                'unanswered': 0,
              },
            ),
          ],
        ),
      );

      expect((document.profiles, document.signUps), (9, 10));
      expect(document.seated, 6);
      expect((document.cameBack?.count, document.cameBack?.of), (1, 3));
      final ronda1 = document.rondas.single;
      expect(ronda1.rondaId, 'r1');
      expect(ronda1.line, 'Sábado a la tarde · mate en la rambla');
      expect(ronda1.status, 'active');
      expect((ronda1.members, ronda1.cap), (5, 6));
      expect(ronda1.cameBack?.count, 1);
      final seguimos = ronda1.seguimos!;
      expect(seguimos.status, 'season');
      expect(
        (seguimos.asked, seguimos.yes, seguimos.no, seguimos.unanswered),
        (4, 3, 1, 0),
      );
      final w = ronda1.weeks.single;
      expect((w.week, w.date, w.members), ('2026-W44', '2026-10-31', 5));
      expect((w.yes, w.no, w.unanswered, w.came, w.marked), (3, 1, 1, 3, 4));
    });

    test('reads a pilot with nothing came back nor asked yet', () {
      final document = PilotNumbersDocument.fromJson(numbers());

      expect(document.cameBack, isNull);
      expect(document.rondas.single.seguimos, isNull);
    });

    final malformed = <String, Object?>{
      'something else': 'x',
      'a ronda of another shape': numbers(rondas: [<String, Object?>{}]),
      'a week of another shape': numbers(
        rondas: [
          {
            ...ronda(),
            'weeks': [<String, Object?>{}],
          },
        ],
      ),
      'counts of another shape': numbers(rondas: [ronda(seguimos: 'x')]),
      'came back of another shape': numbers(cameBack: 'x'),
    };
    for (final MapEntry(key: name, value: data) in malformed.entries) {
      test('throws a $FormatException for $name', () {
        expect(
          () => PilotNumbersDocument.fromJson(data),
          throwsFormatException,
        );
      });
    }
  });
}
