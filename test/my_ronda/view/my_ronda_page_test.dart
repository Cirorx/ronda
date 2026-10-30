import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/my_ronda/widgets/esta_no_sheet.dart';
import 'package:ronda/my_ronda/widgets/this_week_card.dart';
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
      expect(find.text('¿Te avisamos los martes?'), findsOneWidget);
      expect(find.text('Estamos armando tu grupo'), findsOneWidget);
      verify(pushRepository.permission).called(1);
    });
  });

  group(MyRondaView, () {
    late PushCubit pushCubit;
    late ThisWeekCubit thisWeekCubit;

    setUp(() {
      pushCubit = _MockPushCubit();
      thisWeekCubit = _MockThisWeekCubit();
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

      testWidgets('"Estamos armando tu grupo" before a group exists', (
        tester,
      ) async {
        await pump(tester);

        expect(find.text('Estamos armando tu grupo'), findsOneWidget);
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
          lessThan(tester.getTopLeft(find.text('Estamos armando tu grupo')).dy),
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
            matching: find.text('Estamos armando tu grupo'),
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
