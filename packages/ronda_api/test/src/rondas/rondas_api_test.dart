import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T>;

void main() {
  group(RondasApi, () {
    late FakeFirebaseFirestore firestore;
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late RondasApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      subject = RondasApi(firestore: firestore, functions: functions);
    });

    void answers(Map<Object?, Object?> data) {
      final result = _MockHttpsCallableResult<Map<Object?, Object?>>();
      when(() => result.data).thenReturn(data);
      when(() => callable.call<Map<Object?, Object?>>(any<Object?>()))
          .thenAnswer((_) async => result);
    }

    group('watchRondaIds', () {
      test('emits the ids under users/{uid}/rondas', () async {
        await firestore.doc('users/demo-001/rondas/r1').set({'joinedAt': 1});
        await firestore.doc('users/demo-002/rondas/r2').set({'joinedAt': 1});

        expect(subject.watchRondaIds('demo-001'), emits(equals(['r1'])));
      });
    });

    group('readCerca', () {
      test("reads the barrio's demand", () async {
        await firestore.doc('cerca/el-pinar-sur').set({
          'barrio': 'el-pinar-sur',
          'rondas': [
            {
              'pretext': 'mate',
              'slot': 'sat-afternoon',
              'ageFrom': 60,
              'ageTo': null,
              'members': 4,
              'cap': 6,
              'waiting': 3,
            },
          ],
          'waiting': [
            {'pretext': 'mate', 'count': 5},
          ],
        });

        final cerca = await subject.readCerca('el-pinar-sur');

        expect(cerca!.barrio, 'el-pinar-sur');
        expect([
          for (final row in cerca.slotWaiting)
            (row.pretext, row.slot, row.count),
        ], equals([('mate', 'sat-afternoon', 3)]));
        expect([
          for (final count in cerca.pretextWaiting)
            (count.pretext, count.count),
        ], equals([('mate', 5)]));
      });

      test('returns null when the barrio has no counts yet', () async {
        expect(await subject.readCerca('el-pinar-sur'), isNull);
      });
    });

    group('watchRonda', () {
      test('reads the ronda with its public place', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'sat', 'time': 'afternoon'},
          'place': {'name': 'Frente al quiosco', 'lat': 1},
          'status': 'forming',
        });

        final ronda = await subject.watchRonda('r1').first;

        expect(ronda!.id, 'r1');
        expect(ronda.pretext, 'mate');
        expect(ronda.barrio, 'el-pinar-sur');
        expect(ronda.slotDay, 'sat');
        expect(ronda.slotBand, 'afternoon');
        expect(ronda.placeName, 'Frente al quiosco');
      });

      test('reads a ronda with no place yet', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'sat', 'time': 'afternoon'},
        });

        expect((await subject.watchRonda('r1').first)!.placeName, isNull);
      });

      test('emits null while it does not exist', () {
        expect(subject.watchRonda('r1'), emits(isNull));
      });

      test('errors for another shape', () async {
        await firestore.doc('rondas/r1').set({'pretext': 'mate'});

        expect(subject.watchRonda('r1'), emitsError(isA<FormatException>()));
      });
    });

    group('watchMember', () {
      test('reads what they bring and their state', () async {
        await firestore.doc('rondas/r1/members/demo-001').set({
          'brings': ['pan'],
          'state': 'paused',
          'pausedUntil': '2026-11-14',
        });

        final member = await subject.watchMember('r1', 'demo-001').first;

        expect(member!.brings, ['pan']);
        expect(member.state, 'paused');
        expect(member.pausedUntil, '2026-11-14');
      });

      test('reads a member with no state as active', () async {
        await firestore.doc('rondas/r1/members/demo-001').set({
          'brings': <String>[],
        });

        final member = await subject.watchMember('r1', 'demo-001').first;

        expect(member!.state, 'active');
        expect(member.pausedUntil, isNull);
      });

      test('errors for another shape', () async {
        await firestore.doc('rondas/r1/members/demo-001').set({
          'brings': [1],
        });

        expect(
          subject.watchMember('r1', 'demo-001'),
          emitsError(isA<FormatException>()),
        );
      });

      test('errors without brings', () async {
        await firestore.doc('rondas/r1/members/demo-001').set({'state': 'x'});

        expect(
          subject.watchMember('r1', 'demo-001'),
          emitsError(isA<FormatException>()),
        );
      });
    });

    group('watchWeekView', () {
      test("reads who's coming and the counts", () async {
        await firestore.doc('rondas/r1/views/week').set({
          'week': '2026-W44',
          'date': '2026-10-31',
          'going': [
            {
              'uid': 'demo-001',
              'firstName': 'Marta',
              'brings': ['pan'],
            },
          ],
          'noCount': 1,
          'unansweredCount': 2,
        });

        final view = await subject.watchWeekView('r1').first;

        expect(view!.week, '2026-W44');
        expect(view.date, '2026-10-31');
        expect(view.going.single.uid, 'demo-001');
        expect(view.going.single.firstName, 'Marta');
        expect(view.going.single.brings, ['pan']);
        expect(view.noCount, 1);
        expect(view.unansweredCount, 2);
      });

      test('emits null until the server writes it', () {
        expect(subject.watchWeekView('r1'), emits(isNull));
      });

      test('errors for another shape', () async {
        await firestore.doc('rondas/r1/views/week').set({'week': 1});

        expect(subject.watchWeekView('r1'), emitsError(isA<FormatException>()));
      });

      test('errors for a going entry of another shape', () async {
        await firestore.doc('rondas/r1/views/week').set({
          'week': '2026-W44',
          'date': '2026-10-31',
          'going': [
            {'uid': 'demo-001'},
          ],
          'noCount': 0,
          'unansweredCount': 0,
        });

        expect(subject.watchWeekView('r1'), emitsError(isA<FormatException>()));
      });
    });

    group('watchAnswer', () {
      test("reads the member's own answer", () async {
        await firestore.doc('rondas/r1/answers/demo-001').set({
          'week': '2026-W44',
          'answer': 'no',
        });

        final answer = await subject.watchAnswer('r1', 'demo-001').first;

        expect(answer!.week, '2026-W44');
        expect(answer.answer, 'no');
      });

      test('errors for another shape', () async {
        await firestore.doc('rondas/r1/answers/demo-001').set({'week': 1});

        expect(
          subject.watchAnswer('r1', 'demo-001'),
          emitsError(isA<FormatException>()),
        );
      });
    });

    group('answerRsvp', () {
      test('calls answer_rsvp and returns the week it answered', () async {
        answers({'week': '2026-W44', 'answer': 'yes'});

        final week = await subject.answerRsvp(rondaId: 'r1', answer: 'yes');

        expect(week, '2026-W44');
        verify(() => functions.httpsCallable('answer_rsvp')).called(1);
        verify(
          () => callable.call<Map<Object?, Object?>>({
            'rondaId': 'r1',
            'answer': 'yes',
          }),
        ).called(1);
      });

      test('passes the week and the pause when given', () async {
        answers({'week': '2026-W44'});

        await subject.answerRsvp(
          rondaId: 'r1',
          answer: 'no',
          week: '2026-W44',
          pauseWeeks: 2,
        );

        verify(
          () => callable.call<Map<Object?, Object?>>({
            'rondaId': 'r1',
            'answer': 'no',
            'week': '2026-W44',
            'pauseWeeks': 2,
          }),
        ).called(1);
      });

      test('throws a FormatException when no week comes back', () {
        answers({});

        expect(
          subject.answerRsvp(rondaId: 'r1', answer: 'yes'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('runJob', () {
      test('calls run_job and returns the counts', () async {
        answers({'name': 'rsvp_push', 'pushed': 1, 'messages': 3});

        final counts = await subject.runJob('rsvp_push', force: true);

        expect(counts, {'pushed': 1, 'messages': 3});
        verify(() => functions.httpsCallable('run_job')).called(1);
        verify(
          () => callable.call<Map<Object?, Object?>>({
            'name': 'rsvp_push',
            'force': true,
          }),
        ).called(1);
      });

      test('is not forced by default', () async {
        answers({});

        await subject.runJob('rsvp_push');

        verify(
          () => callable.call<Map<Object?, Object?>>({
            'name': 'rsvp_push',
            'force': false,
          }),
        ).called(1);
      });
    });
  });
}
