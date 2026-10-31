import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

void main() {
  group(SmallPlanKind, () {
    test('reads the names the server uses, and any other as other', () {
      expect(SmallPlanKind.fromName('noPhone'), equals(SmallPlanKind.noPhone));
      expect(SmallPlanKind.fromName('walk'), equals(SmallPlanKind.walk));
      expect(SmallPlanKind.fromName('swim'), equals(SmallPlanKind.other));
    });
  });

  group(PlanDropReason, () {
    test('reads the reasons the server uses, and any other as unclear', () {
      expect(PlanDropReason.fromName('diet'), equals(PlanDropReason.diet));
      expect(PlanDropReason.fromName('???'), equals(PlanDropReason.unclear));
    });
  });

  group(SmallPlan, () {
    final plan = SmallPlan(
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 3, 19),
      place: 'desde la parada 23',
      activity: 'Caminar 30 minutos por la rambla',
    );

    test('goes to its stored shape and back', () {
      expect(SmallPlan.fromJson(plan.toJson()), equals(plan));
    });

    test('leaves out what it does not have', () {
      final bare = SmallPlan(
        kind: SmallPlanKind.call,
        at: DateTime(2026, 11, 3, 18),
      );

      expect(bare.toJson().keys, unorderedEquals(['kind', 'at']));
      expect(SmallPlan.fromJson(bare.toJson()), equals(bare));
    });

    test('throws a $FormatException for any other shape', () {
      expect(
        () => SmallPlan.fromJson(const {'kind': 'walk'}),
        throwsFormatException,
      );
      expect(() => SmallPlan.fromJson('walk'), throwsFormatException);
    });
  });

  group(SmallPlanSuggestion, () {
    test('reads the wire shape into a plan with a day and a time', () {
      final suggestion = SmallPlanSuggestion.fromDocument(
        const SmallPlanSuggestionDocument(
          id: 'feria-1',
          kind: 'feria',
          place: 'la Feria de Solymar',
          date: '2026-11-07',
          time: '10:00',
          outdoor: true,
          dry: true,
        ),
      );

      expect(suggestion.at, equals(DateTime(2026, 11, 7, 10)));
      expect(
        suggestion.plan,
        equals(
          SmallPlan(
            kind: SmallPlanKind.feria,
            at: DateTime(2026, 11, 7, 10),
            place: 'la Feria de Solymar',
          ),
        ),
      );
    });

    test('suggestions compare by value', () {
      SmallPlanSuggestion build() => SmallPlanSuggestion(
        id: 'walk-1',
        kind: SmallPlanKind.walk,
        at: DateTime(2026, 11, 3, 18),
        outdoor: true,
      );

      expect(build(), equals(build()));
    });

    test('throws a $FormatException for a day or a time it cannot read', () {
      for (final (date, time) in [('nope', '10:00'), ('2026-11-07', '10')]) {
        expect(
          () => SmallPlanSuggestion.parseWhen(date, time),
          throwsFormatException,
        );
      }
    });
  });

  group('the cards and readings compare by value', () {
    final plan = SmallPlan(
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 3, 19),
    );

    test('cards', () {
      expect(const SmallPlanOffer().props, isEmpty);
      expect(const SmallPlanNothing().props, isEmpty);
      expect(SmallPlanSet(plan), equals(SmallPlanSet(plan)));
      expect(SmallPlanFollowUp(plan), equals(SmallPlanFollowUp(plan)));
      expect(SmallPlanSet(plan), isNot(equals(SmallPlanFollowUp(plan))));
    });

    test('readings', () {
      expect(SmallPlanRead(plan: plan), equals(SmallPlanRead(plan: plan)));
      expect(
        const SmallPlanDropped(PlanDropReason.diet),
        equals(const SmallPlanDropped(PlanDropReason.diet)),
      );
    });

    test('a failure names its kind', () {
      expect(
        const SmallPlanFailure(SmallPlanFailureKind.readFailed).toString(),
        equals('SmallPlanFailure(readFailed)'),
      );
    });
  });
}
