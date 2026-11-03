import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T>;

const _nico = <String, Object?>{
  'week': '2026-W45',
  'date': '2026-11-05',
  'hour': '16:00',
  'newcomerName': 'Nico',
  'status': 'set',
  'choices': [
    {'uid': 'demo-101', 'firstName': 'Mirta'},
    {'uid': 'demo-102', 'firstName': 'Jorge'},
  ],
  'waiterUid': 'demo-102',
  'waiterName': 'Jorge',
  'sign': 'tiene el termo verde',
  'setBy': 'demo-101',
  'setByName': 'Mirta',
  'declined': <String>[],
};

const _lucia = <String, Object?>{
  'week': '2026-W45',
  'date': '2026-11-05',
  'newcomerName': 'Lucía',
  'status': 'open',
  'declinedName': 'Ana',
};

void main() {
  group('RondasApi first visit', () {
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

    group('watchWelcome', () {
      test("reads the newcomer's own welcome, waiter and sign", () async {
        await firestore.doc('rondas/r1/welcomes/demo-105').set(_nico);

        final welcome = (await subject.watchWelcome('r1', 'demo-105').first)!;

        expect(welcome.newcomerUid, 'demo-105');
        expect(
          (welcome.newcomerName, welcome.week, welcome.date, welcome.hour),
          ('Nico', '2026-W45', '2026-11-05', '16:00'),
        );
        expect(
          (welcome.status, welcome.waiterUid, welcome.waiterName, welcome.sign),
          ('set', 'demo-102', 'Jorge', 'tiene el termo verde'),
        );
        expect((welcome.setByUid, welcome.setByName), ('demo-101', 'Mirta'));
        expect(
          [for (final choice in welcome.choices) choice.firstName],
          ['Mirta', 'Jorge'],
        );
        expect(welcome.declinedName, isNull);
      });

      test('is null while there is none', () async {
        expect(await subject.watchWelcome('r1', 'demo-105').first, isNull);
      });

      test('an open welcome has no waiter and no choices left out', () async {
        await firestore.doc('rondas/r1/welcomes/demo-106').set(_lucia);

        final welcome = (await subject.watchWelcome('r1', 'demo-106').first)!;

        expect(
          (welcome.waiterUid, welcome.sign, welcome.hour),
          (null, null, null),
        );
        expect(welcome.choices, isEmpty);
        expect(welcome.declinedName, 'Ana');
      });

      test('another shape is refused', () {
        expect(
          () => WelcomeDocument.fromJson('x', const {'week': '2026-W45'}),
          throwsFormatException,
        );
      });
    });

    test("watchWelcomes lists the ronda's welcomes", () async {
      await firestore.doc('rondas/r1/welcomes/demo-105').set(_nico);
      await firestore.doc('rondas/r1/welcomes/demo-106').set(_lucia);

      final welcomes = await subject.watchWelcomes('r1').first;

      expect([
        for (final welcome in welcomes) welcome.newcomerName,
      ], unorderedEquals(['Nico', 'Lucía']));
    });

    test(
      'watchWelcomesFor finds only the ones a waiter was picked for',
      () async {
        await firestore.doc('rondas/r1/welcomes/demo-105').set(_nico);
        await firestore.doc('rondas/r1/welcomes/demo-106').set(_lucia);

        final welcomes = await subject.watchWelcomesFor('r1', 'demo-102').first;

        expect(
          [for (final welcome in welcomes) welcome.newcomerUid],
          ['demo-105'],
        );
      },
    );

    group('setWelcome', () {
      test('sends the pick and the sign', () async {
        await subject.setWelcome(
          rondaId: 'r1',
          newcomerUid: 'demo-105',
          waiterUid: 'demo-102',
          sign: 'tiene el termo verde',
        );
        await subject.setWelcome(
          rondaId: 'r1',
          newcomerUid: 'demo-105',
          waiterUid: 'demo-101',
        );

        verify(() => functions.httpsCallable('set_welcome')).called(2);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'newcomerUid': 'demo-105',
            'waiterUid': 'demo-102',
            'sign': 'tiene el termo verde',
          }),
        ).called(1);
        verify(
          () => callable.call<Object?>({
            'rondaId': 'r1',
            'newcomerUid': 'demo-105',
            'waiterUid': 'demo-101',
            'sign': '',
          }),
        ).called(1);
      });

      test('throws $WelcomeHeldException with the gate that held it', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'no',
            details: const {'reason': 'voseo'},
          ),
        );

        expect(
          subject.setWelcome(
            rondaId: 'r1',
            newcomerUid: 'demo-105',
            waiterUid: 'demo-102',
          ),
          throwsA(
            isA<WelcomeHeldException>().having(
              (e) => e.reason,
              'reason',
              'voseo',
            ),
          ),
        );
      });

      test('rethrows any other refusal', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(code: 'failed-precondition', message: 'x'),
        );

        expect(
          subject.setWelcome(
            rondaId: 'r1',
            newcomerUid: 'demo-105',
            waiterUid: 'demo-102',
          ),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      });
    });

    test('declineWelcome sends the newcomer', () async {
      await subject.declineWelcome(rondaId: 'r1', newcomerUid: 'demo-105');

      verify(
        () => callable.call<Object?>({
          'rondaId': 'r1',
          'newcomerUid': 'demo-105',
        }),
      ).called(1);
      verify(() => functions.httpsCallable('decline_welcome')).called(1);
    });

    test('the held exception names its gate', () {
      expect(
        const WelcomeHeldException('emoji').toString(),
        'WelcomeHeldException(emoji)',
      );
    });
  });
}
