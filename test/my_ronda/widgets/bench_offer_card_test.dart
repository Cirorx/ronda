import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/bench_offer_cubit.dart';
import 'package:ronda/my_ronda/widgets/bench_offer_card.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockBenchOfferCubit extends MockCubit<BenchOfferState>
    implements BenchOfferCubit;

void main() {
  group(BenchOfferCard, () {
    late BenchOfferCubit cubit;

    setUp(() {
      cubit = _MockBenchOfferCubit();
      when(cubit.takeTapped).thenAnswer((_) async {});
      when(cubit.passTapped).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      BenchOfferState state, {
      Locale locale = rioplatense,
    }) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const SingleChildScrollView(child: BenchOfferCard()),
        ),
        locale: locale,
      );
    }

    BenchOfferState ready(BenchOffer offer) =>
        BenchOfferState(status: BenchOfferCardStatus.ready, offer: offer);

    testWidgets('shows nothing while no offer matters', (tester) async {
      await pump(tester, const BenchOfferState());
      expect(find.byType(Card), findsNothing);

      await pump(
        tester,
        const BenchOfferState(status: BenchOfferCardStatus.ready),
      );
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('offers the seat with its meeting and deadline, no fines', (
      tester,
    ) async {
      await pump(tester, ready(MyRondaFixtures.offer()));

      expect(find.text('Se liberó un lugar'), findsOneWidget);
      expect(
        find.text(
          'Jueves 5/11 a las 16:00 · Mate en la rambla · frente al quiosco',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Estabas en la lista de espera. ¿Lo tomás?'),
        findsOneWidget,
      );
      expect(
        find.text('Tenés hasta el miércoles 4/11 a las 12:00.'),
        findsOneWidget,
      );
      expect(
        find.text('Si no podés, no pasa nada: seguís en la lista de espera.'),
        findsOneWidget,
      );
      expect(
        find.text('al lado de la parada', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('answers with Lo tomo and Esta vez no', (tester) async {
      await pump(tester, ready(MyRondaFixtures.offer()));

      await tester.tap(find.text('Lo tomo'));
      await tester.tap(find.text('Esta vez no'));

      verify(cubit.takeTapped).called(1);
      verify(cubit.passTapped).called(1);
    });

    testWidgets('once taken, says where and that it is for this meeting', (
      tester,
    ) async {
      await pump(
        tester,
        ready(MyRondaFixtures.offer(status: BenchOfferStatus.taken)),
      );

      expect(find.text('Vas esta vez'), findsOneWidget);
      expect(
        find.text('frente al quiosco · al lado de la parada'),
        findsOneWidget,
      );
      expect(
        find.text('Tomás el lugar que alguien liberó, solo para esta reunión.'),
        findsOneWidget,
      );
      expect(find.text('Lo tomo'), findsNothing);
    });

    testWidgets('once taken without a landmark, shows no landmark line', (
      tester,
    ) async {
      await pump(
        tester,
        ready(
          MyRondaFixtures.offer(
            status: BenchOfferStatus.taken,
            placeLandmark: null,
          ),
        ),
      );

      expect(find.textContaining('al lado de la parada'), findsNothing);
    });

    testWidgets('says when it failed, or the offer is over, out loud', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final state = ready(MyRondaFixtures.offer());
      await pump(tester, state.copyWith(saveFailed: true));
      expect(
        tester.getSemantics(
          find.text('No pudimos guardar tu respuesta. Probá de nuevo.'),
        ),
        isSemantics(isLiveRegion: true),
      );

      await pump(tester, state.copyWith(over: true));
      expect(
        tester.getSemantics(
          find.text('Esta oferta ya terminó. Seguís en la lista de espera.'),
        ),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('Lo tomo is a commit, felt on the tap', (tester) async {
      final haptics = recordHaptics(tester);
      await pump(tester, ready(MyRondaFixtures.offer()));

      await tester.tap(find.text('Lo tomo'));

      expect(haptics, [commitHaptic]);
    });

    testWidgets('rings the pressed answer while it saves, and says so', (
      tester,
    ) async {
      await pump(
        tester,
        ready(MyRondaFixtures.offer())
            .copyWith(saving: () => BenchOfferAnswer.take),
      );

      expect(progressIn('bench.yes'), findsOneWidget);
      expect(progressIn('bench.no'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Guardando tu respuesta…'), findsOneWidget);
    });

    group('swaps the offer for "Vas esta vez"', () {
      Future<void> take(WidgetTester tester, {bool reduced = false}) async {
        final states = StreamController<BenchOfferState>();
        addTearDown(states.close);
        whenListen(
          cubit,
          states.stream,
          initialState: ready(MyRondaFixtures.offer()),
        );
        await tester.pumpApp(
          reducedMotion(
            reduced: reduced,
            child: BlocProvider.value(
              value: cubit,
              child: const SingleChildScrollView(child: BenchOfferCard()),
            ),
          ),
        );
        states.add(
          ready(MyRondaFixtures.offer(status: BenchOfferStatus.taken)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
      }

      testWidgets('settling it in, then reading it out', (tester) async {
        final handle = tester.ensureSemantics();
        await take(tester);

        expect(swapMotion(), SwapMotion.settle);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.text('Vas esta vez')),
          isSemantics(isLiveRegion: true, isHeader: true),
        );
        handle.dispose();
      });

      testWidgets('with a cross-fade under reduced motion', (tester) async {
        await take(tester, reduced: true);

        expect(swapMotion(), SwapMotion.crossFade);
      });
    });

    testWidgets('reads in English', (tester) async {
      await pump(
        tester,
        ready(MyRondaFixtures.offer()),
        locale: const Locale('en'),
      );

      expect(find.text('A place opened up'), findsOneWidget);
      expect(find.text("I'll take it"), findsOneWidget);
      expect(find.text('Not this time'), findsOneWidget);
    });
  });
}
