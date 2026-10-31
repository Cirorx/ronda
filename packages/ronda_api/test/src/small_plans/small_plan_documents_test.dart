import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  group(SmallPlanSuggestionDocument, () {
    test('reads a suggestion with a place and a dry day', () {
      expect(
        SmallPlanSuggestionDocument.fromJson(const {
          'id': 'walk-1',
          'kind': 'walk',
          'place': 'la Plaza de los Aromos',
          'date': '2026-11-03',
          'time': '18:00',
          'outdoor': true,
          'dry': true,
        }),
        equals(
          const SmallPlanSuggestionDocument(
            id: 'walk-1',
            kind: 'walk',
            place: 'la Plaza de los Aromos',
            date: '2026-11-03',
            time: '18:00',
            outdoor: true,
            dry: true,
          ),
        ),
      );
    });

    test('reads a suggestion with no place and no word on the rain', () {
      final suggestion = SmallPlanSuggestionDocument.fromJson(const {
        'id': 'call-1',
        'kind': 'call',
        'place': null,
        'date': '2026-11-03',
        'time': '18:00',
        'outdoor': false,
        'dry': null,
      });

      expect(suggestion.place, isNull);
      expect(suggestion.dry, isNull);
    });

    test('throws a $FormatException for any other shape', () {
      expect(
        () => SmallPlanSuggestionDocument.fromJson(const {'id': 'walk-1'}),
        throwsFormatException,
      );
      expect(
        () => SmallPlanSuggestionDocument.fromJson('walk'),
        throwsFormatException,
      );
    });
  });

  group(SmallPlanAnswer, () {
    const plan = {
      'activity': 'Caminar 30 minutos por la rambla',
      'date': '2026-11-03',
      'time': '19:00',
      'place': 'desde la parada 23',
      'kind': 'walk',
      'outdoor': true,
      'dry': false,
      'moved': true,
    };

    test('reads a plan', () {
      expect(
        SmallPlanAnswer.fromJson(const {'plan': plan}),
        equals(
          const SmallPlanShaped(
            ShapedSmallPlanDocument(
              activity: 'Caminar 30 minutos por la rambla',
              date: '2026-11-03',
              time: '19:00',
              place: 'desde la parada 23',
              kind: 'walk',
              outdoor: true,
              dry: false,
              moved: true,
            ),
          ),
        ),
      );
    });

    test('reads a plan with no place and no word on the rain', () {
      final json = {
        'plan': <String, Object?>{...plan, 'place': null, 'dry': null},
      };

      final answer = SmallPlanAnswer.fromJson(json);

      final shaped = (answer as SmallPlanShaped).plan;
      expect(shaped.place, isNull);
      expect(shaped.dry, isNull);
    });

    test('reads a rejection with its reason', () {
      expect(
        SmallPlanAnswer.fromJson(const {'rejected': 'health'}),
        equals(const SmallPlanRejected('health')),
      );
    });

    test('throws a $FormatException for any other shape', () {
      for (final json in <Object?>[
        null,
        const {
          'plan': {'activity': 'x'},
        },
        const {'rejected': 5},
        'plan',
      ]) {
        expect(() => SmallPlanAnswer.fromJson(json), throwsFormatException);
      }
    });
  });
}
