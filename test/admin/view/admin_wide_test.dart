import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda/ronda_setup/ronda_setup.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../../ronda_setup/fixtures.dart';
import '../fixtures.dart';

class _MockProposalsCubit extends MockCubit<ProposalsState>
    implements ProposalsCubit;

class _MockRsvpPushCubit extends MockCubit<RsvpPushState>
    implements RsvpPushCubit;

class _MockSeguimosCountsCubit extends MockCubit<SeguimosCountsState>
    implements SeguimosCountsCubit;

class _MockPilotNumbersCubit extends MockCubit<PilotNumbersState>
    implements PilotNumbersCubit;

class _MockAgentTraceCubit extends MockCubit<AgentTraceState>
    implements AgentTraceCubit;

class _MockRondaSetupCubit extends MockCubit<RondaSetupState>
    implements RondaSetupCubit;

final _at = DateTime(2026, 11, 4, 18, 4);

void main() {
  group('$AdminView on wide windows', () {
    late ProposalsCubit cubit;
    late RsvpPushCubit rsvpPushCubit;
    late SeguimosCountsCubit seguimosCountsCubit;
    late PilotNumbersCubit pilotNumbersCubit;

    final withUnseated = ProposalsState(
      status: ProposalsStatus.ready,
      proposal: AdminFixtures.proposal(
        unseated: const [
          UnseatedPerson(
            uid: 'eva',
            firstName: 'Eva',
            barrioId: 'el-pinar-norte',
            slotIds: ['sat-afternoon'],
            pretextIds: ['mate'],
          ),
        ],
      ),
    );

    setUp(() {
      seguimosCountsCubit = _MockSeguimosCountsCubit();
      when(() => seguimosCountsCubit.state).thenReturn(
        const SeguimosCountsState(status: SeguimosCountsStatus.ready),
      );
      pilotNumbersCubit = _MockPilotNumbersCubit();
      when(() => pilotNumbersCubit.state).thenReturn(const PilotNumbersState());
      cubit = _MockProposalsCubit();
      rsvpPushCubit = _MockRsvpPushCubit();
      when(() => rsvpPushCubit.state).thenReturn(const RsvpPushState());
    });

    Future<void> pump(
      WidgetTester tester,
      ProposalsState state, {
      Size size = desktopSize,
      double textScale = 1,
    }) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: rsvpPushCubit),
            BlocProvider.value(value: seguimosCountsCubit),
            BlocProvider.value(value: pilotNumbersCubit),
          ],
          child: const AdminView(),
        ),
        size: size,
        textScale: textScale,
      );
      await tester.pump();
    }

    testWidgets('keeps one list at ${phoneSize.width} px', (tester) async {
      await pump(tester, withUnseated, size: phoneSize);

      expect(find.byType(PaperColumns), findsNothing);
      expect(find.byType(ReadableColumn), findsNothing);
    });

    testWidgets('keeps a readable column at ${tabletSize.width} px', (
      tester,
    ) async {
      await pump(tester, withUnseated, size: tabletSize);

      expect(find.byType(PaperColumns), findsNothing);
      expect(
        tester.getSize(find.byType(RuledMargin)).width,
        WindowSize.readableWidth,
      );
    });

    group('at ${desktopSize.width} px', () {
      testWidgets('puts who is left out beside the proposal', (tester) async {
        await pump(tester, withUnseated);

        expect(find.byType(PaperColumns), findsOneWidget);
        expect(
          tester.getRect(find.byType(UnseatedList)).left,
          greaterThan(tester.getRect(find.byType(AdminProposalCard)).right),
        );
        expect(find.text('Eva'), findsOneWidget);
      });

      testWidgets('keeps one column with no proposal yet', (tester) async {
        await pump(tester, const ProposalsState(status: ProposalsStatus.ready));

        expect(find.byType(PaperColumns), findsNothing);
        expect(find.byType(ReadableColumn), findsOneWidget);
      });

      testWidgets('holds at 200% text', (tester) async {
        await pump(tester, withUnseated, textScale: 2);

        expect(tester.takeException(), isNull);
        expect(find.byType(UnseatedList), findsOneWidget);
      });
    });
  });

  group('$AgentTraceView on wide windows', () {
    late AgentTraceCubit cubit;

    final state = AgentTraceState(
      status: AgentTraceStatus.ready,
      runs: [
        AgentRun(
          id: 'a',
          rondaId: 'ronda-rain',
          week: '2026-W45',
          status: AgentRunStatus.done,
          startedAt: _at,
          forced: false,
          model: 'meta-models/muse-spark-open-1026',
          note: '',
        ),
      ],
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
    );

    setUp(() => cubit = _MockAgentTraceCubit());

    Future<void> pump(
      WidgetTester tester, {
      Size size = desktopSize,
      double textScale = 1,
    }) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpApp(
        BlocProvider.value(value: cubit, child: const AgentTraceView()),
        size: size,
        textScale: textScale,
      );
      await tester.pump();
    }

    testWidgets('keeps the trace under the runs at ${phoneSize.width} px', (
      tester,
    ) async {
      await pump(tester, size: phoneSize);

      expect(find.byType(PaperColumns), findsNothing);
      expect(find.byType(AgentStepTile), findsOneWidget);
    });

    testWidgets('keeps a readable column at ${tabletSize.width} px', (
      tester,
    ) async {
      await pump(tester, size: tabletSize);

      expect(find.byType(PaperColumns), findsNothing);
      expect(find.byType(ReadableColumn), findsOneWidget);
    });

    testWidgets('puts the trace beside the runs at ${desktopSize.width} px', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(PaperColumns), findsOneWidget);
      expect(
        tester.getRect(find.byType(AgentStepTile)).left,
        greaterThan(tester.getRect(find.byType(ChipPicker)).right),
      );
    });

    testWidgets('holds at 200% text at ${desktopSize.width} px', (
      tester,
    ) async {
      await pump(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.byType(AgentStepTile), findsOneWidget);
    });
  });

  group('$RondaSetupView on wide windows', () {
    late RondaSetupCubit cubit;

    setUp(() {
      cubit = _MockRondaSetupCubit();
      when(() => cubit.state).thenReturn(
        const RondaSetupState(
          status: RondaSetupStatus.ready,
          rondas: [SetupFixtures.bare],
        ),
      );
    });

    for (final size in windowSizes) {
      testWidgets('fits the rondas at ${size.width} px', (tester) async {
        await tester.pumpApp(
          BlocProvider.value(value: cubit, child: const RondaSetupView()),
          size: size,
        );

        expect(find.text('El Pinar Sur'), findsOneWidget);
        if (size == phoneSize) {
          expect(find.byType(RuledMargin), findsNothing);
        } else {
          expect(
            tester.getSize(find.byType(RuledMargin)).width,
            WindowSize.readableWidth,
          );
        }
      });
    }
  });
}
