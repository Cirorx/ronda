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

final _deadline = DateTime.utc(2026, 11, 4, 20);

Map<String, Object?> _offer({String status = 'pending'}) => {
  'rondaId': 'r1',
  'week': '2026-W45',
  'date': '2026-11-05',
  'pretext': 'mate',
  'slot': {'day': 'thu', 'time': 'afternoon'},
  'hour': '16:00',
  'placeName': 'frente al quiosco',
  'placeLandmark': 'al lado de la parada',
  'deadline': Timestamp.fromDate(_deadline),
  'status': status,
};

const _waiting = <String, Object?>{
  'seatId': 'el-pinar-sur_mate_sat-afternoon',
  'barrio': 'el-pinar-sur',
  'pretext': 'mate',
  'slot': 'sat-afternoon',
  'count': 5,
  'threshold': 6,
  'deadline': '2026-11-01',
  'start': '2026-11-07',
  'status': 'didntFill',
  'alternatives': [
    {
      'rondaId': 'r2',
      'pretext': 'truco',
      'barrio': 'el-pinar-norte',
      'slot': {'day': 'thu', 'time': 'evening'},
      'placesLeft': 3,
      'next': '2026-11-05',
    },
  ],
  'choice': 'wait',
};

void main() {
  group('RondasApi bench and waiting list', () {
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
      when(() => result.data).thenReturn(<String, Object?>{});
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
      subject = RondasApi(firestore: firestore, functions: functions);
    });

    group('watchOffers', () {
      test('reads every offer made to the person', () async {
        await firestore
            .doc('users/demo-201/offers/r1_2026-W45_01')
            .set(_offer());

        final [offer] = await subject.watchOffers('demo-201').first;

        expect(offer.id, 'r1_2026-W45_01');
        expect(
          (offer.rondaId, offer.week, offer.date, offer.pretext),
          ('r1', '2026-W45', '2026-11-05', 'mate'),
        );
        expect((offer.slotDay, offer.slotBand), ('thu', 'afternoon'));
        expect(offer.deadline.toUtc(), _deadline);
        expect(offer.status, 'pending');
        expect(offer.hour, '16:00');
        expect(offer.placeName, 'frente al quiosco');
        expect(offer.placeLandmark, 'al lado de la parada');
      });

      test('reads an offer for a ronda without place or hour', () async {
        await firestore.doc('users/demo-201/offers/o').set({
          ..._offer(),
          'hour': null,
          'placeName': null,
          'placeLandmark': null,
        });

        final [offer] = await subject.watchOffers('demo-201').first;

        expect(
          (offer.hour, offer.placeName, offer.placeLandmark),
          (null, null, null),
        );
      });

      test('errors for another shape', () async {
        await firestore.doc('users/demo-201/offers/o').set({'status': 1});

        expect(
          subject.watchOffers('demo-201'),
          emitsError(isA<FormatException>()),
        );
      });
    });

    group('answerBenchOffer', () {
      test('calls answer_bench_offer with the offer and the answer', () async {
        await subject.answerBenchOffer(offerId: 'o', take: true);

        verify(
          () => functions.httpsCallable(RondasApi.answerBenchOfferCallable),
        ).called(1);
        verify(() => callable.call<Object?>({'offerId': 'o', 'take': true}))
            .called(1);
      });
    });

    group('watchWaiting', () {
      test('reads the card with its nearby ronda and pick', () async {
        await firestore.doc('waiting/demo-201').set(_waiting);

        final waiting = (await subject.watchWaiting('demo-201').first)!;

        expect(waiting.seatId, 'el-pinar-sur_mate_sat-afternoon');
        expect(
          (waiting.barrio, waiting.pretext, waiting.slot),
          ('el-pinar-sur', 'mate', 'sat-afternoon'),
        );
        expect((waiting.count, waiting.threshold), (5, 6));
        expect((waiting.deadline, waiting.start), ('2026-11-01', '2026-11-07'));
        expect(waiting.status, 'didntFill');
        expect(waiting.alternatives.single.rondaId, 'r2');
        expect(waiting.choice, 'wait');
      });

      test('reads a card without alternatives or pick', () async {
        await firestore.doc('waiting/demo-201').set({
          ..._waiting,
          'alternatives': null,
          'choice': null,
        });

        final waiting = (await subject.watchWaiting('demo-201').first)!;

        expect(waiting.alternatives, isEmpty);
        expect(waiting.choice, isNull);
      });

      test('emits null while the person waits on no list', () {
        expect(subject.watchWaiting('demo-201'), emits(isNull));
      });

      test('errors for another shape', () async {
        await firestore.doc('waiting/demo-201').set({'count': 'five'});

        expect(
          subject.watchWaiting('demo-201'),
          emitsError(isA<FormatException>()),
        );
      });
    });

    group('answerWaitlist', () {
      test('calls answer_waitlist with the pick', () async {
        await subject.answerWaitlist('join');

        verify(() => functions.httpsCallable(RondasApi.answerWaitlistCallable))
            .called(1);
        verify(() => callable.call<Object?>({'choice': 'join'})).called(1);
      });
    });
  });
}
