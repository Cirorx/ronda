import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/seguimos_cubit.dart';
import 'package:ronda/my_ronda/widgets/seguimos_card.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockSeguimosCubit extends MockCubit<SeguimosState>
    implements SeguimosCubit;

void main() {
  group(SeguimosCard, () {
    late SeguimosCubit cubit;

    setUp(() {
      cubit = _MockSeguimosCubit();
      when(cubit.yesTapped).thenAnswer((_) async {});
      when(cubit.noTapped).thenAnswer((_) async {});
      when(cubit.joinTapped).thenAnswer((_) async {});
      when(cubit.waitTapped).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      SeguimosState state, {
      Locale locale = rioplatense,
    }) async {
      when(() => cubit.state).thenReturn(state);
      // A fresh tree each time, so a second pump in a test shows its state.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const SingleChildScrollView(child: SeguimosCard()),
        ),
        locale: locale,
      );
    }

    SeguimosState ready(Seguimos seguimos) =>
        SeguimosState(status: SeguimosCardStatus.ready, seguimos: seguimos);

    testWidgets('shows nothing before the member is asked', (tester) async {
      await pump(tester, const SeguimosState());
      expect(find.byType(Card), findsNothing);

      await pump(tester, ready(MyRondaFixtures.seguimos(open: false)));
      expect(find.byType(Card), findsNothing);
    });

    group('while open', () {
      testWidgets('asks privately with Sí and No and what silence means', (
        tester,
      ) async {
        await pump(tester, ready(MyRondaFixtures.seguimos()));

        expect(find.text('¿Seguimos los martes?'), findsOneWidget);
        expect(
          find.text(
            'Solo Ronda ve tu respuesta. Nadie del grupo se entera de lo que '
            'digas.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Si no contestás, seguís en la ronda, pero no cuenta como un sí.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Sí'));
        await tester.tap(find.text('No'));

        verify(cubit.yesTapped).called(1);
        verify(cubit.noTapped).called(1);
      });

      testWidgets('shows the answer with Cambiar until the close', (
        tester,
      ) async {
        await pump(
          tester,
          ready(MyRondaFixtures.seguimos(myAnswer: SeguimosAnswer.yes)),
        );

        expect(find.text('Dijiste que sí.'), findsOneWidget);
        expect(
          find.text('Lo podés cambiar hasta que llegue el próximo ¿Venís?.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cambiar'));

        verify(cubit.changeTapped).called(1);
      });

      testWidgets('shows a no as the member gave it', (tester) async {
        await pump(
          tester,
          ready(MyRondaFixtures.seguimos(myAnswer: SeguimosAnswer.no)),
        );

        expect(find.text('Dijiste que no.'), findsOneWidget);
      });

      testWidgets('says when saving failed or the question had closed', (
        tester,
      ) async {
        await pump(
          tester,
          ready(MyRondaFixtures.seguimos())
              .copyWith(saving: true, saveFailed: true, closed: true),
        );

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
          find.text('No pudimos guardar tu respuesta. Probá de nuevo.'),
          findsOneWidget,
        );
        expect(find.text('La pregunta ya se cerró.'), findsOneWidget);
      });
    });

    testWidgets('shows the season with its end and nobody', (tester) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.seguimos(
            open: false,
            outcome: SeguimosOutcome.season,
          ),
        ),
      );

      expect(find.text('Seguimos los martes'), findsOneWidget);
      expect(find.text('Hasta el 24/11.'), findsOneWidget);
      expect(find.text('Nadie sabe qué contestó cada uno.'), findsOneWidget);
      expect(find.textContaining('Sí'), findsNothing);
    });

    group('after a no', () {
      testWidgets('thanks them and lists the nearby places', (tester) async {
        await pump(
          tester,
          ready(
            MyRondaFixtures.seguimos(
              open: false,
              outcome: SeguimosOutcome.gracias,
              alternatives: [MyRondaFixtures.nearby],
            ),
          ),
        );

        expect(find.text('Gracias por venir.'), findsOneWidget);
        expect(find.text('Jueves a la tarde · Truco'), findsOneWidget);
        expect(
          find.text('Quedan 2 lugares · el próximo es el 5/11'),
          findsOneWidget,
        );
      });

      testWidgets('says when none has places', (tester) async {
        await pump(
          tester,
          ready(
            MyRondaFixtures.seguimos(
              open: false,
              outcome: SeguimosOutcome.gracias,
            ),
          ),
        );

        expect(
          find.text(
            'Por ahora no hay otro grupo con lugar cerca. Te avisamos si se '
            'abre uno.',
          ),
          findsOneWidget,
        );
      });
    });

    group('below the floor', () {
      Seguimos didntFill({
        SeguimosChoice? choice,
        bool withNearby = true,
        bool withWait = true,
      }) => MyRondaFixtures.seguimos(
        open: false,
        outcome: SeguimosOutcome.didntFill,
        alternatives: withNearby ? [MyRondaFixtures.nearby] : const [],
        choice: choice,
        withWait: withWait,
      );

      testWidgets('offers another ronda now or waiting, with dates', (
        tester,
      ) async {
        await pump(tester, ready(didntFill()));

        expect(
          find.text('Esta vez no llegamos a 4 para seguir los martes.'),
          findsOneWidget,
        );
        expect(find.text('Jueves a la tarde · Truco, el 5/11'), findsOneWidget);
        expect(
          find.text('Esperamos hasta el 16/11. Si se suman, arranca el 17/11.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Sumarte a otro ya'));
        await tester.tap(find.text('Esperar dos semanas más'));

        verify(cubit.joinTapped).called(1);
        verify(cubit.waitTapped).called(1);
      });

      testWidgets('offers only waiting when no ronda nearby has places', (
        tester,
      ) async {
        await pump(
          tester,
          ready(didntFill(withNearby: false, withWait: false)),
        );

        expect(find.text('Sumarte a otro ya'), findsNothing);
        expect(find.text('Esperar dos semanas más'), findsOneWidget);
      });

      testWidgets('ends each choice with its date', (tester) async {
        await pump(tester, ready(didntFill(choice: SeguimosChoice.join)));
        expect(
          find.text(
            'Listo, lo anotamos. Te confirmamos el lugar antes del 5/11.',
          ),
          findsOneWidget,
        );

        await pump(tester, ready(didntFill(choice: SeguimosChoice.wait)));
        expect(
          find.text(
            'Listo, esperamos hasta el 16/11. Si se suman, arranca el 17/11.',
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('reads in English', (tester) async {
      await pump(
        tester,
        ready(MyRondaFixtures.seguimos()),
        locale: const Locale('en'),
      );

      expect(find.text('Shall we keep meeting on Tuesdays?'), findsOneWidget);
    });

    testWidgets('names every weekday', (tester) async {
      for (final (day, plural) in [
        ('mon', 'lunes'),
        ('wed', 'miércoles'),
        ('thu', 'jueves'),
        ('fri', 'viernes'),
        ('sat', 'sábados'),
        ('sun', 'domingos'),
        ('x', 'días de la ronda'),
      ]) {
        await pump(
          tester,
          ready(Seguimos(rondaId: 'r1', slotDayId: day, open: true)),
        );
        expect(find.text('¿Seguimos los $plural?'), findsOneWidget);
      }
    });
  });
}
