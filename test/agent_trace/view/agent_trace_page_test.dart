import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockOrganiserRepository extends Mock implements OrganiserRepository;

class _MockAgentTraceCubit extends MockCubit<AgentTraceState>
    implements AgentTraceCubit;

final _at = DateTime(2026, 11, 4, 18, 4);

AgentRun _run(String id, AgentRunStatus status, {bool forced = false}) =>
    AgentRun(
      id: id,
      rondaId: 'ronda-rain',
      week: '2026-W45',
      status: status,
      startedAt: _at,
      forced: forced,
      model: forced ? '' : 'meta-models/muse-spark-open-1026',
      note: forced ? '' : 'Listo: le propuse opciones al anfitrión.',
    );

void main() {
  group(AgentTracePage, () {
    testWidgets('follows the runs', (tester) async {
      final repository = _MockOrganiserRepository();
      when(repository.watchRuns).thenAnswer((_) => Stream.value(const []));

      await tester.pumpApp(
        RepositoryProvider<OrganiserRepository>.value(
          value: repository,
          child: const AgentTracePage(),
        ),
      );
      await tester.pump();

      expect(find.text('El programa todavía no corrió.'), findsOneWidget);
      verify(repository.watchRuns).called(1);
    });
  });

  group(AgentTraceView, () {
    late AgentTraceCubit cubit;

    setUp(() {
      cubit = _MockAgentTraceCubit();
      when(() => cubit.rainCheckTapped(atNight: any(named: 'atNight')))
          .thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, AgentTraceState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const AgentTraceView()),
      );
    }

    testWidgets('waits while it reads', (tester) async {
      await pump(tester, const AgentTraceState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('is for the admin only', (tester) async {
      await pump(
        tester,
        const AgentTraceState(status: AgentTraceStatus.forbidden),
      );

      expect(
        find.text('Esta pantalla es solo para quien arma las rondas.'),
        findsOneWidget,
      );
    });

    testWidgets('offers to read it again when it failed', (tester) async {
      await pump(
        tester,
        const AgentTraceState(status: AgentTraceStatus.failure),
      );

      await tester.tap(find.text('Probar de nuevo'));

      verify(cubit.subscribe).called(1);
    });

    testWidgets('lists the runs with their status and picks one', (
      tester,
    ) async {
      await pump(
        tester,
        AgentTraceState(
          status: AgentTraceStatus.ready,
          runs: [
            _run('a', AgentRunStatus.done),
            _run('b', AgentRunStatus.running, forced: true),
            _run('c', AgentRunStatus.capped),
            _run('d', AgentRunStatus.stopped),
            _run('e', AgentRunStatus.failed),
            _run('f', AgentRunStatus.other),
          ],
        ),
      );

      expect(find.textContaining('Semana 2026-W45'), findsNWidgets(6));
      for (final status in [
        'terminó',
        'corriendo',
        'llegó al tope de pasos',
        'se detuvo',
        'falló',
        'sin estado',
      ]) {
        expect(find.textContaining(status), findsOneWidget);
      }

      await tester.tap(find.textContaining('corriendo'));

      verify(() => cubit.runTapped('b')).called(1);
    });

    testWidgets('shows the selected run with its steps and the taps', (
      tester,
    ) async {
      await pump(
        tester,
        AgentTraceState(
          status: AgentTraceStatus.ready,
          runs: [_run('a', AgentRunStatus.done)],
          selectedRunId: 'a',
          steps: [
            AgentStep(
              n: 1,
              at: _at,
              kind: AgentStepKind.tool,
              tool: 'get_forecast',
              summary: 'Miró el pronóstico.',
            ),
          ],
          flagCount: 1,
        ),
      );

      expect(
        find.text('ronda-rain · terminó · meta-models/muse-spark-open-1026'),
        findsOneWidget,
      );
      expect(find.text('1 persona marcó «Algo estuvo mal».'), findsOneWidget);
      expect(
        find.text('Al final dijo: Listo: le propuse opciones al anfitrión.'),
        findsOneWidget,
      );
      expect(find.byType(AgentStepTile), findsOneWidget);
    });

    testWidgets('a run by hand says so', (tester) async {
      await pump(
        tester,
        AgentTraceState(
          status: AgentTraceStatus.ready,
          runs: [_run('b', AgentRunStatus.running, forced: true)],
          selectedRunId: 'b',
        ),
      );

      expect(find.text('ronda-rain · corriendo · a mano'), findsOneWidget);
    });

    testWidgets('runs the rain check now and at 22:00', (tester) async {
      await pump(tester, const AgentTraceState(status: AgentTraceStatus.ready));

      expect(find.text('El programa todavía no corrió.'), findsOneWidget);
      await tester.tap(find.text('Correr el chequeo de lluvia'));
      await tester.tap(find.text('Probar a las 22:00 (no sale nada)'));

      verify(cubit.rainCheckTapped).called(1);
      verify(() => cubit.rainCheckTapped(atNight: true)).called(1);
    });

    testWidgets('waits while it runs', (tester) async {
      await pump(
        tester,
        const AgentTraceState(
          status: AgentTraceStatus.ready,
          rainCheck: RainCheckStatus.running,
        ),
      );

      final run = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Corriendo…'),
      );
      final night = tester.widget<OutlinedButton>(
        find.widgetWithText(
          OutlinedButton,
          'Probar a las 22:00 (no sale nada)',
        ),
      );
      expect(run.onPressed, isNull);
      expect(night.onPressed, isNull);
    });

    testWidgets('says what the run did, and what failed', (tester) async {
      await pump(
        tester,
        const AgentTraceState(
          status: AgentTraceStatus.ready,
          rainCheck: RainCheckStatus.done,
          result: RainCheckResult(checked: 2, failed: 1),
        ),
      );

      expect(
        find.text('Revisó 2 rondas. 1 corrida falló: mirá sus pasos.'),
        findsOneWidget,
      );
    });

    testWidgets('says when the run could not start', (tester) async {
      await pump(
        tester,
        const AgentTraceState(
          status: AgentTraceStatus.ready,
          rainCheck: RainCheckStatus.failed,
        ),
      );

      expect(find.text('No se pudo. Probá de nuevo.'), findsOneWidget);
    });
  });
}
