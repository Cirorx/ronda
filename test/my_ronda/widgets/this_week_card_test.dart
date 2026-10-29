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

void main() {
  group(ThisWeekCard, () {
    late ThisWeekCubit cubit;

    setUp(() {
      cubit = _MockThisWeekCubit();
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
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ThisWeekCard(state: state, uid: MyRondaFixtures.uid),
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
        find.text('Sábado a la tarde · Mate en la rambla · El quiosco'),
        findsOneWidget,
      );
      expect(find.text('¿Venís?'), findsOneWidget);
      expect(find.text('Quiénes van'), findsNothing);
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
