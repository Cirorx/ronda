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
  group('$RondaApi device tokens', () {
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

    group('saveDeviceToken', () {
      test(
        'writes exactly the platform and the time under the token',
        () async {
          await subject.saveDeviceToken(
            uid: 'demo-uid',
            token: 'fake-token',
            platform: 'android',
          );

          final document = await firestore
              .doc('users/demo-uid/tokens/fake-token')
              .get();
          expect(
            document.data()?.keys,
            unorderedEquals(['platform', 'updatedAt']),
          );
          expect(document.data()?['platform'], equals('android'));
          expect(document.data()?['updatedAt'], isA<Timestamp>());
        },
      );

      test('keeps one document per token when it is saved again', () async {
        for (final platform in ['android', 'web']) {
          await subject.saveDeviceToken(
            uid: 'demo-uid',
            token: 'fake-token',
            platform: platform,
          );
        }

        final tokens = await firestore
            .collection('users/demo-uid/tokens')
            .get();
        expect(tokens.docs.map((doc) => doc.id), equals(['fake-token']));
        expect(tokens.docs.single.data()['platform'], equals('web'));
      });
    });

    group('deleteDeviceToken', () {
      test("deletes that token's document and no other", () async {
        for (final token in ['fake-token', 'other-token']) {
          await subject.saveDeviceToken(
            uid: 'demo-uid',
            token: token,
            platform: 'android',
          );
        }

        await subject.deleteDeviceToken(uid: 'demo-uid', token: 'fake-token');

        final tokens = await firestore
            .collection('users/demo-uid/tokens')
            .get();
        expect(tokens.docs.map((doc) => doc.id), equals(['other-token']));
      });

      test('does nothing when the token was never saved', () async {
        await subject.deleteDeviceToken(uid: 'demo-uid', token: 'fake-token');

        final tokens = await firestore
            .collection('users/demo-uid/tokens')
            .get();
        expect(tokens.docs, isEmpty);
      });
    });
  });
}
