import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/push/push.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockPushRepository extends Mock implements PushRepository;

class _MockPushCubit extends MockCubit<PushState> implements PushCubit;

void main() {
  group(MyRondaPage, () {
    late AppBloc appBloc;
    late PushRepository pushRepository;

    setUp(() {
      appBloc = _MockAppBloc();
      pushRepository = _MockPushRepository();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
      when(pushRepository.permission)
          .thenAnswer((_) async => PushPermission.notAsked);
    });

    testWidgets('provides a $PushCubit that offers the notifications card', (
      tester,
    ) async {
      await tester.pumpApp(
        RepositoryProvider<PushRepository>.value(
          value: pushRepository,
          child: BlocProvider.value(value: appBloc, child: const MyRondaPage()),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(MyRondaView));
      expect(
        context.read<PushCubit>().state,
        equals(const PushState(status: PushStatus.offered)),
      );
      expect(find.text('¿Te avisamos los martes?'), findsOneWidget);
      verify(pushRepository.permission).called(1);
    });
  });

  group(MyRondaView, () {
    late PushCubit pushCubit;

    setUp(() {
      pushCubit = _MockPushCubit();
      when(() => pushCubit.state)
          .thenReturn(const PushState(status: PushStatus.dismissed));
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      BlocProvider.value(value: pushCubit, child: const MyRondaView()),
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

      testWidgets('its placeholder line', (tester) async {
        await pump(tester);

        expect(find.text('Estamos armando tu grupo'), findsOneWidget);
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
  });
}
