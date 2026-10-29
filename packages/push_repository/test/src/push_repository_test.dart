import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_client/push_client.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockPushClient extends Mock implements PushClient;

class _MockFirebaseStorage extends Mock implements FirebaseStorage;

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore;

void main() {
  group(PushRepository, () {
    late PushClient pushClient;
    late FakeFirebaseFirestore firestore;
    late PushRepository subject;

    PushRepository buildSubject(FirebaseFirestore firestore) => PushRepository(
      pushClient: pushClient,
      rondaApi: RondaApi(
        firestore: firestore,
        storage: _MockFirebaseStorage(),
        functions: _MockFirebaseFunctions(),
      ),
    );

    FirebaseFirestore failingFirestore() {
      final failing = _MockFirebaseFirestore();
      when(() => failing.collection(any())).thenThrow(
        FirebaseException(plugin: 'firestore', message: 'fake-token'),
      );
      return failing;
    }

    setUp(() {
      pushClient = _MockPushClient();
      firestore = FakeFirebaseFirestore();
      subject = buildSubject(firestore);
      when(() => pushClient.platform).thenReturn(PushPlatform.android);
    });

    Future<Map<String, Map<String, dynamic>>> savedTokens() async {
      final tokens = await firestore.collection('users/demo-uid/tokens').get();
      return {for (final doc in tokens.docs) doc.id: doc.data()};
    }

    group('permission', () {
      final cases = {
        PushAuthorization.authorized: PushPermission.allowed,
        PushAuthorization.notDetermined: PushPermission.notAsked,
        PushAuthorization.denied: PushPermission.refused,
        PushAuthorization.deniedPermanently: PushPermission.blocked,
      };

      for (final MapEntry(key: authorization, value: permission)
          in cases.entries) {
        test('returns $permission for $authorization', () async {
          when(pushClient.authorization).thenAnswer((_) async => authorization);

          expect(await subject.permission(), equals(permission));
        });

        test('askPermission returns $permission for $authorization', () async {
          when(pushClient.requestAuthorization)
              .thenAnswer((_) async => authorization);

          expect(await subject.askPermission(), equals(permission));
        });
      }

      test('throws $PushPermissionFailure when it cannot be read', () {
        when(pushClient.authorization).thenThrow(Exception('plugin'));

        expect(subject.permission, throwsA(isA<PushPermissionFailure>()));
      });

      test('askPermission throws $PushPermissionFailure when the prompt '
          'fails', () {
        when(pushClient.requestAuthorization).thenThrow(Exception('plugin'));

        expect(subject.askPermission, throwsA(isA<PushPermissionFailure>()));
      });
    });

    group('registerDevice', () {
      test('saves the token under the member with the platform', () async {
        when(pushClient.token).thenAnswer((_) async => 'fake-token');
        when(() => pushClient.platform).thenReturn(PushPlatform.web);

        await subject.registerDevice('demo-uid');

        final tokens = await savedTokens();
        expect(tokens.keys, equals(['fake-token']));
        expect(tokens['fake-token']?['platform'], equals('web'));
      });

      test('throws $RegisterDeviceFailure when there is no token', () async {
        when(pushClient.token).thenAnswer((_) async => null);

        await expectLater(
          subject.registerDevice('demo-uid'),
          throwsA(isA<RegisterDeviceFailure>()),
        );
        expect(await savedTokens(), isEmpty);
      });

      test('throws $RegisterDeviceFailure when the token cannot be read', () {
        when(pushClient.token).thenThrow(Exception('fake-token'));

        expect(
          () => subject.registerDevice('demo-uid'),
          throwsA(isA<RegisterDeviceFailure>()),
        );
      });

      test('throws $RegisterDeviceFailure, without the token, when the write '
          'fails', () async {
        when(pushClient.token).thenAnswer((_) async => 'fake-token');

        await expectLater(
          buildSubject(failingFirestore()).registerDevice('demo-uid'),
          throwsA(
            isA<RegisterDeviceFailure>().having(
              (failure) => failure.toString(),
              'description',
              isNot(contains('fake-token')),
            ),
          ),
        );
      });
    });

    group('keepDeviceRegistered', () {
      test('saves every new token while it is listened to', () async {
        when(() => pushClient.tokenRefreshes)
            .thenAnswer((_) => Stream.fromIterable(['fake-a', 'fake-b']));

        await subject.keepDeviceRegistered('demo-uid').drain<void>();

        expect(
          (await savedTokens()).keys,
          unorderedEquals(['fake-a', 'fake-b']),
        );
      });

      test('reports a failed save as $RegisterDeviceFailure', () {
        when(() => pushClient.tokenRefreshes)
            .thenAnswer((_) => Stream.value('fake-token'));

        expect(
          buildSubject(failingFirestore()).keepDeviceRegistered('demo-uid'),
          emitsError(isA<RegisterDeviceFailure>()),
        );
      });
    });
  });
}
