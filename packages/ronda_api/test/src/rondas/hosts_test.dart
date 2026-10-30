import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T>;

const _row = <Object?, Object?>{
  'rondaId': 'r1',
  'line': 'Jueves 16:00 · mate en la rambla · frente al quiosco',
  'pretext': 'mate',
  'barrio': 'el-pinar-sur',
  'slot': {'day': 'thu', 'time': 'afternoon'},
  'hour': '16:00',
  'place': {'name': 'frente al quiosco', 'landmark': 'al lado de la parada'},
  'hosts': {'anfitrion': 'demo-101', 'cola': ''},
  'members': [
    {'uid': 'demo-102', 'firstName': 'Jorge'},
    {'uid': 'demo-101', 'firstName': 'Mirta'},
  ],
  'roll': {'week': '2026-W45', 'date': '2026-11-05', 'people': 4, 'marked': 1},
};

void main() {
  group('RondasApi hosts and attendance', () {
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

    void answers(Map<Object?, Object?> data) {
      final result = _MockHttpsCallableResult<Map<Object?, Object?>>();
      when(() => result.data).thenReturn(data);
      when(() => callable.call<Map<Object?, Object?>>(any<Object?>()))
          .thenAnswer((_) async => result);
    }

    group('watchRonda', () {
      test('reads the place, hour and hosts the admin set', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'thu', 'time': 'afternoon', 'hour': '16:00'},
          'place': {'name': 'frente al quiosco', 'landmark': 'la parada'},
          'hosts': {
            'anfitrion': 'demo-101',
            'anfitrionName': 'Mirta',
            'cola': 'demo-102',
            'colaName': 'Jorge',
          },
        });

        final ronda = (await subject.watchRonda('r1').first)!;

        expect(ronda.slotHour, '16:00');
        expect(ronda.placeLandmark, 'la parada');
        expect(
          (
            ronda.anfitrionUid,
            ronda.anfitrionName,
            ronda.colaUid,
            ronda.colaName,
          ),
          ('demo-101', 'Mirta', 'demo-102', 'Jorge'),
        );
      });

      test('reads none of them before the admin sets them', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'thu', 'time': 'afternoon'},
          'place': {'name': '', 'landmark': ''},
          'hosts': 'none',
        });

        final ronda = (await subject.watchRonda('r1').first)!;

        expect(ronda.slotHour, isNull);
        expect(ronda.placeName, isNull);
        expect(ronda.placeLandmark, isNull);
        expect(ronda.anfitrionUid, isNull);
      });

      test('reads an empty host as none', () async {
        await firestore.doc('rondas/r1').set({
          'pretext': 'mate',
          'barrio': 'el-pinar-sur',
          'slot': {'day': 'thu', 'time': 'afternoon'},
          'hosts': {'anfitrion': ''},
        });

        expect((await subject.watchRonda('r1').first)!.anfitrionUid, isNull);
      });
    });

    group('watchRoll', () {
      test('reads the people and the marks', () async {
        await firestore.doc('rondas/r1/rolls/2026-W45').set({
          'week': '2026-W45',
          'date': '2026-11-05',
          'line': 'Jueves 16:00 · mate',
          'people': [
            {'uid': 'demo-102', 'firstName': 'Jorge'},
          ],
          'marks': {'demo-102': true, 'odd': 'x'},
        });

        final roll = (await subject.watchRoll('r1', '2026-W45').first)!;

        expect(roll.week, '2026-W45');
        expect(roll.date, '2026-11-05');
        expect(roll.line, 'Jueves 16:00 · mate');
        expect(roll.people.single.firstName, 'Jorge');
        expect(roll.marks, {'demo-102': true});
      });

      test('emits null while there is none', () {
        expect(subject.watchRoll('r1', '2026-W45'), emits(isNull));
      });

      test('errors for another shape', () async {
        await firestore.doc('rondas/r1/rolls/2026-W45').set({
          'week': '2026-W45',
          'date': '2026-11-05',
          'line': 'x',
          'people': [
            {'uid': 1},
          ],
          'marks': <String, Object?>{},
        });
        await firestore.doc('rondas/r1/rolls/2026-W46').set({'week': 1});

        expect(
          subject.watchRoll('r1', '2026-W45'),
          emitsError(isA<FormatException>()),
        );
        expect(
          subject.watchRoll('r1', '2026-W46'),
          emitsError(isA<FormatException>()),
        );
      });
    });

    test('recordAttendance calls record_attendance', () async {
      await subject.recordAttendance(
        rondaId: 'r1',
        week: '2026-W45',
        uid: 'demo-102',
        came: false,
      );

      verify(() => functions.httpsCallable('record_attendance')).called(1);
      verify(
        () => callable.call<Object?>({
          'rondaId': 'r1',
          'week': '2026-W45',
          'uid': 'demo-102',
          'came': false,
        }),
      ).called(1);
    });

    group('rondaSetups', () {
      test('reads every row', () async {
        answers({
          'rondas': [
            _row,
            {
              ..._row,
              'rondaId': 'r2',
              'hour': null,
              'place': null,
              'hosts': null,
              'roll': null,
            },
          ],
        });

        final [first, second] = await subject.rondaSetups();

        verify(() => functions.httpsCallable('ronda_setups')).called(1);
        expect(first.rondaId, 'r1');
        expect(first.line, startsWith('Jueves 16:00'));
        expect((first.pretext, first.barrio), ('mate', 'el-pinar-sur'));
        expect(
          (first.slotDay, first.slotBand, first.hour),
          ('thu', 'afternoon', '16:00'),
        );
        expect(
          (first.placeName, first.placeLandmark),
          ('frente al quiosco', 'al lado de la parada'),
        );
        expect((first.anfitrionUid, first.colaUid), ('demo-101', null));
        expect(
          [for (final member in first.members) member.uid],
          ['demo-102', 'demo-101'],
        );
        final roll = first.roll!;
        expect(
          (roll.week, roll.date, roll.people, roll.marked),
          ('2026-W45', '2026-11-05', 4, 1),
        );
        expect(second.hour, isNull);
        expect(second.placeName, isNull);
        expect(second.anfitrionUid, isNull);
        expect(second.roll, isNull);
      });

      test('throws a FormatException for another shape', () async {
        for (final data in <Map<Object?, Object?>>[
          {},
          {
            'rondas': [
              {'rondaId': 'r1'},
            ],
          },
          {
            'rondas': [
              {
                ..._row,
                'members': [
                  {'uid': 1},
                ],
              },
            ],
          },
          {
            'rondas': [
              {..._row, 'roll': 'x'},
            ],
          },
        ]) {
          answers(data);
          await expectLater(
            subject.rondaSetups(),
            throwsA(isA<FormatException>()),
          );
        }
      });
    });

    group('setRondaSetup', () {
      test('sends all three at once', () async {
        await subject.setRondaSetup(
          rondaId: 'r1',
          placeName: 'frente al quiosco',
          placeLandmark: 'la parada',
          hour: '16:00',
          anfitrionUid: 'demo-101',
          colaUid: 'demo-102',
        );

        verify(() => functions.httpsCallable('set_ronda_setup')).called(1);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'place': {'name': 'frente al quiosco', 'landmark': 'la parada'},
            'hour': '16:00',
            'anfitrion': 'demo-101',
            'cola': 'demo-102',
          }),
        ).called(1);
      });

      test('sends empty values to take them away', () async {
        await subject.setRondaSetup(rondaId: 'r1', placeName: 'la plaza');
        await subject.setRondaSetup(rondaId: 'r1');

        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'place': {'name': 'la plaza', 'landmark': ''},
            'hour': null,
            'anfitrion': '',
            'cola': '',
          }),
        ).called(1);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'place': null,
            'hour': null,
            'anfitrion': '',
            'cola': '',
          }),
        ).called(1);
      });
    });
  });
}
