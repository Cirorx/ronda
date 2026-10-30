import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockPilotNumbersCubit extends MockCubit<PilotNumbersState>
    implements PilotNumbersCubit;

void main() {
  group(PilotNumbersSection, () {
    late PilotNumbersCubit cubit;

    setUp(() {
      cubit = _MockPilotNumbersCubit();
      when(cubit.load).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, PilotNumbersState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const SingleChildScrollView(child: PilotNumbersSection()),
        ),
      );
    }

    final ready = PilotNumbersState(
      status: PilotNumbersStatus.ready,
      numbers: PilotFixtures.numbers,
    );

    testWidgets('shows every number as x de y', (tester) async {
      await pump(tester, ready);

      for (final line in [
        'Los números del piloto',
        'Completaron el perfil: 9 de 10 anotados',
        'En una ronda: 6 de 9',
        'Sábado a la tarde · mate en la rambla',
        'Miembros: 5 de 6',
        '31/10: van 3 de 5 · no pueden 1 · sin contestar 1',
        'Vinieron: 3 de 4 marcados',
        '2026-W45: van 0 de 5 · no pueden 0 · sin contestar 5',
        'Asistencia: sin marcar',
        '¿Seguimos?: sí 3 de 4 · no 1 · sin contestar 0',
        'Martes a la noche · truco',
        'Miembros: 4 de 6',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(
        find.text('Volvieron a la segunda reunión: 1 de 3'),
        findsNWidgets(2),
      );
    });

    testWidgets('says nobody came back yet, and no rondas', (tester) async {
      await pump(
        tester,
        const PilotNumbersState(
          status: PilotNumbersStatus.ready,
          numbers: PilotNumbers(
            profiles: CountOf(0, 0),
            seated: CountOf(0, 0),
            rondas: [],
          ),
        ),
      );

      expect(
        find.text('Volvieron: todavía no hay dos reuniones marcadas'),
        findsOneWidget,
      );
      expect(find.text('Todavía no hay rondas.'), findsOneWidget);
    });

    testWidgets('counts again on the button', (tester) async {
      await pump(tester, ready);

      await tester.ensureVisible(find.text('Contar de nuevo'));
      await tester.tap(find.text('Contar de nuevo'));

      verify(cubit.load).called(1);
    });

    testWidgets('a spinner and no button while counting the first time', (
      tester,
    ) async {
      await pump(tester, const PilotNumbersState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('a warning when counting failed', (tester) async {
      await pump(
        tester,
        const PilotNumbersState(status: PilotNumbersStatus.failure),
      );

      expect(find.byType(NoteBanner), findsOneWidget);
      expect(find.text('No pudimos contar. Probá de nuevo.'), findsOneWidget);
    });

    testWidgets('nothing for anyone but the admin', (tester) async {
      await pump(
        tester,
        const PilotNumbersState(status: PilotNumbersStatus.forbidden),
      );

      expect(find.text('Los números del piloto'), findsNothing);
    });

    testWidgets('its provider counts as the screen opens', (tester) async {
      final repository = _MockRondaRepository();
      when(repository.pilotNumbers)
          .thenAnswer((_) async => PilotFixtures.numbers);

      await tester.pumpApp(
        RepositoryProvider<RondaRepository>.value(
          value: repository,
          child: MultiBlocProvider(
            providers: [pilotNumbersProvider()],
            child: const SingleChildScrollView(child: PilotNumbersSection()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('En una ronda: 6 de 9'), findsOneWidget);
    });
  });
}

class _MockRondaRepository extends Mock implements RondaRepository;
