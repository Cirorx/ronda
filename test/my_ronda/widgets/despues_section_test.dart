import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/despues_section.dart';
import 'package:ronda/my_ronda/widgets/despues_sheet.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockThisWeekCubit extends MockCubit<ThisWeekState>
    implements ThisWeekCubit;

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(DespuesSection, () {
    late ThisWeekCubit cubit;

    setUp(() {
      cubit = _MockThisWeekCubit();
      when(() => cubit.state).thenReturn(const ThisWeekState());
      when(() => cubit.homeAnswered(yes: any(named: 'yes')))
          .thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, ThisWeek week) => tester.pumpApp(
      RepositoryProvider<RondaRepository>.value(
        value: _MockRondaRepository(),
        child: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: DespuesSection(week: week, uid: MyRondaFixtures.uid),
          ),
        ),
      ),
    );

    Despues home({
      DespuesStatus status = DespuesStatus.set,
      Host setBy = MyRondaFixtures.me,
      Host homeOf = MyRondaFixtures.jorge,
      String? address = 'Av. Central 1234',
    }) => Despues(
      kind: DespuesKind.home,
      status: status,
      setBy: setBy,
      what: 'bizcochos',
      homeOf: homeOf,
      address: address,
    );

    testWidgets('a member reads it once it is set, and nothing else', (
      tester,
    ) async {
      await pump(
        tester,
        MyRondaFixtures.week(despues: MyRondaFixtures.homeDespues),
      );

      expect(
        find.text(
          'Después, si querés: bizcochos en lo de Mirta, Av. Central 1234 '
          '(20 min)',
        ),
        findsOneWidget,
      );
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('a member sees nothing while there is none', (tester) async {
      await pump(tester, MyRondaFixtures.week());

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the host is asked "¿Hay después esta semana?"', (
      tester,
    ) async {
      await pump(tester, MyRondaFixtures.week(anfitrion: MyRondaFixtures.me));

      expect(find.text('¿Hay después esta semana?'), findsOneWidget);
    });

    testWidgets('the host sees "esta semana no" and can change it', (
      tester,
    ) async {
      await pump(
        tester,
        MyRondaFixtures.week(
          cola: MyRondaFixtures.me,
          despues: const Despues(
            kind: DespuesKind.none,
            status: DespuesStatus.set,
            setBy: MyRondaFixtures.me,
          ),
        ),
      );

      expect(find.text('Esta semana no hay después.'), findsOneWidget);
      await tester.tap(find.text('Cambiar el después'));
      await tester.pumpAndSettle();

      expect(find.byType(DespuesSheet), findsOneWidget);
    });

    testWidgets("who set it at someone else's home sees where it stands", (
      tester,
    ) async {
      await pump(
        tester,
        MyRondaFixtures.week(
          opener: MyRondaFixtures.me,
          despues: home(status: DespuesStatus.asking),
        ),
      );
      expect(
        find.text(
          'Le preguntamos a Jorge si el después puede ser donde vive. Hasta '
          'que diga que sí, no lo ve nadie más.',
        ),
        findsOneWidget,
      );

      await pump(
        tester,
        MyRondaFixtures.week(
          opener: MyRondaFixtures.me,
          despues: home(status: DespuesStatus.declined, address: null),
        ),
      );
      expect(
        find.text(
          'Jorge prefiere que no sea donde vive. Podés elegir otro lugar.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('whose home it would be is asked first', (tester) async {
      await pump(
        tester,
        MyRondaFixtures.week(
          despues: home(
            status: DespuesStatus.asking,
            setBy: MyRondaFixtures.mirta,
            homeOf: MyRondaFixtures.me,
          ),
        ),
      );

      expect(
        find.text(
          'Mirta pregunta si el después de esta semana puede ser donde vivís: '
          'bizcochos, Av. Central 1234.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Sí, puede ser'));
      await tester.tap(find.text('Mejor no'));

      verify(() => cubit.homeAnswered(yes: true)).called(1);
      verify(() => cubit.homeAnswered(yes: false)).called(1);
    });

    testWidgets('the question waits while an answer is on its way, and says '
        'when one failed', (tester) async {
      when(() => cubit.state).thenReturn(
        const ThisWeekState(
          acting: true,
          actionFailure: HostsFailureReason.other,
        ),
      );
      await pump(
        tester,
        MyRondaFixtures.week(
          despues: home(
            status: DespuesStatus.asking,
            setBy: MyRondaFixtures.mirta,
            homeOf: MyRondaFixtures.me,
          ),
        ),
      );

      expect(find.text('No se guardó. Probá de nuevo.'), findsOneWidget);
      await tester.tap(find.text('Sí, puede ser'));
      await tester.tap(find.text('Mejor no'));
      verifyNever(() => cubit.homeAnswered(yes: any(named: 'yes')));
    });
  });
}
