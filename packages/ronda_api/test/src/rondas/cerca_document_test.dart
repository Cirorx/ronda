import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  group(CercaDocument, () {
    group('fromJson', () {
      test('reads nothing from a document without counts', () {
        final cerca = CercaDocument.fromJson('lagomar-sur', const {});

        expect(cerca.barrio, 'lagomar-sur');
        expect(cerca.slotWaiting, isEmpty);
        expect(cerca.pretextWaiting, isEmpty);
      });

      test('skips rows and counts without their shape', () {
        final cerca = CercaDocument.fromJson('lagomar-sur', const {
          'rondas': [
            {'pretext': 'mate', 'slot': 'sat-afternoon'},
            'not a row',
            {'pretext': 'truco', 'slot': 'tue-evening', 'waiting': 2},
          ],
          'waiting': [
            {'pretext': 'mate', 'count': '5'},
            {'pretext': 'caminata', 'count': 1},
          ],
        });

        expect([
          for (final row in cerca.slotWaiting)
            (row.pretext, row.slot, row.count),
        ], equals([('truco', 'tue-evening', 2)]));
        expect([
          for (final count in cerca.pretextWaiting)
            (count.pretext, count.count),
        ], equals([('caminata', 1)]));
      });

      test('reads no rows when the lists have another type', () {
        final cerca = CercaDocument.fromJson('lagomar-sur', const {
          'rondas': 'none',
          'waiting': 3,
        });

        expect(cerca.slotWaiting, isEmpty);
        expect(cerca.pretextWaiting, isEmpty);
      });
    });
  });
}
