import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/small_plan/small_plan.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

import '../../helpers/helpers.dart';

class _MockSharedPlansCubit extends MockCubit<SharedPlansState>
    implements SharedPlansCubit;

void main() {
  group(SharePlanToggle, () {
    late SharedPlansCubit cubit;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final at = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19);
    final walk = SmallPlan(
      kind: SmallPlanKind.walk,
      at: at,
      place: 'desde la parada 23',
      activity: 'Caminar',
    );

    setUpAll(() {
      registerFallbackValue(walk);
    });

    setUp(() {
      cubit = _MockSharedPlansCubit();
      when(() => cubit.shareTapped(any(), any())).thenAnswer((_) async {});
      when(() => cubit.withdrawTapped()).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      SmallPlan plan, {
      SharedPlansState? state,
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(
        state ?? const SharedPlansState(status: SharedPlansStatus.ready),
      );
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(body: SharePlanToggle(plan: plan)),
        ),
        locale: locale,
      );
    }

    testWidgets('shows nothing for a plan with no place to join, a plan that '
        'passed, or while the ronda is read', (tester) async {
      for (final kind in [SmallPlanKind.call, SmallPlanKind.noPhone]) {
        await pump(tester, SmallPlan(kind: kind, at: at));
        expect(find.byType(Switch), findsNothing);
      }
      await pump(
        tester,
        SmallPlan(kind: SmallPlanKind.walk, at: DateTime(2020)),
      );
      expect(find.byType(Switch), findsNothing);
      await pump(tester, walk, state: const SharedPlansState());
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('offers "Avisarle a la ronda" with what it does', (
      tester,
    ) async {
      await pump(tester, walk);

      expect(find.text('Avisarle a la ronda'), findsOneWidget);
      expect(
        find.text(
          'Tu ronda lo ve la próxima vez que abra Mi ronda. Se suma quien '
          'quiere.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('turning it on opens the plan, worded as the screen words it', (
      tester,
    ) async {
      await pump(tester, walk);

      await tester.tap(find.byType(Switch));

      verify(() => cubit.shareTapped(walk, 'Caminar')).called(1);
    });

    testWidgets('turning it off takes the plan back', (tester) async {
      await pump(
        tester,
        walk,
        state: SharedPlansState(
          status: SharedPlansStatus.ready,
          plans: SharedPlans(
            mine: SharedPlanMine(at: at, joined: const []),
          ),
        ),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));

      verify(() => cubit.withdrawTapped()).called(1);
    });

    testWidgets('is off for a plan shared for another time', (tester) async {
      await pump(
        tester,
        walk,
        state: SharedPlansState(
          status: SharedPlansStatus.ready,
          plans: SharedPlans(
            mine: SharedPlanMine(
              at: at.add(const Duration(hours: 1)),
              joined: const [],
            ),
          ),
        ),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('cannot be tapped while it is on its way', (tester) async {
      await pump(
        tester,
        walk,
        state: const SharedPlansState(
          status: SharedPlansStatus.ready,
          sharing: true,
        ),
      );

      await tester.tap(find.byType(Switch));

      verifyNever(() => cubit.shareTapped(any(), any()));
    });

    testWidgets('names who joined by first name, and nothing when nobody '
        'has', (tester) async {
      SharedPlansState shared(List<String> joined) => SharedPlansState(
        status: SharedPlansStatus.ready,
        plans: SharedPlans(
          mine: SharedPlanMine(at: at, joined: joined),
        ),
      );

      await pump(tester, walk, state: shared(const []));
      expect(find.textContaining('Se suman'), findsNothing);
      expect(find.textContaining('nadie'), findsNothing);

      await pump(tester, walk, state: shared(const ['Bruno', 'Carla']));
      expect(find.text('Se suman: Bruno, Carla.'), findsOneWidget);
    });

    for (final (reason, text) in [
      (ShareHoldReason.past, 'Ese plan ya pasó o queda demasiado lejos'),
      (ShareHoldReason.time, 'Solo se comparten planes entre las 9:00'),
      (ShareHoldReason.words, 'Hay algo en el texto que no va'),
      (ShareHoldReason.money, 'Los planes de la ronda no hablan de plata.'),
      (ShareHoldReason.address, 'Un plan para la ronda va a un lugar público'),
      (ShareHoldReason.phone, 'Un plan para la ronda no lleva números'),
      (ShareHoldReason.place, 'Para sumar a la ronda hace falta un lugar'),
      (ShareHoldReason.other, 'Este plan no se puede compartir con la ronda.'),
    ]) {
      testWidgets('says why a plan was held: ${reason.name}', (tester) async {
        await pump(
          tester,
          walk,
          state: SharedPlansState(
            status: SharedPlansStatus.ready,
            held: reason,
          ),
        );

        expect(find.textContaining(text), findsOneWidget);
        expect(
          find.textContaining('Tu plan sigue siendo solo tuyo.'),
          findsOneWidget,
        );
      });
    }

    testWidgets('says when it could not be sent', (tester) async {
      await pump(
        tester,
        walk,
        state: const SharedPlansState(
          status: SharedPlansStatus.ready,
          problem: SharedPlansProblem.shareFailed,
        ),
      );

      expect(
        find.text('No pudimos avisarle a la ronda. Probá de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('gives Maestro a handle on the switch', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, walk);

      expect(
        find.bySemanticsIdentifier(SharePlanToggle.identifier),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
