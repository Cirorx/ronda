import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/app/app.dart';
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
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockPushRepository extends Mock implements PushRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockPushCubit extends MockCubit<PushState> implements PushCubit;

class _MockThisWeekCubit extends MockCubit<ThisWeekState>
    implements ThisWeekCubit;

class _MockSeguimosCubit extends MockCubit<SeguimosState>
    implements SeguimosCubit;

class _MockBenchOfferCubit extends MockCubit<BenchOfferState>
    implements BenchOfferCubit;

class _MockWaitingCubit extends MockCubit<WaitingState> implements WaitingCubit;

void main() {
  group(MyRondaPage, () {
    late AppBloc appBloc;
    late PushRepository pushRepository;
    late RondaRepository rondaRepository;

    setUp(() {
      appBloc = _MockAppBloc();
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

    setUp(() {
      pushCubit = _MockPushCubit();
      thisWeekCubit = _MockThisWeekCubit();
      seguimosCubit = _MockSeguimosCubit();
      benchOfferCubit = _MockBenchOfferCubit();
      waitingCubit = _MockWaitingCubit();
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

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: pushCubit),
          BlocProvider.value(value: thisWeekCubit),
          BlocProvider.value(value: seguimosCubit),
          BlocProvider.value(value: benchOfferCubit),
          BlocProvider.value(value: waitingCubit),
        ],
        child: const MyRondaView(uid: MyRondaFixtures.uid),
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

      testWidgets('a spinner while it reads', (tester) async {
        when(() => thisWeekCubit.state).thenReturn(const ThisWeekState());
        await pump(tester);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

      testWidgets('a retry when the ronda cannot be read', (tester) async {
        when(() => thisWeekCubit.state)
            .thenReturn(const ThisWeekState(status: ThisWeekStatus.failure));
        await pump(tester);

        expect(
          find.text('No pudimos leer tu ronda. Probá de nuevo.'),
          findsOneWidget,
        );
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
