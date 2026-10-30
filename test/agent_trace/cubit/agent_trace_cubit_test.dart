import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/agent_trace/agent_trace.dart';

class _MockOrganiserRepository extends Mock implements OrganiserRepository;

final _at = DateTime(2026, 11, 4, 18);

AgentRun _run(String id, {String ronda = 'r1'}) => AgentRun(
  id: id,
  rondaId: ronda,
  week: '2026-W45',
  status: AgentRunStatus.done,
  startedAt: _at,
  forced: false,
  model: 'meta-models/muse-spark-open-1026',
  note: '',
);

AgentStep _step(int n) =>
    AgentStep(n: n, at: _at, kind: AgentStepKind.tool, tool: 'get_forecast');

void main() {
  group(AgentTraceCubit, () {
    late OrganiserRepository repository;

    setUpAll(() => registerFallbackValue(DateTime(2026)));
    late StreamController<List<AgentRun>> runs;

    setUp(() {
      repository = _MockOrganiserRepository();
      runs = StreamController<List<AgentRun>>.broadcast();
      when(repository.watchRuns).thenAnswer((_) => runs.stream);
      when(() => repository.watchSteps(any())).thenAnswer((invocation) {
        final id = invocation.positionalArguments.single as String;
        return Stream.value([_step(id == 'old' ? 9 : 1)]);
      });
      when(() => repository.watchFlagCount(any()))
          .thenAnswer((_) => Stream.value(2));
    });

    tearDown(() => runs.close());

    AgentTraceCubit build() => AgentTraceCubit(
      organiserRepository: repository,
      now: () => DateTime(2026, 11, 4, 15, 30),
    );

    test('starts loading', () {
      expect(build().state, const AgentTraceState());
    });

    blocTest<AgentTraceCubit, AgentTraceState>(
      "follows the newest run and its steps and the ronda's taps",
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        runs.add([_run('new'), _run('old')]);
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        AgentTraceState(
          status: AgentTraceStatus.ready,
          runs: [_run('new'), _run('old')],
          selectedRunId: 'new',
        ),
        AgentTraceState(
          status: AgentTraceStatus.ready,
          runs: [_run('new'), _run('old')],
          selectedRunId: 'new',
          steps: [_step(1)],
        ),
        AgentTraceState(
          status: AgentTraceStatus.ready,
          runs: [_run('new'), _run('old')],
          selectedRunId: 'new',
          steps: [_step(1)],
          flagCount: 2,
        ),
      ],
      verify: (_) => verify(() => repository.watchFlagCount('r1')).called(1),
    );

    blocTest<AgentTraceCubit, AgentTraceState>(
      'moves to a run that lands newer, unless an older one was picked',
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        runs.add([_run('a')]);
        await Future<void>.delayed(Duration.zero);
        runs.add([_run('b'), _run('a')]);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.selectedRunId, 'b');
        cubit.runTapped('a');
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.pinned, isTrue);
        runs.add([_run('c'), _run('b'), _run('a')]);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.selectedRunId, 'a');
        cubit
          ..runTapped('a')
          ..runTapped('c');
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.pinned, isFalse);
        runs.add([_run('d'), _run('c')]);
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.selectedRunId, 'd');
        expect(cubit.state.runs.length, 2);
      },
    );

    blocTest<AgentTraceCubit, AgentTraceState>(
      'shows nothing selected while there is no run',
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        runs.add([]);
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => const [AgentTraceState(status: AgentTraceStatus.ready)],
    );

    blocTest<AgentTraceCubit, AgentTraceState>(
      'is forbidden for anyone but the admin',
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        runs.addError(const OrganiserFailure(OrganiserFailureReason.forbidden));
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => const [AgentTraceState(status: AgentTraceStatus.forbidden)],
      errors: () => [isA<OrganiserFailure>()],
    );

    blocTest<AgentTraceCubit, AgentTraceState>(
      'fails when the runs or the steps cannot be read',
      setUp: () => when(() => repository.watchSteps(any())).thenAnswer(
        (_) =>
            Stream.error(const OrganiserFailure(OrganiserFailureReason.other)),
      ),
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        runs.add([_run('a')]);
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) => expect(cubit.state.status, AgentTraceStatus.failure),
      errors: () => [isA<OrganiserFailure>()],
    );

    blocTest<AgentTraceCubit, AgentTraceState>(
      'keeps the trace when the taps cannot be read',
      setUp: () => when(() => repository.watchFlagCount(any())).thenAnswer(
        (_) =>
            Stream.error(const OrganiserFailure(OrganiserFailureReason.other)),
      ),
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        runs.add([_run('a')]);
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.status, AgentTraceStatus.ready);
        expect(cubit.state.steps, [_step(1)]);
      },
      errors: () => [isA<OrganiserFailure>()],
    );

    blocTest<AgentTraceCubit, AgentTraceState>(
      'fails when the runs cannot be read',
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        runs.addError(const FormatException('x'));
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => const [AgentTraceState(status: AgentTraceStatus.failure)],
      errors: () => [isA<FormatException>()],
    );

    group('rain check', () {
      const result = RainCheckResult(checked: 1, failed: 0);

      blocTest<AgentTraceCubit, AgentTraceState>(
        'runs it now and keeps what it did',
        setUp: () =>
            when(() => repository.runRainCheck(at: any(named: 'at')))
                .thenAnswer((_) async => result),
        build: build,
        act: (cubit) => cubit.rainCheckTapped(),
        expect: () => const [
          AgentTraceState(rainCheck: RainCheckStatus.running),
          AgentTraceState(rainCheck: RainCheckStatus.done, result: result),
        ],
        verify: (_) => verify(repository.runRainCheck).called(1),
      );

      blocTest<AgentTraceCubit, AgentTraceState>(
        "runs it at today's 22:00 to show the gate",
        setUp: () =>
            when(() => repository.runRainCheck(at: any(named: 'at')))
                .thenAnswer((_) async => result),
        build: build,
        act: (cubit) => cubit.rainCheckTapped(atNight: true),
        verify: (_) =>
            verify(() => repository.runRainCheck(at: DateTime(2026, 11, 4, 22)))
                .called(1),
      );

      blocTest<AgentTraceCubit, AgentTraceState>(
        'says it failed',
        setUp: () => when(() => repository.runRainCheck(at: any(named: 'at')))
            .thenThrow(const OrganiserFailure(OrganiserFailureReason.other)),
        build: build,
        act: (cubit) => cubit.rainCheckTapped(),
        expect: () => const [
          AgentTraceState(rainCheck: RainCheckStatus.running),
          AgentTraceState(rainCheck: RainCheckStatus.failed),
        ],
        errors: () => [isA<OrganiserFailure>()],
      );

      blocTest<AgentTraceCubit, AgentTraceState>(
        'ignores a second tap while it runs',
        build: build,
        seed: () => const AgentTraceState(rainCheck: RainCheckStatus.running),
        act: (cubit) => cubit.rainCheckTapped(),
        expect: () => const <AgentTraceState>[],
      );
    });

    test('a selected run is one of the runs', () {
      expect(
        AgentTraceState(runs: [_run('a')], selectedRunId: 'b').selectedRun,
        isNull,
      );
    });
  });
}
