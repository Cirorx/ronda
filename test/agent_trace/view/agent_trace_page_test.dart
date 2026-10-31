import 'dart:async';

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

AgentRun _run(
  String id,
  AgentRunStatus status, {
  bool forced = false,
  String? model,
}) => AgentRun(
  id: id,
  rondaId: 'ronda-rain',
  week: '2026-W45',
  status: status,
  startedAt: _at,
  forced: forced,
  model: model ?? (forced ? '' : 'meta-models/muse-spark-open-1026'),
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

    Future<void> pump(
      WidgetTester tester,
      AgentTraceState state, {
      bool reduced = false,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        reducedMotion(
          reduced: reduced,
          child: BlocProvider.value(
            value: cubit,
            child: const AgentTraceView(),
          ),
        ),
      );
    }

    AgentTraceState withRuns({String? selected}) => AgentTraceState(
      status: AgentTraceStatus.ready,
      runs: [
        _run('a', AgentRunStatus.done),
        _run('b', AgentRunStatus.running, forced: true),
      ],
      selectedRunId: selected,
    );

    testWidgets('says what it is reading while it reads, read out', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const AgentTraceState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Leyendo lo que hizo el programa…')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('says where it is and goes back to the admin screen', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(withRuns());
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const AgentTraceView(),
                ),
              ),
            ),
            child: const Text('Propuestas'),
          ),
        ),
      );
      await tester.tap(find.text('Propuestas'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Lo que mandó el programa'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AgentTraceView), findsNothing);
    });

    testWidgets('sets the runs apart with a title, not a rule', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, withRuns(selected: 'a'));

      expect(find.byType(Divider), findsNothing);
      expect(
        tester.getSemantics(find.text('Cada vez que corrió')),
        isSemantics(isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('each run chip shrinks from the touch', (tester) async {
      await pump(tester, withRuns(selected: 'a'));

      expect(
        find.ancestor(
          of: find.byType(ChoiceChip),
          matching: find.byType(PressScale),
        ),
        findsNWidgets(2),
      );
    });

    group('swaps the steps when another run is picked', () {
      late StreamController<AgentTraceState> states;

      setUp(() => states = StreamController<AgentTraceState>());

      // Not awaited: a stream nobody listened to never reports it closed.
      tearDown(() => unawaited(states.close()));

      const runA = 'ronda-rain · terminó · meta-models/muse-spark-open-1026';
      const runB = 'ronda-rain · corriendo · a mano';

      Finder settlingIn(String text) => find.ancestor(
        of: find.text(text),
        matching: find.byType(ScaleTransition),
      );

      testWidgets('settling the new one in', (tester) async {
        whenListen(cubit, states.stream, initialState: withRuns(selected: 'a'));
        await pump(tester, withRuns(selected: 'a'));

        states.add(withRuns(selected: 'b'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(runA), findsOneWidget);
        expect(settlingIn(runB), findsWidgets);
        await tester.pumpAndSettle();
        expect(find.text(runA), findsNothing);
        expect(find.text(runB), findsOneWidget);
      });

      testWidgets('with only a cross-fade under reduced motion', (
        tester,
      ) async {
        whenListen(cubit, states.stream, initialState: withRuns(selected: 'a'));
        await pump(tester, withRuns(selected: 'a'), reduced: true);

        states.add(withRuns(selected: 'b'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(runA), findsOneWidget);
        expect(settlingIn(runB), findsNothing);
        expect(
          find.ancestor(
            of: find.text(runB),
            matching: find.byType(FadeTransition),
          ),
          findsWidgets,
        );
        await tester.pumpAndSettle();
        expect(find.text(runA), findsNothing);
      });
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

    testWidgets('a code job says it ran a rule with no model', (tester) async {
      await pump(
        tester,
        AgentTraceState(
          status: AgentTraceStatus.ready,
          runs: [_run('h', AgentRunStatus.done, model: '')],
          selectedRunId: 'h',
        ),
      );

      expect(
        find.text('ronda-rain · terminó · regla en código, sin modelo'),
        findsOneWidget,
      );
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

    testWidgets('feels each rain check as a commit', (tester) async {
      final haptics = recordHaptics(tester);
      await pump(tester, const AgentTraceState(status: AgentTraceStatus.ready));

      await tester.tap(find.text('Correr el chequeo de lluvia'));
      await tester.tap(find.text('Probar a las 22:00 (no sale nada)'));

      expect(haptics, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.lightImpact',
      ]);
    });

    testWidgets('picking a run is not a commit', (tester) async {
      final haptics = recordHaptics(tester);
      await pump(tester, withRuns(selected: 'a'));

      await tester.tap(find.textContaining('corriendo'));

      expect(haptics, isEmpty);
      verify(() => cubit.runTapped('b')).called(1);
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

    testWidgets('reads out a failed read', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const AgentTraceState(status: AgentTraceStatus.failure),
      );

      expect(
        tester.getSemantics(find.textContaining('Probá de nuevo')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
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

      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(
          find.text('Revisó 2 rondas. 1 corrida falló: mirá sus pasos.'),
        ),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('says when the run could not start', (tester) async {
      await pump(
        tester,
        const AgentTraceState(
          status: AgentTraceStatus.ready,
          rainCheck: RainCheckStatus.failed,
        ),
      );

      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(find.text('No se pudo. Probá de nuevo.')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });
  });
}
