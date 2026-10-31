import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/this_week_card.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockThisWeekCubit extends MockCubit<ThisWeekState>
    implements ThisWeekCubit;

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(ThisWeekCard, () {
    late ThisWeekCubit cubit;
    late RondaRepository repository;

    setUp(() {
      cubit = _MockThisWeekCubit();
      repository = _MockRondaRepository();
      when(() => repository.watchRoll(any(), any()))
          .thenAnswer((_) => Stream.value(null));
      when(cubit.yesTapped).thenAnswer((_) async {});
      when(cubit.noTapped).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      ThisWeekState state, {
      Locale locale = rioplatense,
      bool reduced = false,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        reducedMotion(
          reduced: reduced,
          child: RepositoryProvider.value(
            value: repository,
            child: BlocProvider.value(
              value: cubit,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ThisWeekCard(state: state, uid: MyRondaFixtures.uid),
                ),
              ),
            ),
          ),
        ),
        locale: locale,
      );
    }

    ThisWeekState ready(ThisWeek week) =>
        ThisWeekState(status: ThisWeekStatus.ready, week: week);

    testWidgets('asks ¿Venís? with what the member brings', (tester) async {
      await pump(tester, ready(MyRondaFixtures.week()));

      expect(
        find.text('Sábado 31/10 a la tarde · Mate en la rambla'),
        findsOneWidget,
      );
      expect(find.text('¿Venís?'), findsOneWidget);
      expect(find.text('Te toca llevar el pan.'), findsOneWidget);
    });

    testWidgets('carries the turns, "¿Abrís vos?" and the después', (
      tester,
    ) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.week(
            turns: [
              HostTurn(
                month: DateTime(2026, 10),
                anfitrion: MyRondaFixtures.mirta,
                cola: MyRondaFixtures.jorge,
              ),
            ],
            handoffAsk: MyRondaFixtures.handoffAsk,
            despues: MyRondaFixtures.homeDespues,
          ),
        ),
      );

      expect(find.text('Este mes abre Mirta y cierra Jorge.'), findsOneWidget);
      expect(
        find.text('Mirta no puede el sábado. ¿Abrís vos?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Después, si querés: bizcochos en lo de Mirta'),
        findsOneWidget,
      );
    });

    testWidgets('Voy and Esta no answer through the cubit', (tester) async {
      await pump(tester, ready(MyRondaFixtures.week()));

      await tester.tap(find.text('Voy'));
      await tester.tap(find.text('Esta no'));

      verify(cubit.yesTapped).called(1);
      verify(cubit.noTapped).called(1);
    });

    testWidgets("shows who's coming by first name and only counts the rest", (
      tester,
    ) async {
      await pump(tester, ready(MyRondaFixtures.week()));

      expect(find.text('Quiénes van'), findsOneWidget);
      expect(find.text('Raúl'), findsOneWidget);
      expect(find.text('Termo'), findsOneWidget);
      expect(
        find.text('Va 1 · 1 no puede · 1 sin contestar · falta tu respuesta'),
        findsOneWidget,
      );
    });

    testWidgets('after Voy: "Vas. Llevá el pan." and the member as Vos', (
      tester,
    ) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.week(
            myAnswer: RsvpAnswer.yes,
            going: const [
              GoingNeighbour(uid: 'demo-001', firstName: 'Marta', brings: []),
              GoingNeighbour(uid: 'demo-002', firstName: '', brings: ['x']),
            ],
            unansweredCount: 0,
            noCount: 0,
          ),
        ),
      );

      expect(find.text('Vas. Llevá el pan.'), findsOneWidget);
      expect(find.text('Vos'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('Van 2'), findsOneWidget);
      expect(find.text('¿Venís?'), findsNothing);
    });

    testWidgets('after Voy with nothing to carry: "Vas."', (tester) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.week(
            myAnswer: RsvpAnswer.yes,
            myBrings: const ['tengo-ganas'],
          ),
        ),
      );

      expect(find.text('Vas.'), findsOneWidget);
    });

    testWidgets('after Esta no, and Cambiar mi respuesta', (tester) async {
      await pump(tester, ready(MyRondaFixtures.week(myAnswer: RsvpAnswer.no)));

      expect(find.text('Esta no vas.'), findsOneWidget);
      await tester.tap(find.text('Cambiar mi respuesta'));

      verify(cubit.changeTapped).called(1);
    });

    testWidgets('while paused, says when the member is back', (tester) async {
      await pump(
        tester,
        ready(MyRondaFixtures.week(pausedUntil: DateTime(2026, 11, 14))),
      );

      expect(find.text('Esta no vas.'), findsOneWidget);
      expect(
        find.text('Te tomás unas semanas. Volvés el 14/11.'),
        findsOneWidget,
      );
      expect(find.text('Va 1 · 1 no puede · 2 sin contestar'), findsOneWidget);
    });

    testWidgets('before the first view: the question and no counts', (
      tester,
    ) async {
      await pump(
        tester,
        ready(MyRondaFixtures.week(withView: false, placeName: 'El quiosco')),
      );

      expect(
        find.text('Sábado a la tarde · Mate en la rambla'),
        findsOneWidget,
      );
      expect(find.text('El quiosco · Hora a confirmar'), findsOneWidget);
      expect(find.text('¿Venís?'), findsOneWidget);
      expect(find.text('Quiénes van'), findsNothing);
    });

    testWidgets('says what is still to confirm instead of inventing it', (
      tester,
    ) async {
      await pump(tester, ready(MyRondaFixtures.week()));

      expect(find.text('Lugar y hora a confirmar'), findsOneWidget);
      expect(find.textContaining('Abre'), findsNothing);
    });

    testWidgets('shows the hour, the place and who opens and closes', (
      tester,
    ) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.week(
            hour: '16:00',
            placeName: 'Frente al quiosco',
            placeLandmark: 'al lado de la parada',
            anfitrion: const Host(uid: 'demo-002', firstName: 'Raúl'),
            cola: const Host(uid: 'demo-003', firstName: 'Ana'),
          ),
        ),
      );

      expect(
        find.text('Sábado 31/10 a las 16:00 · Mate en la rambla'),
        findsOneWidget,
      );
      expect(
        find.text('Frente al quiosco · al lado de la parada'),
        findsOneWidget,
      );
      expect(find.text('Abre Raúl. Cierra Ana.'), findsOneWidget);
      expect(find.text('Llega primero · Termo'), findsOneWidget);
    });

    testWidgets('tells the host they open, and the cola they close', (
      tester,
    ) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.week(
            hour: '16:00',
            anfitrion: const Host(uid: MyRondaFixtures.uid, firstName: 'Marta'),
            cola: const Host(uid: 'demo-002', firstName: 'Raúl'),
          ),
        ),
      );

      expect(find.text('Lugar a confirmar'), findsOneWidget);
      expect(
        find.text(
          'Abrís vos: llegás diez minutos antes y saludás a los que van '
          'llegando. Cierra Raúl.',
        ),
        findsOneWidget,
      );
      expect(find.text('Se queda al final · Termo'), findsOneWidget);
      verify(() => repository.watchRoll('r1', '2026-W44')).called(1);
      expect(find.text('¿Quién vino hoy?'), findsNothing);
    });

    testWidgets('shows the host "¿Quién vino hoy?" once the roll exists', (
      tester,
    ) async {
      when(() => repository.watchRoll('r1', '2026-W44')).thenAnswer(
        (_) => Stream.value(
          AttendanceRoll(
            week: '2026-W44',
            date: DateTime(2026, 10, 31),
            line: 'Sábado 16:00 · mate en la rambla',
            people: const [SetupMember(uid: 'demo-002', firstName: 'Raúl')],
            marks: const {},
          ),
        ),
      );

      await pump(
        tester,
        ready(
          MyRondaFixtures.week(
            cola: const Host(uid: MyRondaFixtures.uid, firstName: 'Marta'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('¿Quién vino hoy?'), findsOneWidget);
      expect(find.text('Todavía no anotaste a nadie, de 1.'), findsOneWidget);
    });

    group('while an answer is on its way', () {
      testWidgets('rings the pressed button and says so under it', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pump(
          tester,
          ready(MyRondaFixtures.week())
              .copyWith(answering: () => RsvpAnswer.no, answerFailed: true),
        );

        expect(progressIn('rsvp.no'), findsOneWidget);
        expect(progressIn('rsvp.yes'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester.getSemantics(find.text('Guardando tu respuesta…')),
          isSemantics(isLiveRegion: true),
        );
        expect(
          find.text('No pudimos guardar tu respuesta. Probá de nuevo.'),
          findsOneWidget,
        );
        handle.dispose();
      });

      testWidgets('takes no second tap', (tester) async {
        await pump(
          tester,
          ready(MyRondaFixtures.week())
              .copyWith(answering: () => RsvpAnswer.yes),
        );

        await tester.tap(find.text('Voy'), warnIfMissed: false);
        await tester.tap(find.text('Esta no'), warnIfMissed: false);

        verifyNever(cubit.yesTapped);
        verifyNever(cubit.noTapped);
      });

      testWidgets('says so under an answer given from the sheet', (
        tester,
      ) async {
        await pump(
          tester,
          ready(MyRondaFixtures.week(myAnswer: RsvpAnswer.no))
              .copyWith(answering: () => RsvpAnswer.yes),
        );

        expect(find.text('Esta no vas.'), findsOneWidget);
        expect(find.text('Guardando tu respuesta…'), findsOneWidget);
      });
    });

    group('swaps the question for the answer', () {
      Future<void> answer(WidgetTester tester, {bool reduced = false}) async {
        await pump(tester, ready(MyRondaFixtures.week()), reduced: reduced);
        await pump(
          tester,
          ready(MyRondaFixtures.week(myAnswer: RsvpAnswer.yes)),
          reduced: reduced,
        );
        await tester.pump(AppMotion.crossFade ~/ 2);
      }

      testWidgets('settling the answer in', (tester) async {
        await answer(tester);

        expect(swapMotion(), SwapMotion.settle);
        await tester.pumpAndSettle();
        expect(swapMotion(), SwapMotion.none);
        expect(find.text('Vas. Llevá el pan.'), findsOneWidget);
        expect(find.text('¿Venís?'), findsNothing);
      });

      testWidgets('with a cross-fade under reduced motion', (tester) async {
        await answer(tester, reduced: true);

        expect(swapMotion(), SwapMotion.crossFade);
        await tester.pumpAndSettle();
        expect(find.text('Vas. Llevá el pan.'), findsOneWidget);
      });

      testWidgets('reading out only the answer', (tester) async {
        final handle = tester.ensureSemantics();
        await answer(tester);
        expect(find.semantics.byLabel('¿Venís?'), findsNothing);
        await tester.pumpAndSettle();

        expect(find.semantics.byLabel('¿Venís?'), findsNothing);
        expect(
          tester.getSemantics(find.text('Vas. Llevá el pan.')),
          isSemantics(isLiveRegion: true),
        );
        handle.dispose();
      });
    });

    group('a seat filling', () {
      const vos = GoingNeighbour(
        uid: MyRondaFixtures.uid,
        firstName: 'Ana',
        brings: ['pan'],
      );
      const raul = GoingNeighbour(
        uid: 'demo-002',
        firstName: 'Raúl',
        brings: ['termo'],
      );

      double? heightOf(String name) => find
          .ancestor(
            of: find.text(name),
            matching: find.byWidgetPredicate(
              (widget) => widget is Align && widget.heightFactor != null,
            ),
          )
          .evaluate()
          .map((element) => (element.widget as Align).heightFactor)
          .first;

      testWidgets('grows a new row in and leaves the others still', (
        tester,
      ) async {
        await pump(tester, ready(MyRondaFixtures.week()));
        expect(heightOf('Raúl'), 1);

        await pump(
          tester,
          ready(
            MyRondaFixtures.week(
              myAnswer: RsvpAnswer.yes,
              going: const [raul, vos],
            ),
          ),
        );
        expect(heightOf('Vos'), 0);
        await tester.pump();
        await tester.pump(AppMotion.standardDuration ~/ 4);
        expect(heightOf('Vos'), allOf(greaterThan(0), lessThan(1)));
        expect(heightOf('Raúl'), 1);
        await tester.pumpAndSettle();
        expect(heightOf('Vos'), 1);
        expect(find.text('Van 2 · 1 no puede · 2 sin contestar'), findsOne);
      });

      testWidgets('is there at once under reduced motion', (tester) async {
        await pump(tester, ready(MyRondaFixtures.week()), reduced: true);
        await pump(
          tester,
          ready(
            MyRondaFixtures.week(
              myAnswer: RsvpAnswer.yes,
              going: const [raul, vos],
            ),
          ),
          reduced: true,
        );
        await tester.pump();
        await tester.pump();

        expect(heightOf('Vos'), 1);
      });
    });

    testWidgets('carries the identifiers Maestro taps', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, ready(MyRondaFixtures.week()));

      expect(find.bySemanticsIdentifier('rsvp.yes'), findsOneWidget);
      expect(find.bySemanticsIdentifier('rsvp.no'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(ThisWeekCard.identifier),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('reads in English', (tester) async {
      await pump(
        tester,
        ready(MyRondaFixtures.week()),
        locale: const Locale('en'),
      );

      expect(
        find.text('Saturday 10/31 afternoon · Mate on the rambla'),
        findsOneWidget,
      );
      expect(find.text('Are you coming?'), findsOneWidget);
      expect(find.text("It's your turn to bring the bread."), findsOneWidget);
    });
  });
}
