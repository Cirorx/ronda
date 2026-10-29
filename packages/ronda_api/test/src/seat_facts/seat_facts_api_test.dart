import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseStorage extends Mock implements FirebaseStorage;

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

void main() {
  group('$RondaApi seat facts', () {
    late FakeFirebaseFirestore firestore;
    late RondaApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = RondaApi(
        firestore: firestore,
        storage: _MockFirebaseStorage(),
        functions: _MockFirebaseFunctions(),
      );
    });

    Map<String, Object?> seat({
      required String barrio,
      bool endsAfterDark = false,
    }) => {
      'barrio': barrio,
      'pretext': 'mate',
      'slot': endsAfterDark ? 'thu-evening' : 'sat-afternoon',
      'blocksFrom': {'solymar-sur': 0, 'solymar-norte': 9.1},
      'hasStairs': false,
      'endsAfterDark': endsAfterDark,
      'needsCar': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    group('readSeatFacts', () {
      test('returns no seats when none are published', () async {
        expect(await subject.readSeatFacts(), isEmpty);
      });

      test('returns every published seat, keyed by its document id', () async {
        final seatFacts = firestore.collection('seat_facts');
        await seatFacts
            .doc('solymar-sur_mate_sat-afternoon')
            .set(seat(barrio: 'solymar-sur'));
        await seatFacts
            .doc('solymar-sur_mate_thu-evening')
            .set(seat(barrio: 'solymar-sur', endsAfterDark: true));

        final seats = await subject.readSeatFacts();

        expect(
          seats.map((seat) => seat.seatId),
          unorderedEquals([
            'solymar-sur_mate_sat-afternoon',
            'solymar-sur_mate_thu-evening',
          ]),
        );
        expect(
          seats
              .singleWhere((seat) => seat.seatId.endsWith('thu-evening'))
              .endsAfterDark,
          isTrue,
        );
      });

      test('skips a seat whose facts cannot be read, so it never passes the '
          'filter', () async {
        final seatFacts = firestore.collection('seat_facts');
        await seatFacts
            .doc('solymar-sur_mate_sat-afternoon')
            .set(seat(barrio: 'solymar-sur'));
        await seatFacts.doc('solymar-sur_truco_sat-afternoon').set({
          'barrio': 'solymar-sur',
        });

        final seats = await subject.readSeatFacts();

        expect(
          seats.map((seat) => seat.seatId),
          equals(['solymar-sur_mate_sat-afternoon']),
        );
      });
    });

    group('writeEligibleSeatIds', () {
      DocumentReference<Map<String, dynamic>> eligible(String uid) =>
          firestore.doc('users/$uid/private/eligible');

      test('writes users/{uid}/private/eligible with seat ids and the time '
          'only', () async {
        await subject.writeEligibleSeatIds(
          uid: 'demo-uid',
          seatIds: [
            'solymar-sur_mate_sat-afternoon',
            'solymar-norte_mate_sun-afternoon',
          ],
        );

        final data = (await eligible('demo-uid').get()).data()!;
        expect(data.keys, unorderedEquals(['seatIds', 'updatedAt']));
        expect(
          data['seatIds'],
          equals([
            'solymar-sur_mate_sat-afternoon',
            'solymar-norte_mate_sun-afternoon',
          ]),
        );
        expect(data['updatedAt'], isA<Timestamp>());
      });

      test('replaces what the phone wrote before', () async {
        await eligible('demo-uid').set({
          'seatIds': ['lagomar-sur_mate_sat-afternoon'],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await subject.writeEligibleSeatIds(uid: 'demo-uid', seatIds: []);

        final data = (await eligible('demo-uid').get()).data()!;
        expect(data['seatIds'], isEmpty);
      });

      test('writes nothing under users/{uid} itself', () async {
        await subject.writeEligibleSeatIds(
          uid: 'demo-uid',
          seatIds: ['solymar-sur_mate_sat-afternoon'],
        );

        final profile = await firestore.doc('users/demo-uid').get();
        expect(profile.exists, isFalse);
      });
    });
  });
}
