import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T>;

const _turn = <String, Object?>{
  'month': '2026-11',
  'anfitrion': 'demo-102',
  'anfitrionName': 'Jorge',
  'cola': 'demo-103',
  'colaName': 'Ana',
};

const _home = <String, Object?>{
  'week': '2026-W45',
  'date': '2026-11-05',
  'kind': 'home',
  'what': 'bizcochos',
  'homeOf': 'demo-103',
  'homeName': 'Ana',
  'address': 'Av. Central 1234',
  'setBy': 'demo-101',
  'setByName': 'Mirta',
  'status': 'asking',
};

void main() {
  group('RondasApi weekly loop', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late RondasApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => _MockHttpsCallableResult<Object?>());
      subject = RondasApi(firestore: firestore, functions: functions);
    });

    void answers(Object? data) {
      final result = _MockHttpsCallableResult<Object?>();
      when(() => result.data).thenReturn(data);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
    }

    group('watchRonda', () {
      test('reads the turns and who took over opening', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'thu', 'time': 'afternoon'},
          'hosts': {
            'anfitrion': 'demo-102',
            'cola': 'demo-103',
            'month': '2026-11',
          },
          'turns': [_turn],
          'opener': {
            'week': '2026-W45',
            'uid': 'demo-104',
            'firstName': 'Facu',
          },
        });

        final ronda = (await subject.watchRonda('r1').first)!;

        expect(ronda.hostsMonth, '2026-11');
        expect(ronda.turns.single.month, '2026-11');
        expect(ronda.turns.single.anfitrionUid, 'demo-102');
        expect(ronda.turns.single.anfitrionName, 'Jorge');
        expect(ronda.turns.single.colaUid, 'demo-103');
        expect(ronda.turns.single.colaName, 'Ana');
        expect(
          (ronda.openerWeek, ronda.openerUid, ronda.openerName),
          ('2026-W45', 'demo-104', 'Facu'),
        );
      });

      test('a ronda without them reads none', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'thu', 'time': 'afternoon'},
          'opener': {'week': ''},
        });

        final ronda = (await subject.watchRonda('r1').first)!;

        expect(ronda.turns, isEmpty);
        expect(ronda.openerWeek, isNull);
        expect(ronda.openerUid, isNull);
      });

      test('a turn of another shape is refused', () {
        expect(
          () => HostTurnDocument.fromJson(const {'month': '2026-11'}),
          throwsFormatException,
        );
      });
    });

    test('a guest from the bench reads as one in "who\'s coming"', () {
      final going = WeekViewDocument.fromJson(const {
        'week': '2026-W45',
        'date': '2026-11-05',
        'going': [
          {
            'uid': 'demo-900',
            'firstName': 'Leo',
            'brings': <Object?>[],
            'guest': true,
          },
          {'uid': 'demo-101', 'firstName': 'Mirta', 'brings': <Object?>[]},
        ],
        'noCount': 0,
        'unansweredCount': 0,
      }).going;

      expect([for (final person in going) person.guest], [true, false]);
    });

    group('the después', () {
      test('watchDespues reads it, and null while there is none', () async {
        expect(await subject.watchDespues('r1', '2026-W45').first, isNull);
        await firestore.doc('rondas/r1/despues/2026-W45').set(_home);

        final despues = (await subject.watchDespues('r1', '2026-W45').first)!;

        expect(despues.week, '2026-W45');
        expect(despues.kind, 'home');
        expect(despues.status, 'asking');
        expect((despues.setByUid, despues.setByName), ('demo-101', 'Mirta'));
        expect(despues.what, 'bizcochos');
        expect(despues.where, isNull);
        expect((despues.homeOfUid, despues.homeName), ('demo-103', 'Ana'));
        expect(despues.address, 'Av. Central 1234');
      });

      test('another shape is refused', () {
        expect(
          () => DespuesDocument.fromJson(const {'week': '2026-W45'}),
          throwsFormatException,
        );
      });

      test('setDespues sends only what was given', () async {
        await subject.setDespues(
          rondaId: 'r1',
          week: '2026-W45',
          kind: 'place',
          what: 'bizcochos',
          where: 'el Café del Puerto',
        );

        verify(() => functions.httpsCallable('set_despues')).called(1);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'week': '2026-W45',
            'kind': 'place',
            'what': 'bizcochos',
            'where': 'el Café del Puerto',
          }),
        ).called(1);
      });

      test('setDespues sends whose home it is and its address', () async {
        await subject.setDespues(
          rondaId: 'r1',
          week: '2026-W45',
          kind: 'home',
          what: 'bizcochos',
          homeOfUid: 'demo-103',
          address: 'Av. Central 1234',
        );

        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'week': '2026-W45',
            'kind': 'home',
            'what': 'bizcochos',
            'homeOf': 'demo-103',
            'address': 'Av. Central 1234',
          }),
        ).called(1);
      });

      test('answerDespues sends yes or no', () async {
        await subject.answerDespues(rondaId: 'r1', week: '2026-W45', yes: true);
        await subject.answerDespues(
          rondaId: 'r1',
          week: '2026-W45',
          yes: false,
        );

        verify(() => functions.httpsCallable('answer_despues')).called(2);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'week': '2026-W45',
            'answer': 'yes',
          }),
        ).called(1);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'week': '2026-W45',
            'answer': 'no',
          }),
        ).called(1);
      });
    });

    group('"¿Abrís vos?"', () {
      test("watchHandoffAsk reads the cola's question", () async {
        await firestore.doc('rondas/r1/handoff_asks/demo-102').set({
          'week': '2026-W45',
          'date': '2026-11-05',
          'hour': '16:00',
          'fromName': 'Mirta',
          'reason': 'no',
          'status': 'open',
        });

        final ask = (await subject.watchHandoffAsk('r1', 'demo-102').first)!;

        expect(
          (ask.week, ask.date, ask.hour),
          ('2026-W45', '2026-11-05', '16:00'),
        );
        expect((ask.fromName, ask.reason, ask.status), ('Mirta', 'no', 'open'));
      });

      test("the others' question names nobody", () async {
        await firestore.doc('rondas/r1/handoff_asks/demo-104').set({
          'week': '2026-W45',
          'date': '2026-11-05',
          'hour': null,
          'fromName': '',
          'reason': '',
          'status': 'open',
        });

        final ask = (await subject.watchHandoffAsk('r1', 'demo-104').first)!;

        expect((ask.fromName, ask.reason, ask.hour), ('', '', null));
      });

      test('another shape is refused', () {
        expect(
          () => HandoffAskDocument.fromJson(const {'week': '2026-W45'}),
          throwsFormatException,
        );
      });

      test('answerHandoff sends yes or no', () async {
        await subject.answerHandoff(rondaId: 'r1', week: '2026-W45', yes: true);
        await subject.answerHandoff(
          rondaId: 'r1',
          week: '2026-W45',
          yes: false,
        );

        verify(() => functions.httpsCallable('answer_handoff')).called(2);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'week': '2026-W45',
            'answer': 'no',
          }),
        ).called(1);
      });
    });

    group('the buddy', () {
      test(
        'watchBuddyAsk reads the misses, and closeBuddyAsk closes it',
        () async {
          await firestore.doc('rondas/r1/buddy_asks/demo-101').set({
            'status': 'open',
            'asks': [
              {'firstName': 'Jorge', 'day': 'thu', 'week': '2026-W45'},
            ],
          });

          final card = (await subject.watchBuddyAsk('r1', 'demo-101').first)!;
          expect(card.status, 'open');
          expect(card.asks.single.firstName, 'Jorge');
          expect(card.asks.single.day, 'thu');

          await subject.closeBuddyAsk('r1', 'demo-101');

          final closed = await firestore
              .doc('rondas/r1/buddy_asks/demo-101')
              .get();
          expect(closed.data()!['status'], 'closed');
          expect(closed.data()!['closedAt'], isNotNull);
        },
      );

      test('another shape is refused', () {
        expect(
          () => BuddyAskDocument.fromJson(const {'status': 'open'}),
          throwsFormatException,
        );
        expect(
          () => BuddyMissDocument.fromJson(const {'firstName': 'Jorge'}),
          throwsFormatException,
        );
      });

      test('buddyOptions reads the choices and who was chosen', () async {
        answers(const {
          'due': true,
          'chosen': true,
          'buddyUid': 'demo-101',
          'buddyName': 'Mirta',
          'choices': [
            {'uid': 'demo-101', 'firstName': 'Mirta'},
          ],
        });

        final options = await subject.buddyOptions('r1');

        verify(() => functions.httpsCallable('buddy_options')).called(1);
        expect((options.due, options.chosen), (true, true));
        expect((options.buddyUid, options.buddyName), ('demo-101', 'Mirta'));
        expect(options.choices.single.firstName, 'Mirta');
      });

      test('buddyOptions refuses another shape', () async {
        answers(const {'due': true});

        await expectLater(subject.buddyOptions('r1'), throwsFormatException);
      });

      test('setBuddy sends the uid, or an empty one for nobody', () async {
        await subject.setBuddy(rondaId: 'r1', buddyUid: 'demo-101');
        await subject.setBuddy(rondaId: 'r1');

        verify(() => functions.httpsCallable('set_buddy')).called(2);
        verify(() => callable.call<Object?>({'rondaId': 'r1', 'buddyUid': ''}))
            .called(1);
      });
    });

    group("the admin's list", () {
      const row = <Object?, Object?>{
        'rondaId': 'r1',
        'line': 'Jueves 16:00 · mate en la rambla',
        'pretext': 'mate',
        'barrio': 'el-pinar-sur',
        'slot': {'day': 'thu', 'time': 'afternoon'},
        'members': <Object?>[],
        'handoff': {
          'week': '2026-W45',
          'date': '2026-11-05',
          'step': 'taken',
          'fromName': 'Mirta',
          'takenName': 'Facu',
        },
      };

      test('carries the upcoming meeting\'s "¿Abrís vos?"', () {
        final handoff = RondaSetupDocument.fromJson(row).handoff!;

        expect((handoff.week, handoff.date), ('2026-W45', '2026-11-05'));
        expect(
          (handoff.step, handoff.fromName, handoff.takenName),
          ('taken', 'Mirta', 'Facu'),
        );
      });

      test('a handoff of another shape is refused', () {
        expect(
          () => HandoffSummaryDocument.fromJson(const {'week': '2026-W45'}),
          throwsFormatException,
        );
      });
    });
  });
}
