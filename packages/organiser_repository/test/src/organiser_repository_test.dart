import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockOrganiserApi extends Mock implements OrganiserApi;

final _at = DateTime.utc(2026, 11, 4, 21);

ActaEntryDocument _entry(String id, String week, int hour, String by) =>
    ActaEntryDocument(
      id: id,
      week: week,
      ts: DateTime.utc(2026, 11, 4, hour),
      tool: 'get_forecast',
      summary: 'Línea $id.',
      decidedBy: by,
    );

MoveDocument _move({String status = 'pending', String? choice}) => MoveDocument(
  week: '2026-W45',
  title: 'El jueves puede llover',
  body: 'Jueves 16:00 · lluvia 80%.',
  options: const [
    MoveOptionDocument(
      id: 'covered',
      label: 'Al Salón',
      message: 'Nos vemos en el Salón.',
    ),
    MoveOptionDocument(id: 'home', label: 'En lo de Mirta', message: 'x'),
    MoveOptionDocument(id: 'asIs', label: 'Vamos igual', message: 'Igual.'),
  ],
  recipients: 3,
  deadline: _at,
  status: status,
  hostFallback: true,
  choice: choice,
  sent: choice == null ? null : 3,
);

void main() {
  group(OrganiserRepository, () {
    late OrganiserApi api;
    late OrganiserRepository subject;

    setUp(() {
      api = _MockOrganiserApi();
      subject = OrganiserRepository(organiserApi: api);
    });

    group('watchRuns', () {
      test('reads each run with its status', () {
        when(api.watchRuns).thenAnswer(
          (_) => Stream.value([
            for (final status in ['running', 'done', 'brand-new'])
              AgentRunDocument(
                id: status,
                job: 'rain_check',
                rondaId: 'r1',
                week: '2026-W45',
                status: status,
                startedAt: _at,
                forced: true,
                model: 'm',
                note: 'Listo.',
              ),
          ]),
        );

        expect(
          subject.watchRuns(),
          emits([
            AgentRun(
              id: 'running',
              rondaId: 'r1',
              week: '2026-W45',
              status: AgentRunStatus.running,
              startedAt: _at,
              forced: true,
              model: 'm',
              note: 'Listo.',
            ),
            isA<AgentRun>().having(
              (r) => r.status,
              'status',
              AgentRunStatus.done,
            ),
            isA<AgentRun>().having(
              (r) => r.status,
              'status',
              AgentRunStatus.other,
            ),
          ]),
        );
      });

      test('turns a refused read into a forbidden failure', () {
        when(api.watchRuns).thenAnswer(
          (_) => Stream.error(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ),
        );

        expect(
          subject.watchRuns(),
          emitsError(
            isA<OrganiserFailure>().having(
              (f) => f.reason,
              'reason',
              OrganiserFailureReason.forbidden,
            ),
          ),
        );
      });
    });

    group('watchSteps', () {
      test('reads what each kind of step carries', () {
        when(() => api.watchSteps('r')).thenAnswer(
          (_) => Stream.value([
            AgentStepDocument(
              n: 1,
              ts: _at,
              kind: 'model',
              by: 'model',
              toolCalls: const ['get_sunset', 'count_rsvps'],
              content: 'Miro.',
              latencyMs: 900,
              model: 'm',
            ),
            AgentStepDocument(
              n: 2,
              ts: _at,
              kind: 'tool',
              tool: 'get_forecast',
              argsSummary: '{}',
              reason: 'ver',
              resultSummary: 'Miró.',
              status: 'refused',
            ),
            AgentStepDocument(
              n: 3,
              ts: _at,
              kind: 'message',
              toRole: 'host',
              toName: 'Mirta',
              text: 'Jueves.',
              gateReason: 'fuera de horario',
              releaseAt: _at,
              outcome: 'held',
            ),
            AgentStepDocument(n: 4, ts: _at, kind: 'stop', why: 'tope'),
            AgentStepDocument(
              n: 5,
              ts: _at,
              kind: 'note',
              by: 'code',
              note: 'nota',
            ),
            AgentStepDocument(
              n: 6,
              ts: _at,
              kind: 'tool',
              status: 'invalid',
              outcome: 'weird',
            ),
            AgentStepDocument(n: 7, ts: _at, kind: 'brand-new'),
          ]),
        );

        expect(
          subject.watchSteps('r'),
          emits([
            AgentStep(
              n: 1,
              at: _at,
              kind: AgentStepKind.model,
              by: StepAuthor.model,
              tool: 'get_sunset, count_rsvps',
              summary: 'Miro.',
              latency: const Duration(milliseconds: 900),
              model: 'm',
            ),
            AgentStep(
              n: 2,
              at: _at,
              kind: AgentStepKind.tool,
              tool: 'get_forecast',
              arguments: '{}',
              reason: 'ver',
              summary: 'Miró.',
              refused: true,
            ),
            AgentStep(
              n: 3,
              at: _at,
              kind: AgentStepKind.message,
              toName: 'Mirta',
              toHost: true,
              text: 'Jueves.',
              outcome: MessageOutcome.held,
              heldBecause: 'fuera de horario',
              releaseAt: _at,
            ),
            AgentStep(n: 4, at: _at, kind: AgentStepKind.stop, summary: 'tope'),
            AgentStep(
              n: 5,
              at: _at,
              kind: AgentStepKind.note,
              by: StepAuthor.code,
              summary: 'nota',
            ),
            AgentStep(n: 6, at: _at, kind: AgentStepKind.tool, refused: true),
            AgentStep(n: 7, at: _at, kind: AgentStepKind.other),
          ]),
        );
      });
    });

    group('watchFlagCount', () {
      test('passes the count through', () {
        when(() => api.watchFlagCount('r1')).thenAnswer((_) => Stream.value(2));

        expect(subject.watchFlagCount('r1'), emits(2));
      });
    });

    group('watchActa', () {
      test("keeps the newest week's lines, oldest first", () {
        when(() => api.watchActa('r1')).thenAnswer(
          (_) => Stream.value([
            _entry('d', '2026-W45', 21, 'rule'),
            _entry('c', '2026-W45', 20, 'host'),
            _entry('b', '2026-W45', 18, 'agent'),
            _entry('a', '2026-W44', 18, 'agent'),
          ]),
        );

        expect(
          subject.watchActa('r1'),
          emits(
            Acta(
              week: '2026-W45',
              lines: [
                ActaLine(
                  id: 'b',
                  at: DateTime.utc(2026, 11, 4, 18),
                  summary: 'Línea b.',
                  byHost: false,
                ),
                ActaLine(
                  id: 'c',
                  at: DateTime.utc(2026, 11, 4, 20),
                  summary: 'Línea c.',
                  byHost: true,
                ),
                ActaLine(
                  id: 'd',
                  at: DateTime.utc(2026, 11, 4, 21),
                  summary: 'Línea d.',
                  byHost: false,
                  byRule: true,
                ),
              ],
            ),
          ),
        );
      });

      test('is empty while the program has done nothing', () {
        when(() => api.watchActa('r1')).thenAnswer((_) => Stream.value([]));

        expect(subject.watchActa('r1'), emits(const Acta()));
      });

      test('turns a shape error into another failure', () {
        when(() => api.watchActa('r1'))
            .thenAnswer((_) => Stream.error(const FormatException('x')));

        expect(
          subject.watchActa('r1'),
          emitsError(
            isA<OrganiserFailure>().having(
              (f) => f.reason,
              'reason',
              OrganiserFailureReason.other,
            ),
          ),
        );
      });
    });

    group('reportActa', () {
      test("writes the member's tap", () async {
        when(() => api.flagActa(rondaId: 'r1', uid: 'u', week: '2026-W45'))
            .thenAnswer((_) async {});

        await subject.reportActa(rondaId: 'r1', uid: 'u', week: '2026-W45');

        verify(() => api.flagActa(rondaId: 'r1', uid: 'u', week: '2026-W45'))
            .called(1);
      });

      test('turns a refused write into a forbidden failure', () {
        when(
          () => api.flagActa(
            rondaId: any(named: 'rondaId'),
            uid: any(named: 'uid'),
            week: any(named: 'week'),
          ),
        ).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
        );

        expect(
          subject.reportActa(rondaId: 'r1', uid: 'u', week: 'w'),
          throwsA(
            isA<OrganiserFailure>().having(
              (f) => f.reason,
              'reason',
              OrganiserFailureReason.forbidden,
            ),
          ),
        );
      });
    });

    group('watchMove', () {
      test(
        'reads the proposal, leaving out choices this app does not know',
        () {
          when(() => api.watchMove('r1', '2026-W45'))
              .thenAnswer((_) => Stream.value(_move()));

          expect(
            subject.watchMove('r1', '2026-W45'),
            emits(
              RainMove(
                title: 'El jueves puede llover',
                forecast: 'Jueves 16:00 · lluvia 80%.',
                options: const [
                  RainOption(
                    choice: MoveChoice.covered,
                    label: 'Al Salón',
                    message: 'Nos vemos en el Salón.',
                  ),
                  RainOption(
                    choice: MoveChoice.asIs,
                    label: 'Vamos igual',
                    message: 'Igual.',
                  ),
                ],
                recipients: 3,
                deadline: _at,
                status: RainMoveStatus.pending,
                standIn: true,
              ),
            ),
          );
        },
      );

      test('reads what was decided and the option picked', () async {
        when(() => api.watchMove('r1', 'w')).thenAnswer(
          (_) => Stream.value(_move(status: 'decided', choice: 'asIs')),
        );

        final move = (await subject.watchMove('r1', 'w').first)!;

        expect(move.status, RainMoveStatus.decided);
        expect(move.choice, MoveChoice.asIs);
        expect(move.sent, 3);
        expect(move.picked!.label, 'Vamos igual');
      });

      test('reads a status it does not know as expired', () async {
        when(() => api.watchMove('r1', 'w'))
            .thenAnswer((_) => Stream.value(_move(status: 'odd')));

        final move = (await subject.watchMove('r1', 'w').first)!;

        expect(move.status, RainMoveStatus.expired);
        expect(move.picked, isNull);
      });

      test('emits null while there is none', () {
        when(() => api.watchMove('r1', 'w'))
            .thenAnswer((_) => Stream.value(null));

        expect(subject.watchMove('r1', 'w'), emits(isNull));
      });
    });

    group('answerMove', () {
      test('sends the pick and says whether it went already', () async {
        when(() => api.answerMove(rondaId: 'r1', week: 'w', choice: 'covered'))
            .thenAnswer((_) async => (status: 'decided', sent: 3));
        when(() => api.answerMove(rondaId: 'r1', week: 'w', choice: 'asIs'))
            .thenAnswer((_) async => (status: 'already', sent: 3));

        expect(
          await subject.answerMove(
            rondaId: 'r1',
            week: 'w',
            choice: MoveChoice.covered,
          ),
          const MoveAnswer(sent: 3, already: false),
        );
        expect(
          await subject.answerMove(
            rondaId: 'r1',
            week: 'w',
            choice: MoveChoice.asIs,
          ),
          const MoveAnswer(sent: 3, already: true),
        );
      });

      test('a pick after the deadline is late', () {
        when(
          () => api.answerMove(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
            choice: any(named: 'choice'),
          ),
        ).thenThrow(
          FirebaseFunctionsException(
            message: 'the time to pick has passed',
            code: 'failed-precondition',
          ),
        );

        expect(
          subject.answerMove(rondaId: 'r1', week: 'w', choice: MoveChoice.asIs),
          throwsA(
            isA<OrganiserFailure>().having(
              (f) => f.reason,
              'reason',
              OrganiserFailureReason.late,
            ),
          ),
        );
      });
    });

    group('runRainCheck', () {
      test('returns what it did', () async {
        when(() => api.runRainCheck(at: _at))
            .thenAnswer((_) async => {'checked': 2, 'failed': 1, 'rondas': 3});
        when(api.runRainCheck).thenAnswer((_) async => {});

        expect(
          await subject.runRainCheck(at: _at),
          const RainCheckResult(checked: 2, failed: 1),
        );
        expect(
          await subject.runRainCheck(),
          const RainCheckResult(checked: 0, failed: 0),
        );
      });
    });
  });
}
