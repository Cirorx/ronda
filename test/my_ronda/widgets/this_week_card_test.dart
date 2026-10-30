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
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        RepositoryProvider.value(
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

    testWidgets('shows progress and a failed answer', (tester) async {
      await pump(
        tester,
        ready(MyRondaFixtures.week())
            .copyWith(answering: true, answerFailed: true),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.text('No pudimos guardar tu respuesta. Probá de nuevo.'),
        findsOneWidget,
      );
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
