import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  slotDay: 'sat',
  slotBand: 'afternoon',
  placeName: 'Frente al quiosco',
);

const _member = MemberDocument(brings: ['pan'], state: 'active');

const _view = WeekViewDocument(
  week: '2026-W44',
  date: '2026-10-31',
  going: [
    GoingDocument(uid: 'demo-002', firstName: 'Raúl', brings: ['termo']),
  ],
  noCount: 1,
  unansweredCount: 2,
);

void main() {
  group('RondaRepository weekly loop', () {
    late RondasApi rondasApi;
    late RondaRepository subject;
    late StreamController<List<String>> ids;

    setUp(() {
      rondasApi = _MockRondasApi();
      when(() => rondasApi.watchHandoffAsk(any(), any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondasApi.watchDespues(any(), any()))
          .thenAnswer((_) => Stream.value(null));
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
      );
      ids = StreamController<List<String>>();
      when(() => rondasApi.watchRondaIds('demo-001'))
          .thenAnswer((_) => ids.stream);
      when(() => rondasApi.watchRonda('r1'))
          .thenAnswer((_) => Stream.value(_ronda));
      when(() => rondasApi.watchMember('r1', 'demo-001'))
          .thenAnswer((_) => Stream.value(_member));
      when(() => rondasApi.watchWeekView('r1'))
          .thenAnswer((_) => Stream.value(_view));
      when(() => rondasApi.watchAnswer('r1', 'demo-001')).thenAnswer(
        (_) =>
            Stream.value(const AnswerDocument(week: '2026-W44', answer: 'yes')),
      );
    });

    tearDown(() => unawaited(ids.close()));

    group('watchThisWeek', () {
      test('emits null while the member is in no ronda', () {
        ids.add([]);

        expect(subject.watchThisWeek('demo-001'), emits(isNull));
      });

      test('emits the ronda, the member and the view as one $ThisWeek', () {
        ids.add(['r1']);

        expect(
          subject.watchThisWeek('demo-001'),
          emits(
            ThisWeek(
              rondaId: 'r1',
              pretextId: 'mate',
              barrioId: 'el-pinar-sur',
              slotDayId: 'sat',
              slotBandId: 'afternoon',
              placeName: 'Frente al quiosco',
              myBrings: const ['pan'],
              week: '2026-W44',
              date: DateTime(2026, 10, 31),
              myAnswer: RsvpAnswer.yes,
              going: const [
                GoingNeighbour(
                  uid: 'demo-002',
                  firstName: 'Raúl',
                  brings: ['termo'],
                ),
              ],
              noCount: 1,
              unansweredCount: 2,
            ),
          ),
        );
      });

      test('reads a "no" and a pause', () async {
        when(() => rondasApi.watchMember('r1', 'demo-001')).thenAnswer(
          (_) => Stream.value(
            const MemberDocument(
              brings: [],
              state: 'paused',
              pausedUntil: '2026-11-14',
            ),
          ),
        );
        when(() => rondasApi.watchAnswer('r1', 'demo-001')).thenAnswer(
          (_) => Stream.value(
            const AnswerDocument(week: '2026-W44', answer: 'no'),
          ),
        );
        ids.add(['r1']);

        final week = await subject.watchThisWeek('demo-001').first;

        expect(week!.myAnswer, RsvpAnswer.no);
        expect(week.pausedUntil, DateTime(2026, 11, 14));
      });

      test("an answer for another week is not this week's", () async {
        when(() => rondasApi.watchAnswer('r1', 'demo-001')).thenAnswer(
          (_) => Stream.value(
            const AnswerDocument(week: '2026-W43', answer: 'yes'),
          ),
        );
        ids.add(['r1']);

        final week = await subject.watchThisWeek('demo-001').first;

        expect(week!.myAnswer, isNull);
      });

      test(
        'before the server writes the view it has no week or counts',
        () async {
          when(() => rondasApi.watchWeekView('r1'))
              .thenAnswer((_) => Stream.value(null));
          when(() => rondasApi.watchAnswer('r1', 'demo-001'))
              .thenAnswer((_) => Stream.value(null));
          ids.add(['r1']);

          final week = await subject.watchThisWeek('demo-001').first;

          expect(week!.week, isNull);
          expect(week.date, isNull);
          expect(week.going, isEmpty);
          expect(week.noCount, isNull);
          expect(week.myAnswer, isNull);
        },
      );

      test('emits null while the ronda or the member is missing', () {
        when(() => rondasApi.watchRonda('r1'))
            .thenAnswer((_) => Stream.value(null));
        ids.add(['r1']);

        expect(subject.watchThisWeek('demo-001'), emits(isNull));
      });

      test('follows the first ronda by id', () async {
        ids.add(['r2', 'r1']);

        final week = await subject.watchThisWeek('demo-001').first;

        expect(week!.rondaId, 'r1');
      });

      test('errors with an $RsvpFailure', () {
        when(() => rondasApi.watchWeekView('r1'))
            .thenAnswer((_) => Stream.error(const FormatException('shape')));
        ids.add(['r1']);

        expect(
          subject.watchThisWeek('demo-001'),
          emitsError(
            isA<RsvpFailure>().having(
              (f) => f.reason,
              'reason',
              RsvpFailureReason.other,
            ),
          ),
        );
      });
    });

    group('answerRsvp', () {
      test('calls answer_rsvp with the answer and the week', () async {
        when(
          () => rondasApi.answerRsvp(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
            week: any(named: 'week'),
            pauseWeeks: any(named: 'pauseWeeks'),
          ),
        ).thenAnswer((_) async => '2026-W44');

        await subject.answerRsvp(
          rondaId: 'r1',
          answer: RsvpAnswer.no,
          week: '2026-W44',
          pause: true,
        );
        await subject.answerRsvp(rondaId: 'r1', answer: RsvpAnswer.yes);

        verify(
          () => rondasApi.answerRsvp(
            rondaId: 'r1',
            answer: 'no',
            week: '2026-W44',
            pauseWeeks: 2,
          ),
        ).called(1);
        verify(() => rondasApi.answerRsvp(rondaId: 'r1', answer: 'yes'))
            .called(1);
      });

      for (final (code, reason) in [
        ('permission-denied', RsvpFailureReason.forbidden),
        ('unauthenticated', RsvpFailureReason.forbidden),
        ('failed-precondition', RsvpFailureReason.passed),
        ('unavailable', RsvpFailureReason.other),
      ]) {
        test('turns $code into $reason', () {
          when(
            () => rondasApi.answerRsvp(
              rondaId: any(named: 'rondaId'),
              answer: any(named: 'answer'),
            ),
          ).thenThrow(FirebaseFunctionsException(message: 'x', code: code));

          expect(
            subject.answerRsvp(rondaId: 'r1', answer: RsvpAnswer.yes),
            throwsA(
              isA<RsvpFailure>().having((f) => f.reason, 'reason', reason),
            ),
          );
        });
      }

      test('turns any other exception into other', () {
        when(
          () => rondasApi.answerRsvp(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
          ),
        ).thenThrow(const FormatException('no week'));

        expect(
          subject.answerRsvp(rondaId: 'r1', answer: RsvpAnswer.yes),
          throwsA(
            isA<RsvpFailure>().having(
              (f) => f.reason,
              'reason',
              RsvpFailureReason.other,
            ),
          ),
        );
      });
    });

    group('sendRsvpNow', () {
      test('forces the rsvp_push job and reads its counts', () async {
        when(() => rondasApi.runJob('rsvp_push', force: true))
            .thenAnswer((_) async => {'pushed': 1, 'messages': 5, 'rondas': 1});

        expect(
          await subject.sendRsvpNow(),
          const RsvpPushResult(pushed: 1, messages: 5, already: 0, held: 0),
        );
      });

      test('turns a refusal into forbidden', () {
        when(() => rondasApi.runJob('rsvp_push', force: true)).thenThrow(
          FirebaseException(plugin: 'functions', code: 'permission-denied'),
        );

        expect(
          subject.sendRsvpNow(),
          throwsA(
            isA<RsvpFailure>().having(
              (f) => f.reason,
              'reason',
              RsvpFailureReason.forbidden,
            ),
          ),
        );
      });
    });
  });
}
