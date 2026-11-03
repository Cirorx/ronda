import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/first_visit/first_visit.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockFirstVisitCubit extends MockCubit<FirstVisitState>
    implements FirstVisitCubit;

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(FirstVisitSection, () {
    testWidgets("follows the member's first visit from the repository", (
      tester,
    ) async {
      final repository = _MockRondaRepository();
      when(() => repository.watchFirstVisit('demo-105')).thenAnswer(
        (_) => Stream.value(
          FirstVisit(rondaId: 'r1', mine: FirstVisitFixtures.picked),
        ),
      );

      await tester.pumpApp(
        RepositoryProvider<RondaRepository>.value(
          value: repository,
          child: const Scaffold(body: FirstVisitSection(uid: 'demo-105')),
        ),
      );
      await tester.pump();

      expect(
        tester
            .element(find.byType(FirstVisitView))
            .read<FirstVisitCubit>()
            .state
            .status,
        FirstVisitStatus.ready,
      );
    });
  });

  group(FirstVisitView, () {
    late FirstVisitCubit cubit;

    setUp(() {
      cubit = _MockFirstVisitCubit();
      when(() => cubit.declined(any())).thenAnswer((_) async {});
      when(cubit.sheetOpened).thenReturn(null);
    });

    setUpAll(() => registerFallbackValue(FirstVisitFixtures.open));

    Future<void> pump(
      WidgetTester tester,
      FirstVisitState state, {
      String uid = 'demo-101',
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: SingleChildScrollView(child: FirstVisitView(uid: uid)),
          ),
        ),
      );
    }

    testWidgets('shows nothing when no newcomer concerns the member', (
      tester,
    ) async {
      await pump(tester, const FirstVisitState());

      expect(find.byType(Card), findsNothing);
    });

    group("the newcomer's card", () {
      testWidgets('says who waits, how to know them, where and what comes '
          'first', (tester) async {
        await pump(
          tester,
          FirstVisitState(card: FirstVisitFixtures.picked),
          uid: 'demo-105',
        );

        expect(find.text('Así va a ser'), findsOneWidget);
        expect(
          find.text('Te espera Jorge — tiene el termo verde.'),
          findsOneWidget,
        );
        expect(find.text('Es en frente al quiosco.'), findsOneWidget);
        expect(
          find.text('Para encontrarlo: al lado de la parada.'),
          findsOneWidget,
        );
        expect(find.text('Los primeros cinco minutos'), findsOneWidget);
        expect(
          find.text(
            'Buscás a Jorge, que te presenta al resto. No hace falta traer '
            'nada ni saber nada.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            '¿Te querés ir antes? Decí «me tengo que ir» y listo. Nadie se '
            'ofende.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('without anyone to wait or a place, says neither', (
        tester,
      ) async {
        await pump(
          tester,
          FirstVisitState(
            card: Welcome(
              rondaId: 'r1',
              newcomerUid: 'demo-105',
              newcomerName: 'Nico',
              week: '2026-W45',
              date: FirstVisitFixtures.thursday,
            ),
          ),
          uid: 'demo-105',
        );

        expect(find.textContaining('Te espera'), findsNothing);
        expect(
          find.text('El lugar todavía está a confirmar. Va a aparecer acá.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Saludás y decís tu nombre. No hace falta traer nada ni saber '
            'nada.',
          ),
          findsOneWidget,
        );
      });
    });

    group("the hosts' question", () {
      testWidgets('asks who waits, and who does while nobody chose', (
        tester,
      ) async {
        await pump(
          tester,
          FirstVisitState(toChoose: [FirstVisitFixtures.open]),
        );

        expect(find.text('Viene alguien nuevo'), findsOneWidget);
        expect(
          find.text(
            'Nico viene por primera vez el jueves. ¿Quién espera a Nico en '
            'frente al quiosco a las 15:50?',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Si nadie elige, esperás vos: abrís vos.'),
          findsOneWidget,
        );
        expect(find.text('Elegir quién espera'), findsOneWidget);
      });

      testWidgets('to the cola names whoever opens', (tester) async {
        await pump(
          tester,
          FirstVisitState(toChoose: [FirstVisitFixtures.open]),
          uid: 'demo-102',
        );

        expect(
          find.text('Si nadie elige, espera Mirta: quien abre.'),
          findsOneWidget,
        );
      });

      testWidgets('shows the pick, the line Nico sees, and [Cambiar]', (
        tester,
      ) async {
        await pump(
          tester,
          FirstVisitState(toChoose: [FirstVisitFixtures.picked]),
        );

        expect(find.text('Espera Jorge.'), findsOneWidget);
        expect(find.text('Nico ve: «tiene el termo verde»'), findsOneWidget);
        expect(find.text('Cambiar'), findsOneWidget);
      });

      testWidgets('says when the host waits themself', (tester) async {
        await pump(
          tester,
          FirstVisitState(
            toChoose: [
              Welcome(
                rondaId: 'r1',
                newcomerUid: 'demo-105',
                newcomerName: 'Nico',
                week: '2026-W45',
                date: FirstVisitFixtures.thursday,
                waiter: FirstVisitFixtures.mirta,
                picked: true,
              ),
            ],
          ),
        );

        expect(find.text('Esperás vos.'), findsOneWidget);
      });

      testWidgets('says who could not, and when nobody opens yet', (
        tester,
      ) async {
        await pump(
          tester,
          FirstVisitState(
            toChoose: [
              Welcome(
                rondaId: 'r1',
                newcomerUid: 'demo-105',
                newcomerName: 'Nico',
                week: '2026-W45',
                date: FirstVisitFixtures.thursday,
                placeName: 'frente al quiosco',
                declinedName: 'Ana',
              ),
            ],
          ),
        );

        expect(
          find.text(
            'Nico viene por primera vez el jueves. ¿Quién espera a Nico en '
            'frente al quiosco?',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Ana dijo que no puede. Todavía no abre nadie, así que no espera '
            'nadie.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('[Elegir quién espera] opens the sheet', (tester) async {
        await pump(
          tester,
          FirstVisitState(toChoose: [FirstVisitFixtures.open]),
        );

        await tester.tap(find.text('Elegir quién espera'));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeSheet), findsOneWidget);
        verify(cubit.sheetOpened).called(1);
      });
    });

    group('the picked waiter', () {
      testWidgets('is told who picked them, when, and the line', (
        tester,
      ) async {
        await pump(
          tester,
          FirstVisitState(waitingFor: [FirstVisitFixtures.picked]),
          uid: 'demo-102',
        );

        expect(find.text('Esperás a alguien nuevo'), findsOneWidget);
        expect(
          find.text(
            'Mirta te eligió para esperar a Nico, que viene por primera vez '
            'el jueves.',
          ),
          findsOneWidget,
        );
        expect(find.text('Llegá a las 15:50, diez minutos antes.'), findsOne);
        expect(
          find.text('Nico te va a reconocer así: tiene el termo verde.'),
          findsOneWidget,
        );
      });

      testWidgets('[No puedo] hands it back, felt as a commit', (tester) async {
        final haptics = recordHaptics(tester);
        await pump(
          tester,
          FirstVisitState(waitingFor: [FirstVisitFixtures.picked]),
          uid: 'demo-102',
        );

        await tester.tap(find.text('No puedo'));
        await tester.pump();

        verify(() => cubit.declined(FirstVisitFixtures.picked)).called(1);
        expect(haptics, [commitHaptic]);
      });

      testWidgets('without an hour or a line, and while saving or failed', (
        tester,
      ) async {
        await pump(
          tester,
          FirstVisitState(
            waitingFor: [
              Welcome(
                rondaId: 'r1',
                newcomerUid: 'demo-105',
                newcomerName: 'Nico',
                week: '2026-W45',
                date: FirstVisitFixtures.thursday,
                waiter: FirstVisitFixtures.jorge,
                picked: true,
                setBy: FirstVisitFixtures.mirta,
              ),
            ],
            save: WelcomeSaveStatus.failed,
            failure: WelcomeFailureReason.passed,
          ),
          uid: 'demo-102',
        );

        expect(find.textContaining('Llegá'), findsNothing);
        expect(find.textContaining('reconocer'), findsNothing);
        expect(
          find.text('La reunión ya empezó: ya no se puede cambiar.'),
          findsOneWidget,
        );
      });

      testWidgets('[No puedo] waits while one is on its way', (tester) async {
        await pump(
          tester,
          FirstVisitState(
            waitingFor: [FirstVisitFixtures.picked],
            save: WelcomeSaveStatus.saving,
          ),
          uid: 'demo-102',
        );

        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'No puedo'),
        );
        expect(button.onPressed, isNull);
      });
    });
  });
}
