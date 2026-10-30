import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T>;

const _alternative = <String, Object?>{
  'rondaId': 'r2',
  'line': 'Jueves a la tarde · truco',
  'pretext': 'truco',
  'barrio': 'el-pinar-norte',
  'slot': {'day': 'thu', 'time': 'afternoon'},
  'placesLeft': 2,
  'next': '2026-11-05',
};

void main() {
  group('RondasApi ¿seguimos?', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late RondasApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      final result = _MockHttpsCallableResult<Object?>();
      when(() => result.data).thenReturn({'answer': 'yes'});
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
      subject = RondasApi(firestore: firestore, functions: functions);
    });

    group('watchRonda', () {
      test('reads the season once it started', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'tue', 'time': 'afternoon'},
          'season': {'start': '2026-11-03', 'end': '2026-11-24'},
        });

        final ronda = (await subject.watchRonda('r1').first)!;

        expect(ronda.seasonStart, '2026-11-03');
        expect(ronda.seasonEnd, '2026-11-24');
      });
    });

    group('watchSeguimos', () {
      test('reads an open question with the answer so far', () async {
        await firestore.doc('rondas/r1/seguimos/demo-001').set({
          'status': 'open',
          'answer': 'yes',
        });

        final seguimos = (await subject.watchSeguimos('r1', 'demo-001').first)!;

        expect(seguimos.status, 'open');
        expect(seguimos.answer, 'yes');
        expect(seguimos.outcome, isNull);
        expect(seguimos.alternatives, isEmpty);
      });

      test('reads a close below the floor with its choices', () async {
        await firestore.doc('rondas/r1/seguimos/demo-001').set({
          'status': 'closed',
          'outcome': 'didntFill',
          'alternatives': [_alternative],
          'floor': 4,
          'wait': {'until': '2026-11-16', 'start': '2026-11-17'},
          'choice': 'wait',
        });

        final seguimos = (await subject.watchSeguimos('r1', 'demo-001').first)!;

        expect(seguimos.outcome, 'didntFill');
        expect(seguimos.floor, 4);
        expect(seguimos.waitUntil, '2026-11-16');
        expect(seguimos.waitStart, '2026-11-17');
        expect(seguimos.choice, 'wait');
        final nearby = seguimos.alternatives.single;
        expect(
          (
            nearby.rondaId,
            nearby.pretext,
            nearby.barrio,
            nearby.slotDay,
            nearby.slotBand,
            nearby.placesLeft,
            nearby.next,
          ),
          equals((
            'r2',
            'truco',
            'el-pinar-norte',
            'thu',
            'afternoon',
            2,
            '2026-11-05',
          )),
        );
      });

      test('emits null until the member is asked', () {
        expect(subject.watchSeguimos('r1', 'demo-001'), emits(isNull));
      });

      test('errors for another shape', () async {
        await firestore.doc('rondas/r1/seguimos/demo-001').set({'answer': 1});
        await firestore.doc('rondas/r1/seguimos/demo-002').set({
          'status': 'closed',
          'alternatives': [
            {'rondaId': 'r2'},
          ],
        });

        expect(
          subject.watchSeguimos('r1', 'demo-001'),
          emitsError(isA<FormatException>()),
        );
        expect(
          subject.watchSeguimos('r1', 'demo-002'),
          emitsError(isA<FormatException>()),
        );
      });
    });

    group('watchSeguimosCounts', () {
      test("reads every ronda's counts", () async {
        await firestore.doc('seguimos_counts/r1').set({
          'line': 'Sábado a la tarde · mate en la rambla',
          'status': 'season',
          'asked': 6,
          'yes': 4,
          'no': 1,
          'unanswered': 1,
          'season': {'start': '2026-11-03', 'end': '2026-11-24'},
        });
        await firestore.doc('seguimos_counts/r2').set({
          'line': 'Jueves a la tarde · truco',
          'status': 'didntFill',
          'asked': 5,
          'yes': 2,
          'no': 0,
          'unanswered': 3,
          'choices': {'join': 1, 'wait': 2},
        });

        final rows = await subject.watchSeguimosCounts().first;

        expect(rows.map((row) => row.rondaId), ['r1', 'r2']);
        expect(rows.first.seasonEnd, '2026-11-24');
        expect((rows.first.join, rows.first.wait), (0, 0));
        expect(
          (
            rows.last.line,
            rows.last.status,
            rows.last.asked,
            rows.last.yes,
            rows.last.no,
            rows.last.unanswered,
            rows.last.join,
            rows.last.wait,
            rows.last.seasonEnd,
          ),
          equals((
            'Jueves a la tarde · truco',
            'didntFill',
            5,
            2,
            0,
            3,
            1,
            2,
            null,
          )),
        );
      });

      test('errors for another shape', () async {
        await firestore.doc('seguimos_counts/r1').set({'line': 'x'});

        expect(
          subject.watchSeguimosCounts(),
          emitsError(isA<FormatException>()),
        );
      });
    });

    group('answerSeguimos', () {
      test('calls answer_seguimos with the answer', () async {
        await subject.answerSeguimos(rondaId: 'r1', answer: 'yes');

        verify(() => functions.httpsCallable('answer_seguimos')).called(1);
        verify(() => callable.call<Object?>({'rondaId': 'r1', 'answer': 'yes'}))
            .called(1);
      });

      test('or with the choice', () async {
        await subject.answerSeguimos(rondaId: 'r1', choice: 'wait');

        verify(
          () => callable.call<Object?>({'rondaId': 'r1', 'choice': 'wait'}),
        ).called(1);
      });
    });
  });
}
