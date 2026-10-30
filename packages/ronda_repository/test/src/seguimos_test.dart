import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

class _MockRondasApi extends Mock implements RondasApi;

const _ronda = RondaDocument(
  id: 'r1',
  pretext: 'mate',
  barrio: 'el-pinar-sur',
  slotDay: 'tue',
  slotBand: 'afternoon',
  seasonStart: '2026-11-03',
  seasonEnd: '2026-11-24',
);

const _nearby = NearbyRondaDocument(
  rondaId: 'r2',
  pretext: 'truco',
  barrio: 'el-pinar-norte',
  slotDay: 'thu',
  slotBand: 'afternoon',
  placesLeft: 2,
  next: '2026-11-05',
);

Matcher _failsWith(RsvpFailureReason reason) =>
    throwsA(isA<RsvpFailure>().having((f) => f.reason, 'reason', reason));

void main() {
  group('RondaRepository ¿seguimos?', () {
    late RondasApi rondasApi;
    late RondaRepository subject;
    late StreamController<List<String>> ids;

    setUp(() {
      rondasApi = _MockRondasApi();
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
      );
      ids = StreamController<List<String>>();
      when(() => rondasApi.watchRondaIds('demo-001'))
          .thenAnswer((_) => ids.stream);
      when(() => rondasApi.watchRonda('r1'))
          .thenAnswer((_) => Stream.value(_ronda));
      when(
        () => rondasApi.answerSeguimos(
          rondaId: any(named: 'rondaId'),
          answer: any(named: 'answer'),
          choice: any(named: 'choice'),
        ),
      ).thenAnswer((_) async {});
    });

    group('watchThisWeek', () {
      test('says when the member left at the close', () {
        ids.add(['r1']);
        when(() => rondasApi.watchMember('r1', 'demo-001')).thenAnswer(
          (_) => Stream.value(const MemberDocument(brings: [], state: 'left')),
        );
        when(() => rondasApi.watchWeekView('r1'))
            .thenAnswer((_) => Stream.value(null));
        when(() => rondasApi.watchAnswer('r1', 'demo-001'))
            .thenAnswer((_) => Stream.value(null));

        expect(
          subject.watchThisWeek('demo-001'),
          emits(isA<ThisWeek>().having((w) => w.hasLeft, 'hasLeft', isTrue)),
        );
      });
    });

    group('watchSeguimos', () {
      test('emits null while the member is in no ronda', () {
        ids.add([]);

        expect(subject.watchSeguimos('demo-001'), emits(isNull));
      });

      test('emits null until the member is asked', () {
        ids.add(['r1']);
        when(() => rondasApi.watchSeguimos('r1', 'demo-001'))
            .thenAnswer((_) => Stream.value(null));

        expect(subject.watchSeguimos('demo-001'), emits(isNull));
      });

      test('reads an open question with the answer so far', () {
        ids.add(['r1']);
        when(() => rondasApi.watchSeguimos('r1', 'demo-001')).thenAnswer(
          (_) => Stream.value(
            const SeguimosDocument(status: 'open', answer: 'no'),
          ),
        );

        expect(
          subject.watchSeguimos('demo-001'),
          emits(
            Seguimos(
              rondaId: 'r1',
              slotDayId: 'tue',
              open: true,
              myAnswer: SeguimosAnswer.no,
              seasonEnd: DateTime(2026, 11, 24),
            ),
          ),
        );
      });

      test('reads a close below the floor with its dates and choice', () {
        ids.add(['r1']);
        when(() => rondasApi.watchSeguimos('r1', 'demo-001')).thenAnswer(
          (_) => Stream.value(
            const SeguimosDocument(
              status: 'closed',
              answer: 'yes',
              outcome: 'didntFill',
              alternatives: [
                _nearby,
                NearbyRondaDocument(
                  rondaId: 'r3',
                  pretext: 'mate',
                  barrio: 'el-pinar-sur',
                  slotDay: 'sun',
                  slotBand: 'morning',
                  placesLeft: 1,
                  next: 'soon',
                ),
              ],
              floor: 4,
              waitUntil: '2026-11-16',
              waitStart: '2026-11-17',
              choice: 'join',
            ),
          ),
        );

        expect(
          subject.watchSeguimos('demo-001'),
          emits(
            Seguimos(
              rondaId: 'r1',
              slotDayId: 'tue',
              open: false,
              myAnswer: SeguimosAnswer.yes,
              outcome: SeguimosOutcome.didntFill,
              seasonEnd: DateTime(2026, 11, 24),
              alternatives: [
                NearbyRonda(
                  rondaId: 'r2',
                  pretextId: 'truco',
                  barrioId: 'el-pinar-norte',
                  slotDayId: 'thu',
                  slotBandId: 'afternoon',
                  placesLeft: 2,
                  next: DateTime(2026, 11, 5),
                ),
              ],
              floor: 4,
              waitUntil: DateTime(2026, 11, 16),
              waitStart: DateTime(2026, 11, 17),
              choice: SeguimosChoice.join,
            ),
          ),
        );
      });

      test('errors with an $RsvpFailure', () {
        ids.add(['r1']);
        when(() => rondasApi.watchSeguimos('r1', 'demo-001'))
            .thenAnswer((_) => Stream.error(const FormatException('shape')));

        expect(
          subject.watchSeguimos('demo-001'),
          emitsError(isA<RsvpFailure>()),
        );
      });
    });

    group('answerSeguimos', () {
      test('calls answer_seguimos with the answer', () async {
        await subject.answerSeguimos(rondaId: 'r1', answer: SeguimosAnswer.yes);

        verify(() => rondasApi.answerSeguimos(rondaId: 'r1', answer: 'yes'))
            .called(1);
      });

      test('turns a closed question into passed', () {
        when(
          () => rondasApi.answerSeguimos(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
          ),
        ).thenThrow(
          FirebaseException(plugin: 'functions', code: 'failed-precondition'),
        );

        expect(
          subject.answerSeguimos(rondaId: 'r1', answer: SeguimosAnswer.no),
          _failsWith(RsvpFailureReason.passed),
        );
      });
    });

    group('chooseAfterSeguimos', () {
      test('calls answer_seguimos with the choice', () async {
        await subject.chooseAfterSeguimos(
          rondaId: 'r1',
          choice: SeguimosChoice.wait,
        );

        verify(() => rondasApi.answerSeguimos(rondaId: 'r1', choice: 'wait'))
            .called(1);
      });
    });

    group('watchSeguimosCounts', () {
      test('reads each ronda by its counts', () {
        when(() => rondasApi.watchSeguimosCounts()).thenAnswer(
          (_) => Stream.value(const [
            SeguimosCountsDocument(
              rondaId: 'r1',
              line: 'Martes a la tarde · mate en la rambla',
              status: 'season',
              asked: 6,
              yes: 4,
              no: 1,
              unanswered: 1,
              seasonEnd: '2026-11-24',
            ),
            SeguimosCountsDocument(
              rondaId: 'r2',
              line: 'Jueves a la tarde · truco',
              status: 'unknown',
              asked: 5,
              yes: 2,
              no: 0,
              unanswered: 3,
              join: 1,
              wait: 2,
            ),
          ]),
        );

        expect(
          subject.watchSeguimosCounts(),
          emits([
            SeguimosCounts(
              rondaId: 'r1',
              line: 'Martes a la tarde · mate en la rambla',
              status: SeguimosStatus.season,
              yes: 4,
              no: 1,
              unanswered: 1,
              seasonEnd: DateTime(2026, 11, 24),
            ),
            const SeguimosCounts(
              rondaId: 'r2',
              line: 'Jueves a la tarde · truco',
              status: SeguimosStatus.open,
              yes: 2,
              no: 0,
              unanswered: 3,
              join: 1,
              wait: 2,
            ),
          ]),
        );
      });

      for (final (error, reason) in [
        (
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
          RsvpFailureReason.forbidden,
        ),
        (const FormatException('shape'), RsvpFailureReason.other),
      ]) {
        test('turns ${error.runtimeType} into $reason', () {
          when(() => rondasApi.watchSeguimosCounts())
              .thenAnswer((_) => Stream.error(error));

          expect(
            subject.watchSeguimosCounts(),
            emitsError(
              isA<RsvpFailure>().having((f) => f.reason, 'reason', reason),
            ),
          );
        });
      }
    });
  });
}
