import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Object?>;

void main() {
  const line = {
    'id': 'u1',
    'firstName': 'Ana',
    'activity': 'Caminar 30 minutos por la rambla',
    'place': 'desde la parada 23',
    'kind': 'walk',
    'date': '2026-11-05',
    'time': '19:00',
    'joined': false,
  };
  const mine = {
    'activity': 'Ir a la feria',
    'place': '',
    'kind': 'feria',
    'date': '2026-11-06',
    'time': '10:00',
    'joined': ['Bruno', 'Carla'],
  };

  group(SharedPlansApi, () {
    late FakeFirebaseFirestore firestore;
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late SharedPlansApi subject;

    setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

    setUp(() {
      firestore = FakeFirebaseFirestore();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      subject = SharedPlansApi(firestore: firestore, functions: functions);
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => _MockHttpsCallableResult());
    });

    group('watchCard', () {
      test("reads the others' plans and the member's own", () async {
        await firestore.doc('rondas/r1/plan_cards/u2').set({
          'plans': [line],
          'mine': mine,
        });

        final card = await subject.watchCard('r1', 'u2').first;

        expect(card!.lines.single.firstName, equals('Ana'));
        expect(card.lines.single.id, equals('u1'));
        expect(card.lines.single.joined, isFalse);
        expect(card.mine!.joined, equals(['Bruno', 'Carla']));
        expect(card.mine!.place, isEmpty);
      });

      test('reads a card with only lines', () async {
        await firestore.doc('rondas/r1/plan_cards/u2').set({
          'plans': [line],
          'mine': null,
        });

        final card = await subject.watchCard('r1', 'u2').first;

        expect(card!.mine, isNull);
        expect(card.lines, hasLength(1));
      });

      test('is null while there is no card', () async {
        expect(await subject.watchCard('r1', 'u2').first, isNull);
      });

      test('throws on a card, a line or a plan of another shape', () {
        expect(
          () => SharedPlanCardDocument.fromJson(const {'mine': null}),
          throwsFormatException,
        );
        expect(
          () => SharedPlanCardDocument.fromJson(const {
            'plans': [
              {'id': 'u1'},
            ],
          }),
          throwsFormatException,
        );
        expect(
          () => SharedPlanCardDocument.fromJson(const {
            'plans': <Object?>[],
            'mine': {'activity': 'x'},
          }),
          throwsFormatException,
        );
        expect(
          () => SharedPlanMineDocument.fromJson(
            Map.of(mine)..['joined'] = const [1],
          ),
          throwsFormatException,
        );
      });

      test('documents with the same fields are equal', () {
        expect(
          SharedPlanLineDocument.fromJson(line),
          equals(SharedPlanLineDocument.fromJson(line)),
        );
        expect(
          SharedPlanMineDocument.fromJson(mine),
          equals(SharedPlanMineDocument.fromJson(mine)),
        );
        expect(
          SharedPlanCardDocument(
            lines: [SharedPlanLineDocument.fromJson(line)],
          ),
          equals(
            SharedPlanCardDocument(
              lines: [SharedPlanLineDocument.fromJson(line)],
            ),
          ),
        );
      });
    });

    test('share sends the plan, with a timeout', () async {
      await subject.share(
        rondaId: 'r1',
        activity: 'Caminar',
        place: 'por la rambla',
        kind: 'walk',
        date: '2026-11-05',
        time: '19:00',
      );

      final options =
          verify(
                () => functions.httpsCallable(
                  SharedPlansApi.shareCallable,
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as HttpsCallableOptions;
      expect(options.timeout, equals(SharedPlansApi.shareTimeout));
      verify(
        () => callable.call<Object?>({
          'rondaId': 'r1',
          'activity': 'Caminar',
          'place': 'por la rambla',
          'kind': 'walk',
          'date': '2026-11-05',
          'time': '19:00',
        }),
      ).called(1);
    });

    test('withdraw, join and leave call their callables', () async {
      await subject.withdraw('r1');
      await subject.join(rondaId: 'r1', authorUid: 'u1');
      await subject.leave(rondaId: 'r1', authorUid: 'u1');

      verify(() => functions.httpsCallable(SharedPlansApi.withdrawCallable))
          .called(1);
      verify(() => functions.httpsCallable(SharedPlansApi.joinCallable))
          .called(1);
      verify(() => functions.httpsCallable(SharedPlansApi.leaveCallable))
          .called(1);
      verify(() => callable.call<Object?>({'rondaId': 'r1'})).called(1);
      verify(() => callable.call<Object?>({'rondaId': 'r1', 'authorUid': 'u1'}))
          .called(2);
    });

    for (final (code, details, matcher) in [
      (
        'failed-precondition',
        {'reason': 'time'},
        isA<SharedPlanHeldException>().having(
          (e) => e.reason,
          'reason',
          'time',
        ),
      ),
      ('failed-precondition', null, isA<SharedPlanGoneException>()),
      ('permission-denied', null, isA<FirebaseFunctionsException>()),
    ]) {
      test('maps $code ${details ?? ''}', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(
            code: code,
            message: 'no',
            details: details,
          ),
        );

        expect(subject.withdraw('r1'), throwsA(matcher));
      });
    }

    test('the held exception names its reason', () {
      expect(
        const SharedPlanHeldException('phone').toString(),
        contains('phone'),
      );
    });
  });
}
