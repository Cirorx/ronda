import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cuaderno/cuaderno.dart';
import 'package:ronda/mate_flyer/mate_flyer.dart';
import 'package:ronda/my_ronda/cubit/bench_offer_cubit.dart';
import 'package:ronda/my_ronda/cubit/seguimos_cubit.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/cubit/waiting_cubit.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/my_ronda/widgets/bench_offer_card.dart';
import 'package:ronda/my_ronda/widgets/esta_no_sheet.dart';
import 'package:ronda/my_ronda/widgets/seguimos_card.dart';
import 'package:ronda/my_ronda/widgets/this_week_card.dart';
import 'package:ronda/my_ronda/widgets/waiting_card.dart';
import 'package:ronda/push/push.dart';
import 'package:ronda/small_plan/small_plan.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockPushRepository extends Mock implements PushRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockContactRepository extends Mock implements ContactRepository;

class _MockCuadernoRepository extends Mock implements CuadernoRepository;
class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;
class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

class _MockPushCubit extends MockCubit<PushState> implements PushCubit;

class _MockThisWeekCubit extends MockCubit<ThisWeekState>
    implements ThisWeekCubit;

class _MockSeguimosCubit extends MockCubit<SeguimosState>
    implements SeguimosCubit;

class _MockBenchOfferCubit extends MockCubit<BenchOfferState>
    implements BenchOfferCubit;

class _MockWaitingCubit extends MockCubit<WaitingState> implements WaitingCubit;

class _MockCuadernoCardCubit extends MockCubit<String?>
    implements CuadernoCardCubit;
class _MockSmallPlanCubit extends MockCubit<SmallPlanState>
    implements SmallPlanCubit;

void main() {
  group(MyRondaPage, () {
    late AppBloc appBloc;
    late PushRepository pushRepository;
    late RondaRepository rondaRepository;
    late CuadernoRepository cuadernoRepository;
    late SmallPlanRepository smallPlanRepository;

    setUp(() {
      appBloc = _MockAppBloc();
      cuadernoRepository = _MockCuadernoRepository();
      when(() => cuadernoRepository.changes)
          .thenAnswer((_) => const Stream<void>.empty());
      when(() => cuadernoRepository.read(MyRondaFixtures.uid))
          .thenAnswer((_) async => Cuaderno.empty);
      smallPlanRepository = _MockSmallPlanRepository();
      when(() => smallPlanRepository.current(any()))
          .thenAnswer((_) async => const SmallPlanNothing());
      pushRepository = _MockPushRepository();
      rondaRepository = _MockRondaRepository();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: MyRondaFixtures.uid),
        ),
      );
      when(pushRepository.permission)
          .thenAnswer((_) async => PushPermission.notAsked);
      when(pushRepository.promptSnoozed).thenAnswer((_) async => false);
      when(() => rondaRepository.watchThisWeek(MyRondaFixtures.uid))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.watchSeguimos(MyRondaFixtures.uid))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.watchBenchOffers(MyRondaFixtures.uid))
          .thenAnswer((_) => Stream.value(const []));
      when(() => rondaRepository.watchWaiting(MyRondaFixtures.uid))
          .thenAnswer((_) => Stream.value(null));
    });

    testWidgets('provides the notifications ask and the week of the '
        "member's ronda", (tester) async {
      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: pushRepository),
            RepositoryProvider.value(value: rondaRepository),
            RepositoryProvider<CuadernoRepository>.value(
              value: cuadernoRepository,
            ),
            RepositoryProvider.value(value: smallPlanRepository),
          ],
          child: BlocProvider.value(value: appBloc, child: const MyRondaPage()),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(MyRondaView));
      expect(
        context.read<PushCubit>().state,
        equals(const PushState(status: PushStatus.offered)),
      );
      expect(
        context.read<ThisWeekCubit>().state,
        equals(const ThisWeekState(status: ThisWeekStatus.noGroup)),
      );
      expect(
        context.read<SeguimosCubit>().state,
        equals(const SeguimosState(status: SeguimosCardStatus.none)),
      );
      expect(
        context.read<BenchOfferCubit>().state,
        equals(const BenchOfferState(status: BenchOfferCardStatus.none)),
      );
      expect(
        context.read<WaitingCubit>().state,
        equals(const WaitingState(status: WaitingCardStatus.none)),
      );
      expect(find.text('¿Te avisamos los martes?'), findsOneWidget);
      expect(find.text('Todavía no tenés grupo'), findsOneWidget);
      verify(pushRepository.permission).called(1);
    });
  });

  group(MyRondaView, () {
    late PushCubit pushCubit;
    late ThisWeekCubit thisWeekCubit;
    late SeguimosCubit seguimosCubit;
    late BenchOfferCubit benchOfferCubit;
    late WaitingCubit waitingCubit;
    late CuadernoCardCubit cuadernoCardCubit;
    late SmallPlanCubit smallPlanCubit;
    late RondaRepository rondaRepository;
    late ContactRepository contactRepository;
    late DondeQuedaRepository dondeQuedaRepository;
    late SmallPlanRepository sharedRepository;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      contactRepository = _MockContactRepository();
      dondeQuedaRepository = _MockDondeQuedaRepository();
      sharedRepository = _MockSmallPlanRepository();
      when(
        () => sharedRepository.watchShared(
          rondaId: any(named: 'rondaId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) => Stream.value(const SharedPlans()));
      when(
        () => dondeQuedaRepository.watch(
          rondaId: any(named: 'rondaId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) => Stream.value(const DondeQuedaWeek()));
      when(() => rondaRepository.watchFirstVisit(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.watchBuddyAsk(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.buddyOptions(any())).thenAnswer(
        (_) async => const BuddyOptions(due: false, chosen: false, choices: []),
      );
      when(contactRepository.canOpenWhatsApp).thenAnswer((_) async => false);
      pushCubit = _MockPushCubit();
      thisWeekCubit = _MockThisWeekCubit();
      seguimosCubit = _MockSeguimosCubit();
      benchOfferCubit = _MockBenchOfferCubit();
      waitingCubit = _MockWaitingCubit();
      cuadernoCardCubit = _MockCuadernoCardCubit();
      when(() => cuadernoCardCubit.state).thenReturn(null);
      smallPlanCubit = _MockSmallPlanCubit();
      when(() => smallPlanCubit.state)
          .thenReturn(const SmallPlanState(status: SmallPlanStatus.ready));
      when(() => benchOfferCubit.state)
          .thenReturn(const BenchOfferState(status: BenchOfferCardStatus.none));
      when(() => waitingCubit.state)
          .thenReturn(const WaitingState(status: WaitingCardStatus.none));
      when(() => seguimosCubit.state)
          .thenReturn(const SeguimosState(status: SeguimosCardStatus.none));
      when(() => pushCubit.state)
          .thenReturn(const PushState(status: PushStatus.dismissed));
      when(() => thisWeekCubit.state)
          .thenReturn(const ThisWeekState(status: ThisWeekStatus.noGroup));
      when(thisWeekCubit.pauseTapped).thenAnswer((_) async {});
      when(thisWeekCubit.yesTapped).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, {bool reduced = false}) =>
        tester.pumpApp(
          reducedMotion(
            reduced: reduced,
            child: MultiRepositoryProvider(
              providers: [
                RepositoryProvider.value(value: rondaRepository),
                RepositoryProvider.value(value: contactRepository),
                RepositoryProvider.value(value: dondeQuedaRepository),
                RepositoryProvider.value(value: sharedRepository),
              ],
              child: MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: pushCubit),
                  BlocProvider.value(value: thisWeekCubit),
                  BlocProvider.value(value: seguimosCubit),
                  BlocProvider.value(value: benchOfferCubit),
                  BlocProvider.value(value: waitingCubit),
                  BlocProvider.value(value: cuadernoCardCubit),
                  BlocProvider.value(value: smallPlanCubit),
                ],
                child: const MyRondaView(uid: MyRondaFixtures.uid),
              ),
            ),
          ),
        );

    group('renders', () {
      testWidgets('its title in the app bar', (tester) async {
        await pump(tester);

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Mi ronda'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('"Todavía no tenés grupo" and what happens next before a '
          'group exists', (tester) async {
        await pump(tester);

        expect(find.text('Todavía no tenés grupo'), findsOneWidget);
        expect(
          find.text(
            'Armamos cada grupo con vecinos que viven cerca y buscan lo mismo '
            'que vos. Puede tardar, según cuántos se anoten. Cuando haya uno '
            'para vos, te avisamos y lo vas a ver acá.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('the waiting list under "Todavía no tenés grupo", and an '
          'offer of a freed seat on top', (tester) async {
        when(() => waitingCubit.state).thenReturn(
          WaitingState(
            status: WaitingCardStatus.ready,
            waiting: MyRondaFixtures.waiting(),
          ),
        );
        when(() => benchOfferCubit.state).thenReturn(
          BenchOfferState(
            status: BenchOfferCardStatus.ready,
            offer: MyRondaFixtures.offer(),
          ),
        );
        await pump(tester);

        expect(find.byType(WaitingCard), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(BenchOfferCard)).dy,
          lessThan(tester.getTopLeft(find.text('Todavía no tenés grupo')).dy),
        );
      });

      testWidgets('Algo chico for a member waiting for a group, with nobody '
          'to tell', (tester) async {
        when(() => smallPlanCubit.state).thenReturn(
          const SmallPlanState(
            status: SmallPlanStatus.ready,
            card: SmallPlanOffer(),
          ),
        );
        await pump(tester);

        expect(find.text('Todavía no tenés grupo'), findsOneWidget);
        expect(find.byType(SmallPlanSection), findsOneWidget);
        expect(
          find.text(
            'Mientras armamos tu grupo, ¿te proponés algo chico para esta '
            'semana?',
          ),
          findsOneWidget,
        );
        expect(find.byType(SharedPlansSection), findsNothing);
        expect(find.text('Avisarle a la ronda'), findsNothing);
      });

      testWidgets('no Algo chico while it reads', (tester) async {
        when(() => thisWeekCubit.state).thenReturn(const ThisWeekState());
        await pump(tester);

        expect(find.byType(SmallPlanSection), findsNothing);
      });

      testWidgets('a spinner and what it looks for while it reads', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        when(() => thisWeekCubit.state).thenReturn(const ThisWeekState());
        await pump(tester);

        expect(find.byType(RondaLoader), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Buscando tu ronda…')),
          isSemantics(isLiveRegion: true),
        );
        handle.dispose();
      });

      group('the ronda in place of the wait', () {
        Future<void> arrive(WidgetTester tester, {bool reduced = false}) async {
          final states = StreamController<ThisWeekState>();
          addTearDown(states.close);
          whenListen(
            thisWeekCubit,
            states.stream,
            initialState: const ThisWeekState(),
          );
          await pump(tester, reduced: reduced);
          states.add(
            ThisWeekState(
              status: ThisWeekStatus.ready,
              week: MyRondaFixtures.week(),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1));
        }

        testWidgets('settling it in', (tester) async {
          await arrive(tester);

          expect(swapMotion(), SwapMotion.settle);
          await tester.pump(AppMotion.standardDuration);
          expect(find.byType(ThisWeekCard), findsOneWidget);
          expect(find.text('Buscando tu ronda…'), findsNothing);
        });

        testWidgets('with a cross-fade under reduced motion', (tester) async {
          await arrive(tester, reduced: true);

          expect(swapMotion(), SwapMotion.crossFade);
        });
      });

      testWidgets("this week's card once there is a ronda", (tester) async {
        when(() => thisWeekCubit.state).thenReturn(
          ThisWeekState(
            status: ThisWeekStatus.ready,
            week: MyRondaFixtures.week(),
          ),
        );
        await pump(tester);

        expect(find.byType(ThisWeekCard), findsOneWidget);
      });

      testWidgets('the ¿seguimos? card above the week while there is one', (
        tester,
      ) async {
        when(() => thisWeekCubit.state).thenReturn(
          ThisWeekState(
            status: ThisWeekStatus.ready,
            week: MyRondaFixtures.week(),
          ),
        );
        when(() => seguimosCubit.state).thenReturn(
          SeguimosState(
            status: SeguimosCardStatus.ready,
            seguimos: MyRondaFixtures.seguimos(),
          ),
        );
        await pump(tester);

        expect(
          tester.getTopLeft(find.byType(SeguimosCard)).dy,
          lessThan(tester.getTopLeft(find.byType(ThisWeekCard)).dy),
        );
      });

      testWidgets('no week once the member left at the close', (tester) async {
        when(() => thisWeekCubit.state).thenReturn(
          const ThisWeekState(
            status: ThisWeekStatus.ready,
            week: ThisWeek(
              rondaId: 'r1',
              pretextId: 'mate',
              barrioId: 'el-pinar-sur',
              slotDayId: 'tue',
              slotBandId: 'afternoon',
              myBrings: [],
              hasLeft: true,
            ),
          ),
        );
        when(() => seguimosCubit.state).thenReturn(
          SeguimosState(
            status: SeguimosCardStatus.ready,
            seguimos: MyRondaFixtures.seguimos(
              open: false,
              outcome: SeguimosOutcome.gracias,
            ),
          ),
        );
        await pump(tester);

        expect(find.byType(ThisWeekCard), findsNothing);
        expect(find.byType(ActaLink), findsNothing);
        expect(find.text('Gracias por venir.'), findsOneWidget);
      });

      testWidgets("one line to the program's acta under the card", (
        tester,
      ) async {
        when(() => thisWeekCubit.state).thenReturn(
          ThisWeekState(
            status: ThisWeekStatus.ready,
            week: MyRondaFixtures.week(),
          ),
        );
        await pump(tester);
        await tester.scrollUntilVisible(find.byType(ActaLink), 200);

        expect(
          tester.widget<ActaLink>(find.byType(ActaLink)).rondaId,
          MyRondaFixtures.week().rondaId,
        );
      });

      group('"Un mate de más"', () {
        setUp(() {
          // A host's card links the meeting's roll.
          when(() => rondaRepository.watchRoll(any(), any()))
              .thenAnswer((_) => Stream.value(null));
        });

        void weekWith({required bool keepsNewcomerSeat, Host? anfitrion}) =>
            when(() => thisWeekCubit.state).thenReturn(
              ThisWeekState(
                status: ThisWeekStatus.ready,
                week: MyRondaFixtures.week(
                  keepsNewcomerSeat: keepsNewcomerSeat,
                  anfitrion: anfitrion,
                  cola: MyRondaFixtures.jorge,
                ),
              ),
            );

        testWidgets('for a host once the ronda keeps a newcomer seat', (
          tester,
        ) async {
          weekWith(keepsNewcomerSeat: true, anfitrion: MyRondaFixtures.me);
          await pump(tester);
          await tester.scrollUntilVisible(find.byType(MateFlyerEntry), 200);

          expect(
            tester.widget<MateFlyerEntry>(find.byType(MateFlyerEntry)).rondaId,
            MyRondaFixtures.week().rondaId,
          );
        });

        testWidgets('not for a member who is not a host', (tester) async {
          weekWith(keepsNewcomerSeat: true, anfitrion: MyRondaFixtures.mirta);
          await pump(tester);
          await tester.scrollUntilVisible(find.byType(ActaLink), 200);

          expect(find.byType(MateFlyerEntry), findsNothing);
        });

        testWidgets('not for a host before week 4', (tester) async {
          weekWith(keepsNewcomerSeat: false, anfitrion: MyRondaFixtures.me);
          await pump(tester);
          await tester.scrollUntilVisible(find.byType(ActaLink), 200);

          expect(find.byType(MateFlyerEntry), findsNothing);
        });
      });

      testWidgets('a row of chairs, one taken, while there is no group', (
        tester,
      ) async {
        await pump(tester);

        expect(findSketch(RondaScene.emptyChairs), findsOneWidget);
        expect(
          tester.getBottomLeft(findSketch(RondaScene.emptyChairs)).dy,
          lessThan(tester.getTopLeft(find.text('Todavía no tenés grupo')).dy),
        );
      });

      testWidgets('a retry when the ronda cannot be read', (tester) async {
        when(() => thisWeekCubit.state)
            .thenReturn(const ThisWeekState(status: ThisWeekStatus.failure));
        await pump(tester);

        expect(
          find.text('No pudimos leer tu ronda. Probá de nuevo.'),
          findsOneWidget,
        );
        expect(findSketch(RondaScene.termoAsks), findsOneWidget);
        await tester.tap(find.text('Probar de nuevo'));

        verify(thisWeekCubit.subscribe).called(1);
      });

      testWidgets('the notifications card above it while it is offered', (
        tester,
      ) async {
        when(() => pushCubit.state)
            .thenReturn(const PushState(status: PushStatus.offered));
        await pump(tester);

        expect(find.byType(PushPrompt), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('¿Te avisamos los martes?')).dy,
          lessThan(tester.getTopLeft(find.text('Todavía no tenés grupo')).dy),
        );
      });

      testWidgets('its content under the identifier Maestro waits for', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pump(tester);

        expect(
          tester.getSemantics(
            find.bySemanticsIdentifier(MyRondaPage.identifier),
          ),
          isSemantics(identifier: MyRondaPage.identifier),
        );
        expect(
          find.descendant(
            of: find.bySemanticsIdentifier(MyRondaPage.identifier),
            matching: find.text('Todavía no tenés grupo'),
          ),
          findsOneWidget,
        );
        handle.dispose();
      });
    });

    group('the Esta no sheet', () {
      final ready = ThisWeekState(
        status: ThisWeekStatus.ready,
        week: MyRondaFixtures.week(myAnswer: RsvpAnswer.no),
      );

      Future<void> open(WidgetTester tester) async {
        final states = StreamController<ThisWeekState>();
        addTearDown(states.close);
        whenListen(thisWeekCubit, states.stream, initialState: ready);
        await pump(tester);
        states.add(ready.copyWith(estaNoSheet: true));
        await tester.pumpAndSettle();
      }

      testWidgets('opens once the no is recorded', (tester) async {
        await open(tester);

        expect(find.text('Listo, esta no.'), findsOneWidget);
        expect(find.text('Nadie pregunta por qué.'), findsOneWidget);
      });

      testWidgets('Sigo en la ronda only closes it', (tester) async {
        await open(tester);

        await tester.tap(find.text('Sigo en la ronda'));
        await tester.pumpAndSettle();

        expect(find.byType(EstaNoSheet), findsNothing);
        verify(thisWeekCubit.sheetClosed).called(1);
        verifyNever(thisWeekCubit.pauseTapped);
        verifyNever(thisWeekCubit.yesTapped);
      });

      testWidgets('Pausar 2 semanas pauses', (tester) async {
        await open(tester);

        await tester.tap(find.text('Pausar 2 semanas'));
        await tester.pumpAndSettle();

        verify(thisWeekCubit.pauseTapped).called(1);
        verify(thisWeekCubit.sheetClosed).called(1);
      });

      testWidgets('Me equivoqué, voy says yes', (tester) async {
        await open(tester);

        await tester.tap(find.text('Me equivoqué, voy'));
        await tester.pumpAndSettle();

        verify(thisWeekCubit.yesTapped).called(1);
      });
    });
  });
}
