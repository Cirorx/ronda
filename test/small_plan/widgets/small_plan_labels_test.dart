import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/small_plan/widgets/small_plan_labels.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SmallPlanLabels', () {
    late AppLocalizations l10n;

    Future<void> pump(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpApp(
        Builder(
          builder: (context) {
            l10n = context.l10n;
            return const SizedBox();
          },
        ),
        locale: locale ?? rioplatense,
      );
    }

    final tuesday = DateTime(2026, 11, 3, 19);
    SmallPlan plan(SmallPlanKind kind, {String? place, String? activity}) =>
        SmallPlan(kind: kind, at: tuesday, place: place, activity: activity);

    testWidgets('words the day and the hour', (tester) async {
      await pump(tester);

      expect(l10n.planWhen(tuesday), equals('el martes a las 19:00'));
      expect(
        l10n.planWhen(DateTime(2026, 11, 8, 9, 5)),
        equals('el domingo a las 09:05'),
      );
    });

    testWidgets('words each suggestion from its kind and place', (
      tester,
    ) async {
      await pump(tester);

      expect(
        l10n.planWhat(plan(SmallPlanKind.walk, place: 'la Rambla')),
        equals('Caminar 30 minutos por la Rambla'),
      );
      expect(
        l10n.planWhat(plan(SmallPlanKind.walk)),
        equals('Caminar 30 minutos cerca de casa'),
      );
      expect(
        l10n.planWhat(plan(SmallPlanKind.feria, place: 'la Feria')),
        equals('Ir a la Feria'),
      );
      expect(l10n.planWhat(plan(SmallPlanKind.feria)), equals('Ir a la feria'));
      expect(
        l10n.planWhat(plan(SmallPlanKind.library, place: 'la Biblioteca')),
        equals('Pasar por la Biblioteca'),
      );
      expect(
        l10n.planWhat(plan(SmallPlanKind.library)),
        equals('Pasar por la biblioteca'),
      );
      expect(
        l10n.planWhat(plan(SmallPlanKind.call)),
        equals('Llamar a alguien con quien hace tiempo no hablás'),
      );
      expect(
        l10n.planWhat(plan(SmallPlanKind.noPhone)),
        equals('Una tarde sin el celular'),
      );
      expect(
        l10n.planWhat(plan(SmallPlanKind.other)),
        equals('Caminar 30 minutos cerca de casa'),
      );
    });

    testWidgets('keeps the words a member said, with their place after '
        'the day', (tester) async {
      await pump(tester);

      expect(
        l10n.planLine(
          plan(
            SmallPlanKind.walk,
            activity: 'Caminar 30 minutos por la rambla',
            place: 'desde la parada 23',
          ),
        ),
        equals(
          'Caminar 30 minutos por la rambla, el martes a las 19:00, '
          'desde la parada 23.',
        ),
      );
    });

    testWidgets('does not repeat the place of a suggestion', (tester) async {
      await pump(tester);

      expect(
        l10n.planLine(plan(SmallPlanKind.walk, place: 'la Rambla')),
        equals('Caminar 30 minutos por la Rambla, el martes a las 19:00.'),
      );
    });

    testWidgets('asks about each kind in the language of the phone', (
      tester,
    ) async {
      await pump(tester);

      expect(
        l10n.followUp(plan(SmallPlanKind.walk)),
        equals('¿Saliste a caminar el martes?'),
      );
      expect(
        l10n.followUp(plan(SmallPlanKind.feria)),
        equals('¿Fuiste a la feria el martes?'),
      );
      expect(
        l10n.followUp(plan(SmallPlanKind.library)),
        equals('¿Pasaste por la biblioteca el martes?'),
      );
      expect(
        l10n.followUp(plan(SmallPlanKind.call)),
        equals('¿Pudiste hacer esa llamada el martes?'),
      );
      expect(
        l10n.followUp(plan(SmallPlanKind.noPhone)),
        equals('¿Pudiste tener tu tarde sin el celular el martes?'),
      );
      expect(
        l10n.followUp(plan(SmallPlanKind.other)),
        equals('¿Pudiste hacer lo que te propusiste el martes?'),
      );
    });

    testWidgets('reads the same in English', (tester) async {
      await pump(tester, locale: const Locale('en'));

      expect(l10n.planWhen(tuesday), equals('Tuesday at 19:00'));
      expect(
        l10n.followUp(plan(SmallPlanKind.walk)),
        equals('Did you go for a walk on Tuesday?'),
      );
    });

    testWidgets('says what the forecast says of an outdoor day, and '
        'nothing indoors or without one', (tester) async {
      await pump(tester);

      expect(
        l10n.forecastNote(outdoor: true, dry: true),
        equals('No se espera lluvia ese día.'),
      );
      expect(
        l10n.forecastNote(outdoor: true, dry: false),
        equals('Se espera lluvia ese día. Si querés, cambialo.'),
      );
      expect(l10n.forecastNote(outdoor: true), isNull);
      expect(l10n.forecastNote(outdoor: false, dry: true), isNull);
    });

    testWidgets('says why the sheet is back on "Decilo vos"', (tester) async {
      await pump(tester);

      expect(
        l10n.sayProblem(dropped: PlanDropReason.unclear),
        equals(l10n.smallPlanNotUnderstood),
      );
      for (final reason in [
        PlanDropReason.health,
        PlanDropReason.diet,
        PlanDropReason.money,
        PlanDropReason.people,
      ]) {
        expect(l10n.sayProblem(dropped: reason), equals(l10n.smallPlanDropped));
      }
      expect(
        l10n.sayProblem(failure: SmallPlanFailureKind.notUnderstood),
        equals(l10n.smallPlanNotUnderstood),
      );
      expect(
        l10n.sayProblem(failure: SmallPlanFailureKind.noMicrophone),
        equals(l10n.smallPlanNoMicrophone),
      );
      expect(
        l10n.sayProblem(failure: SmallPlanFailureKind.microphoneDenied),
        equals(l10n.smallPlanMicrophoneDenied),
      );
      expect(
        l10n.sayProblem(failure: SmallPlanFailureKind.uploadFailed),
        equals(l10n.smallPlanReadFailed),
      );
      expect(l10n.sayProblem(), isNull);
    });
  });
}
