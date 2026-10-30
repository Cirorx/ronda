import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T>;

final _at = DateTime.utc(2026, 11, 4, 21);

Map<String, Object?> _run({String status = 'done'}) => {
  'job': 'rain_check',
  'rondaId': 'r1',
  'week': '2026-W45',
  'status': status,
  'startedAt': Timestamp.fromDate(_at),
  'forced': true,
  'model': 'meta-models/muse-spark-open-1026',
  'note': 'Listo.',
};

Map<String, Object?> _move() => {
  'week': '2026-W45',
  'title': 'El jueves puede llover',
  'body': 'Jueves 16:00 · lluvia 80%.',
  'options': [
    {'id': 'asIs', 'label': 'Vamos igual', 'message': 'Vamos igual.'},
  ],
  'recipients': 3,
  'deadline': Timestamp.fromDate(_at.add(const Duration(hours: 3))),
  'status': 'pending',
  'hostFallback': true,
};

void main() {
  group(OrganiserApi, () {
    late FakeFirebaseFirestore firestore;
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late OrganiserApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      subject = OrganiserApi(firestore: firestore, functions: functions);
    });

    void answers(Map<Object?, Object?> data) {
      final result = _MockHttpsCallableResult<Map<Object?, Object?>>();
      when(() => result.data).thenReturn(data);
      when(() => callable.call<Map<Object?, Object?>>(any<Object?>()))
          .thenAnswer((_) async => result);
    }

    group('watchRuns', () {
      test('reads the newest runs first', () async {
        await firestore.doc('agent_runs/old').set({
          ..._run(),
          'startedAt': Timestamp.fromDate(
            _at.subtract(const Duration(days: 7)),
          ),
        });
        await firestore.doc('agent_runs/new').set(_run(status: 'running'));

        final runs = await subject.watchRuns().first;

        expect([for (final run in runs) run.id], ['new', 'old']);
        final run = runs.first;
        expect(run.job, 'rain_check');
        expect(run.rondaId, 'r1');
        expect(run.week, '2026-W45');
        expect(run.status, 'running');
        expect(run.startedAt.toUtc(), _at);
        expect(run.forced, isTrue);
        expect(run.model, 'meta-models/muse-spark-open-1026');
        expect(run.note, 'Listo.');
      });

      test('reads a run without model or note as empty', () async {
        await firestore.doc('agent_runs/r').set({
          ..._run(),
          'model': null,
          'note': null,
          'forced': null,
        });

        final run = (await subject.watchRuns().first).single;

        expect((run.model, run.note, run.forced), ('', '', false));
      });

      test('errors for another shape', () async {
        await firestore.doc('agent_runs/r').set({
          'job': 'rain_check',
          'startedAt': Timestamp.fromDate(_at),
        });

        expect(subject.watchRuns(), emitsError(isA<FormatException>()));
      });
    });

    group('watchSteps', () {
      test('reads every step in order with what its kind carries', () async {
        await firestore.doc('agent_runs/r/steps/002').set({
          'n': 2,
          'ts': Timestamp.fromDate(_at),
          'kind': 'message',
          'toRole': 'host',
          'toName': 'Mirta',
          'title': 'El jueves puede llover',
          'text': 'Jueves 16:00.',
          'gate': 'blocked',
          'gateName': 'quiet_hours',
          'gateReason': 'fuera de horario',
          'releaseAt': Timestamp.fromDate(_at.add(const Duration(hours: 11))),
          'outcome': 'held',
        });
        await firestore.doc('agent_runs/r/steps/001').set({
          'n': 1,
          'ts': Timestamp.fromDate(_at),
          'kind': 'tool',
          'by': 'model',
          'tool': 'get_forecast',
          'argsSummary': '{"date": "2026-11-05"}',
          'reason': 'ver si llueve',
          'resultSummary': 'Miró el pronóstico.',
          'status': 'ok',
          'latencyMs': 812,
          'model': 'scripted',
          'toolCalls': ['get_forecast', 7],
          'content': 'x',
          'why': 'y',
          'note': 'z',
        });

        final [tool, message] = await subject.watchSteps('r').first;

        expect(tool.n, 1);
        expect(tool.ts.toUtc(), _at);
        expect(tool.kind, 'tool');
        expect(tool.by, 'model');
        expect(message.by, isEmpty);
        expect(tool.tool, 'get_forecast');
        expect(tool.argsSummary, '{"date": "2026-11-05"}');
        expect(tool.reason, 'ver si llueve');
        expect(tool.resultSummary, 'Miró el pronóstico.');
        expect(tool.status, 'ok');
        expect(tool.latencyMs, 812);
        expect(tool.model, 'scripted');
        expect(tool.toolCalls, ['get_forecast']);
        expect((tool.content, tool.why, tool.note), ('x', 'y', 'z'));
        expect(tool.releaseAt, isNull);
        expect(message.toRole, 'host');
        expect(message.toName, 'Mirta');
        expect(message.title, 'El jueves puede llover');
        expect(message.text, 'Jueves 16:00.');
        expect(message.gate, 'blocked');
        expect(message.gateName, 'quiet_hours');
        expect(message.gateReason, 'fuera de horario');
        expect(message.releaseAt!.toUtc(), _at.add(const Duration(hours: 11)));
        expect(message.outcome, 'held');
        expect(message.latencyMs, 0);
        expect(message.toolCalls, isEmpty);
      });

      test('errors for another shape', () async {
        await firestore.doc('agent_runs/r/steps/001').set({'n': 1});

        expect(subject.watchSteps('r'), emitsError(isA<FormatException>()));
      });
    });

    group('watchFlagCount', () {
      test("counts the ronda's [Algo estuvo mal] taps", () async {
        await firestore.doc('acta/r1/flags/a').set({'week': '2026-W45'});
        await firestore.doc('acta/r1/flags/b').set({'week': '2026-W45'});
        await firestore.doc('acta/r2/flags/c').set({'week': '2026-W45'});

        expect(subject.watchFlagCount('r1'), emits(2));
      });
    });

    group('watchActa', () {
      test('reads the newest lines first', () async {
        for (final (id, hour) in [('a', 18), ('b', 20)]) {
          await firestore.doc('acta/r1/entries/$id').set({
            'week': '2026-W45',
            'ts': Timestamp.fromDate(DateTime.utc(2026, 11, 4, hour)),
            'tool': 'get_forecast',
            'summary': 'Línea $id.',
            'decidedBy': 'agent',
          });
        }

        final [newest, oldest] = await subject.watchActa('r1').first;

        expect(newest.id, 'b');
        expect(newest.week, '2026-W45');
        expect(newest.ts.toUtc(), DateTime.utc(2026, 11, 4, 20));
        expect(newest.tool, 'get_forecast');
        expect(newest.summary, 'Línea b.');
        expect(newest.decidedBy, 'agent');
        expect(oldest.id, 'a');
      });

      test('errors for another shape', () async {
        await firestore.doc('acta/r1/entries/a').set({
          'ts': Timestamp.fromDate(_at),
        });

        expect(subject.watchActa('r1'), emitsError(isA<FormatException>()));
      });
    });

    group('flagActa', () {
      test("writes the week under the member's uid", () async {
        await subject.flagActa(rondaId: 'r1', uid: 'demo-1', week: '2026-W45');

        final flag = (await firestore.doc('acta/r1/flags/demo-1').get()).data();
        expect(flag!['week'], '2026-W45');
        expect(flag['at'], isNotNull);
      });
    });

    group('watchMove', () {
      test('reads the proposal with its options', () async {
        await firestore.doc('rondas/r1/moves/2026-W45').set(_move());

        final move = (await subject.watchMove('r1', '2026-W45').first)!;

        expect(move.week, '2026-W45');
        expect(move.title, 'El jueves puede llover');
        expect(move.body, 'Jueves 16:00 · lluvia 80%.');
        expect(move.options.single.id, 'asIs');
        expect(move.options.single.label, 'Vamos igual');
        expect(move.options.single.message, 'Vamos igual.');
        expect(move.recipients, 3);
        expect(move.deadline.toUtc(), DateTime.utc(2026, 11, 5));
        expect(move.status, 'pending');
        expect(move.hostFallback, isTrue);
        expect(move.choice, isNull);
        expect(move.sent, isNull);
      });

      test('reads what was decided', () async {
        await firestore.doc('rondas/r1/moves/2026-W45').set({
          ..._move(),
          'status': 'decided',
          'choice': 'asIs',
          'sent': 3,
          'hostFallback': null,
        });

        final move = (await subject.watchMove('r1', '2026-W45').first)!;

        expect((move.choice, move.sent, move.hostFallback), ('asIs', 3, false));
      });

      test('emits null while there is none', () {
        expect(subject.watchMove('r1', '2026-W45'), emits(isNull));
      });

      test('errors for another shape', () async {
        await firestore.doc('rondas/r1/moves/2026-W45').set({
          ..._move(),
          'options': [
            {'id': 'asIs'},
          ],
        });
        await firestore.doc('rondas/r1/moves/2026-W46').set({'week': 'x'});

        expect(
          subject.watchMove('r1', '2026-W45'),
          emitsError(isA<FormatException>()),
        );
        expect(
          subject.watchMove('r1', '2026-W46'),
          emitsError(isA<FormatException>()),
        );
      });
    });

    group('answerMove', () {
      test("calls answer_move with the host's choice", () async {
        answers({'status': 'decided', 'sent': 3, 'held': 0});

        final result = await subject.answerMove(
          rondaId: 'r1',
          week: '2026-W45',
          choice: 'covered',
        );

        expect(result, (status: 'decided', sent: 3));
        verify(() => functions.httpsCallable('answer_move')).called(1);
        verify(
          () => callable.call<Map<Object?, Object?>>({
            'rondaId': 'r1',
            'week': '2026-W45',
            'choice': 'covered',
          }),
        ).called(1);
      });

      test('refuses an answer of another shape', () async {
        answers({'status': 'decided'});

        expect(
          subject.answerMove(rondaId: 'r1', week: 'w', choice: 'asIs'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('runRainCheck', () {
      test('runs the rain check now, forced, and returns its counts', () async {
        answers({'name': 'rain_check', 'checked': 1, 'failed': 0});

        expect(await subject.runRainCheck(), {'checked': 1, 'failed': 0});
        verify(() => functions.httpsCallable('run_job')).called(1);
        verify(
          () => callable.call<Map<Object?, Object?>>({
            'name': 'rain_check',
            'force': true,
          }),
        ).called(1);
      });

      test('runs it as if it were a given time, in UTC', () async {
        answers({'checked': 1});

        await subject.runRainCheck(at: DateTime.utc(2026, 11, 5, 1));

        verify(
          () => callable.call<Map<Object?, Object?>>({
            'name': 'rain_check',
            'force': true,
            'now': '2026-11-05T01:00:00.000Z',
          }),
        ).called(1);
      });
    });
  });
}
