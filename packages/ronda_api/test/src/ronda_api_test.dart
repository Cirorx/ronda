import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  group(RondaApi, () {
    late FakeFirebaseFirestore firestore;
    late RondaApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = RondaApi(firestore: firestore);
    });

    test('pins every function to southamerica-east1', () {
      expect(RondaApi.region, equals('southamerica-east1'));
    });

    group('watchUserExists', () {
      test('emits false when users/{uid} does not exist', () {
        expect(subject.watchUserExists('demo-uid'), emits(isFalse));
      });

      test('emits true when users/{uid} exists', () async {
        await firestore.collection('users').doc('demo-uid').set({
          'firstName': 'Marta',
        });

        expect(subject.watchUserExists('demo-uid'), emits(isTrue));
      });

      test('emits true once users/{uid} is created', () async {
        final expectation = expectLater(
          subject.watchUserExists('demo-uid'),
          emitsInOrder([isFalse, isTrue]),
        );
        await Future<void>.delayed(Duration.zero);

        await firestore.collection('users').doc('demo-uid').set({
          'firstName': 'Marta',
        });

        await expectation;
      });

      test('reads only the given uid', () async {
        await firestore.collection('users').doc('other-uid').set({
          'firstName': 'Julio',
        });

        expect(subject.watchUserExists('demo-uid'), emits(isFalse));
      });
    });
  });
}
