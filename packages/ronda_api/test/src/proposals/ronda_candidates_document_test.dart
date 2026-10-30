import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  Map<String, Object?> person({Object? warnings = const ['slot']}) => {
    'uid': 'gabi',
    'firstName': 'Gabi',
    'ageBand': '30-39',
    'barrio': 'el-pinar-norte',
    'slots': ['tue-evening'],
    'pretexts': ['truco'],
    'warnings': warnings,
    'blocks': 9,
    'rondaId': 'r2',
    'rondaLine': 'Martes a la noche · truco',
  };

  Map<String, Object?> candidates({List<Object?>? people}) => {
    'rondaId': 'r1',
    'line': 'Sábado a la tarde · mate en la rambla',
    'members': ['Ana', 'Beto'],
    'taken': 2,
    'cap': 6,
    'people': people ?? [person()],
  };

  group(RondaCandidatesDocument, () {
    test('reads the ronda and who could join it', () {
      final document = RondaCandidatesDocument.fromJson(candidates());

      expect(document.rondaId, 'r1');
      expect(document.line, 'Sábado a la tarde · mate en la rambla');
      expect(document.members, ['Ana', 'Beto']);
      expect((document.taken, document.cap), (2, 6));
      final gabi = document.people.single;
      expect(gabi.uid, 'gabi');
      expect(gabi.firstName, 'Gabi');
      expect(gabi.ageBand, '30-39');
      expect(gabi.barrio, 'el-pinar-norte');
      expect(gabi.slots, ['tue-evening']);
      expect(gabi.pretexts, ['truco']);
      expect(gabi.warnings, ['slot']);
      expect(gabi.blocks, 9);
      expect(gabi.rondaId, 'r2');
      expect(gabi.rondaLine, 'Martes a la noche · truco');
    });

    final malformed = <String, Object?>{
      'something else': 'x',
      'a person of another shape': candidates(people: [<String, Object?>{}]),
      'a warning that is not a string': candidates(
        people: [
          person(warnings: [1]),
        ],
      ),
    };
    for (final MapEntry(key: name, value: data) in malformed.entries) {
      test('throws a $FormatException for $name', () {
        expect(
          () => RondaCandidatesDocument.fromJson(data),
          throwsFormatException,
        );
      });
    }
  });

  group(AddToRondaDocument, () {
    test('reads who joined and from where', () {
      final document = AddToRondaDocument.fromJson({
        'rondaId': 'r1',
        'uid': 'gabi',
        'warnings': ['barrio'],
        'movedFrom': 'r2',
      });

      expect(document.rondaId, 'r1');
      expect(document.uid, 'gabi');
      expect(document.warnings, ['barrio']);
      expect(document.movedFrom, 'r2');
    });

    test('throws a $FormatException for another shape', () {
      expect(() => AddToRondaDocument.fromJson(null), throwsFormatException);
    });
  });
}
