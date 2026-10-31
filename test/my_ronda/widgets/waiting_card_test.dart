import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/waiting_cubit.dart';
import 'package:ronda/my_ronda/widgets/waiting_card.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockWaitingCubit extends MockCubit<WaitingState> implements WaitingCubit;

final _nearby = NearbyRonda(
  rondaId: 'r2',
  pretextId: 'truco',
  barrioId: 'el-pinar-norte',
  slotDayId: 'thu',
  slotBandId: 'evening',
  placesLeft: 3,
  next: DateTime(2026, 11, 5),
);

void main() {
  group(WaitingCard, () {
    late WaitingCubit cubit;

    setUp(() {
      cubit = _MockWaitingCubit();
      when(cubit.joinTapped).thenAnswer((_) async {});
      when(cubit.waitTapped).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      WaitingState state, {
      Locale locale = rioplatense,
    }) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const SingleChildScrollView(child: WaitingCard()),
        ),
        locale: locale,
      );
    }

    WaitingState ready(Waiting waiting) =>
        WaitingState(status: WaitingCardStatus.ready, waiting: waiting);

    testWidgets('shows nothing while the person waits on no list', (
      tester,
    ) async {
      await pump(tester, const WaitingState());
      expect(find.byType(Card), findsNothing);

      await pump(tester, const WaitingState(status: WaitingCardStatus.ready));
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('says how many with them, the deadline and what happens if '
        'it does not fill', (tester) async {
      await pump(tester, ready(MyRondaFixtures.waiting()));

      expect(find.text('Tu lista de espera'), findsOneWidget);
      expect(
        find.text('Sábado a la tarde · Mate en la rambla'),
        findsOneWidget,
      );
      expect(find.text('Con vos son 5 de 6. Falta uno.'), findsOneWidget);
      expect(
        find.text(
          'Si se suma uno más antes del domingo 1/11, empieza el sábado 7/11.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Si no llegamos, te damos a elegir: sumarte a otro grupo o esperar '
          'dos semanas más.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reads for the first on a list and for several missing', (
      tester,
    ) async {
      await pump(tester, ready(MyRondaFixtures.waiting(count: 1)));
      expect(
        find.text('Por ahora sos la primera persona anotada. Hacen falta 6.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Si se suman 5 más antes del domingo 1/11, empieza el sábado 7/11.',
        ),
        findsOneWidget,
      );

      await pump(tester, ready(MyRondaFixtures.waiting(count: 3)));
      expect(find.text('Con vos son 3 de 6. Faltan 3.'), findsOneWidget);
    });

    testWidgets('says a full list is being put together, with its date', (
      tester,
    ) async {
      await pump(
        tester,
        ready(MyRondaFixtures.waiting(status: WaitingStatus.full, count: 6)),
      );

      expect(
        find.text(
          'Ya son 6: alcanza para arrancar. Armamos el grupo y te avisamos '
          'antes del sábado 7/11.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('after a round that did not fill, offers both choices with '
        'their dates', (tester) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.waiting(
            status: WaitingStatus.didntFill,
            nearby: _nearby,
          ),
        ),
      );

      expect(find.text('Esta vez no llegamos a 6.'), findsOneWidget);
      expect(
        find.text('Jueves a la noche · Truco, el jueves 5/11'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Esperamos hasta el domingo 1/11. Si se suman, arranca el sábado '
          '7/11.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Sumarte a otro ya'));
      await tester.tap(find.text('Esperar dos semanas más'));
      verify(cubit.joinTapped).called(1);
      verify(cubit.waitTapped).called(1);
    });

    testWidgets('with no ronda nearby, offers only to wait', (tester) async {
      await pump(
        tester,
        ready(MyRondaFixtures.waiting(status: WaitingStatus.didntFill)),
      );

      expect(find.text('Sumarte a otro ya'), findsNothing);
      expect(find.text('Esperar dos semanas más'), findsOneWidget);
    });

    testWidgets('after joining, ends with the next date', (tester) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.waiting(
            status: WaitingStatus.joined,
            nearby: _nearby,
            choice: WaitlistChoice.join,
          ),
        ),
      );
      expect(
        find.text(
          'Listo, lo anotamos. Te confirmamos el lugar antes del jueves 5/11.',
        ),
        findsOneWidget,
      );

      await pump(
        tester,
        ready(MyRondaFixtures.waiting(status: WaitingStatus.joined)),
      );
      expect(
        find.text(
          'Listo, lo anotamos. Te confirmamos el lugar antes del sábado 7/11.',
        ),
        findsOneWidget,
      );
    });

    group('a pick', () {
      WaitingState didntFill() => ready(
        MyRondaFixtures.waiting(
          status: WaitingStatus.didntFill,
          nearby: _nearby,
        ),
      );

      testWidgets('is a commit, felt on the tap', (tester) async {
        final haptics = recordHaptics(tester);
        await pump(tester, didntFill());

        await tester.tap(find.text('Esperar dos semanas más'));

        expect(haptics, [commitHaptic]);
        verify(cubit.waitTapped).called(1);
      });

      testWidgets('rings the pressed choice while it saves, and says so', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pump(
          tester,
          didntFill().copyWith(saving: () => WaitlistChoice.join),
        );

        expect(progressIn(WaitingCard.joinIdentifier), findsOneWidget);
        expect(progressIn(WaitingCard.waitIdentifier), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester.getSemantics(find.text('Guardando lo que elegiste…')),
          isSemantics(isLiveRegion: true),
        );

        await tester.tap(find.text('Sumarte a otro ya'), warnIfMissed: false);
        await tester.tap(find.text('Esperar dos semanas más'));
        verifyNever(cubit.joinTapped);
        verifyNever(cubit.waitTapped);
        handle.dispose();
      });

      testWidgets('that failed says so out loud', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, didntFill().copyWith(saveFailed: true));

        expect(
          tester.getSemantics(
            find.text('No pudimos guardar tu respuesta. Probá de nuevo.'),
          ),
          isSemantics(isLiveRegion: true),
        );
        handle.dispose();
      });

      group('swaps in what it led to', () {
        Future<void> join(WidgetTester tester, {bool reduced = false}) async {
          final states = StreamController<WaitingState>();
          addTearDown(states.close);
          whenListen(cubit, states.stream, initialState: didntFill());
          await tester.pumpApp(
            reducedMotion(
              reduced: reduced,
              child: BlocProvider.value(
                value: cubit,
                child: const SingleChildScrollView(child: WaitingCard()),
              ),
            ),
          );
          states.add(
            ready(
              MyRondaFixtures.waiting(
                status: WaitingStatus.joined,
                nearby: _nearby,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1));
        }

        testWidgets('settling it in, then reading it out', (tester) async {
          final handle = tester.ensureSemantics();
          await join(tester);

          expect(swapMotion(), SwapMotion.settle);
          await tester.pumpAndSettle();
          expect(
            tester.getSemantics(
              find.text(
                'Listo, lo anotamos. Te confirmamos el lugar antes del jueves '
                '5/11.',
              ),
            ),
            isSemantics(isLiveRegion: true),
          );
          handle.dispose();
        });

        testWidgets('with a cross-fade under reduced motion', (tester) async {
          await join(tester, reduced: true);

          expect(swapMotion(), SwapMotion.crossFade);
        });
      });
    });

    testWidgets('reads in English', (tester) async {
      await pump(
        tester,
        ready(MyRondaFixtures.waiting()),
        locale: const Locale('en'),
      );

      expect(
        find.text('With you there are 5 of 6. One more is needed.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'If one more joins before Sunday 11/1, it starts on Saturday 11/7.',
        ),
        findsOneWidget,
      );
    });
  });
}
