import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  group(SeatFactsDocument, () {
    Map<String, Object?> json() => {
      'barrio': 'solymar-norte',
      'pretext': 'truco',
      'slot': 'sat-afternoon',
      'blocksFrom': {'solymar-sur': 9.1, 'solymar-norte': 0},
      'hasStairs': true,
      'endsAfterDark': false,
      'needsCar': false,
      'updatedAt': '2026-10-27T19:00:00Z',
    };

    group('fromJson', () {
      test('reads every fact, with the document id as the seat id', () {
        final document = SeatFactsDocument.fromJson(
          'solymar-norte_truco_sat-afternoon',
          json(),
        );

        expect(document.seatId, equals('solymar-norte_truco_sat-afternoon'));
        expect(document.barrio, equals('solymar-norte'));
        expect(document.pretext, equals('truco'));
        expect(document.slot, equals('sat-afternoon'));
        expect(
          document.blocksFrom,
          equals({'solymar-sur': 9.1, 'solymar-norte': 0.0}),
        );
        expect(document.blocksFrom, isA<Map<String, double>>());
        expect(document.hasStairs, isTrue);
        expect(document.endsAfterDark, isFalse);
        expect(document.needsCar, isFalse);
      });

      for (final field in [
        'barrio',
        'pretext',
        'slot',
        'blocksFrom',
        'hasStairs',
        'endsAfterDark',
        'needsCar',
      ]) {
        test('throws $FormatException when $field is missing', () {
          expect(
            () => SeatFactsDocument.fromJson('seat', json()..remove(field)),
            throwsFormatException,
          );
        });
      }

      test('throws $FormatException when a fact has the wrong type', () {
        expect(
          () =>
              SeatFactsDocument.fromJson('seat', json()..['hasStairs'] = 'yes'),
          throwsFormatException,
        );
      });

      test('throws $FormatException when a walk in blocksFrom is not a '
          'number', () {
        expect(
          () => SeatFactsDocument.fromJson(
            'seat',
            json()..['blocksFrom'] = {'solymar-sur': 'cerca'},
          ),
          throwsFormatException,
        );
      });
    });
  });
}
