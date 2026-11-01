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

class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

void main() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final at = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19);
  SharedPlanLine line({
    bool joined = false,
    String uid = 'u1',
    String? place,
  }) => SharedPlanLine(
    authorUid: uid,
    firstName: 'Ana',
    activity: 'Caminar 30 minutos por la rambla',
    place: place ?? 'desde la parada 23',
    kind: SmallPlanKind.walk,
    at: at,
    joined: joined,
  );
  SharedPlansState ready(
    List<SharedPlanLine> lines, {
    String? joining,
    SharedPlansProblem? problem,
  }) => SharedPlansState(
    status: SharedPlansStatus.ready,
    plans: SharedPlans(lines: lines),
    joining: joining,
    problem: problem,
  );

  group(SharedPlansSection, () {
    late SharedPlansCubit cubit;

    setUp(() {
      cubit = _MockSharedPlansCubit();
      when(() => cubit.joinTapped(any())).thenAnswer((_) async {});
      when(() => cubit.leaveTapped(any())).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      SharedPlansState state, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: SharedPlansSection()),
        ),
        locale: locale,
      );
    }

    testWidgets('shows nothing while reading, with no plans or for a plan '
        'whose time passed', (tester) async {
      await pump(tester, const SharedPlansState());
      expect(find.byType(Card), findsNothing);

      await pump(tester, ready(const []));
      expect(find.byType(Card), findsNothing);

      await pump(
        tester,
        ready([
          SharedPlanLine(
            authorUid: 'u1',
            firstName: 'Ana',
            activity: 'Caminar',
            place: null,
            kind: SmallPlanKind.walk,
            at: DateTime(2020),
            joined: false,
          ),
        ]),
      );
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows the line with [Me sumo], in voseo', (tester) async {
      await pump(tester, ready([line()]));

      expect(
        find.textContaining(
          'Ana propone: Caminar 30 minutos por la rambla, el',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('a las 19:00, desde la parada 23.'), findsOne);
      expect(find.text('Me sumo'), findsOneWidget);
      expect(find.text('Te sumaste.'), findsNothing);
    });

    testWidgets('says it in English on an English phone', (tester) async {
      await pump(tester, ready([line()]), locale: const Locale('en'));

      expect(find.textContaining('Ana suggests: Caminar'), findsOneWidget);
      expect(find.text('Count me in'), findsOneWidget);
    });

    testWidgets('joins, and shows one line for each plan', (tester) async {
      await pump(tester, ready([line(), line(uid: 'u3')]));

      await tester.tap(find.text('Me sumo').first);

      verify(() => cubit.joinTapped('u1')).called(1);
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('after joining says so, and lets the member take it back', (
      tester,
    ) async {
      await pump(tester, ready([line(joined: true)]));

      expect(find.text('Te sumaste.'), findsOneWidget);
      expect(find.text('Me sumo'), findsNothing);
      await tester.tap(find.text('Ya no voy'));

      verify(() => cubit.leaveTapped('u1')).called(1);
    });

    testWidgets('disables the button while it is on its way', (tester) async {
      await pump(tester, ready([line()], joining: 'u1'));

      await tester.tap(find.text('Me sumo'));

      verifyNever(() => cubit.joinTapped(any()));
    });

    testWidgets('disables "Ya no voy" while it is on its way', (tester) async {
      await pump(tester, ready([line(joined: true)], joining: 'u1'));

      await tester.tap(find.text('Ya no voy'));

      verifyNever(() => cubit.leaveTapped(any()));
    });

    for (final (problem, text) in [
      (SharedPlansProblem.planGone, 'Ese plan ya no está.'),
      (SharedPlansProblem.joinFailed, 'No pudimos anotarte. Probá de nuevo.'),
    ]) {
      testWidgets('says plainly when joining went wrong: ${problem.name}', (
        tester,
      ) async {
        await pump(tester, ready([line()], problem: problem));

        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets("does not show the author's own failure here", (tester) async {
      await pump(
        tester,
        ready([line()], problem: SharedPlansProblem.shareFailed),
      );

      expect(find.textContaining('avisarle'), findsNothing);
    });

    testWidgets('gives Maestro a handle on each button', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, ready([line(), line(uid: 'u3', joined: true)]));

      expect(find.bySemanticsIdentifier('sharedPlan.join.u1'), findsOneWidget);
      expect(find.bySemanticsIdentifier('sharedPlan.leave.u3'), findsOneWidget);
      handle.dispose();
    });
  });

  group(SharedPlansScope, () {
    testWidgets('provides a cubit that follows the ronda for the member', (
      tester,
    ) async {
      final repository = _MockSmallPlanRepository();
      when(() => repository.watchShared(rondaId: 'r1', uid: 'u2'))
          .thenAnswer((_) => Stream.value(SharedPlans(lines: [line()])));

      await tester.pumpApp(
        RepositoryProvider<SmallPlanRepository>.value(
          value: repository,
          child: const Scaffold(
            body: SharedPlansScope(
              rondaId: 'r1',
              uid: 'u2',
              child: SharedPlansSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Me sumo'), findsOneWidget);
    });
  });
}
