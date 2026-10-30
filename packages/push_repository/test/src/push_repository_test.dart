import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_store/device_store.dart';
import 'package:fake_async/fake_async.dart';
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

class _MockDeviceStore extends Mock implements DeviceStore;

final _now = DateTime.utc(2026, 10, 29, 21);

void main() {
  group(PushRepository, () {
    late PushClient pushClient;
    late DeviceStore deviceStore;
    late FakeFirebaseFirestore firestore;
    late PushRepository subject;

    PushRepository buildSubject(FirebaseFirestore firestore) => PushRepository(
      pushClient: pushClient,
      rondaApi: RondaApi(
        firestore: firestore,
        storage: _MockFirebaseStorage(),
        functions: _MockFirebaseFunctions(),
      ),
      deviceStore: deviceStore,
      now: () => _now,
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
      deviceStore = _MockDeviceStore();
      firestore = FakeFirebaseFirestore();
      subject = buildSubject(firestore);
      when(() => pushClient.platform).thenReturn(PushPlatform.android);
    });

    Future<Map<String, Map<String, dynamic>>> savedTokens() async {
      final tokens = await firestore.collection('users/demo-uid/tokens').get();
      return {for (final doc in tokens.docs) doc.id: doc.data()};
    }

    test('can be built with the real clock', () {
      expect(
        PushRepository(
          pushClient: pushClient,
          rondaApi: RondaApi(
            firestore: firestore,
            storage: _MockFirebaseStorage(),
            functions: _MockFirebaseFunctions(),
          ),
          deviceStore: deviceStore,
        ),
        isA<PushRepository>(),
      );
    });

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

    group('unregisterDevice', () {
      setUp(() {
        when(pushClient.token).thenAnswer((_) async => 'fake-token');
        when(pushClient.deleteToken).thenAnswer((_) async {});
        when(pushClient.authorization)
            .thenAnswer((_) async => PushAuthorization.authorized);
      });

      Future<void> saveTokens() async {
        for (final token in ['fake-token', 'other-phone']) {
          await firestore.doc('users/demo-uid/tokens/$token').set({
            'platform': 'android',
          });
        }
      }

      test("deletes this phone's token document, then the token", () async {
        await saveTokens();

        await subject.unregisterDevice('demo-uid');

        expect((await savedTokens()).keys, equals(['other-phone']));
        verifyInOrder([pushClient.token, pushClient.deleteToken]);
      });

      test(
        'deletes the token on a phone that never allowed notifications',
        () async {
          when(pushClient.authorization)
              .thenAnswer((_) async => PushAuthorization.notDetermined);
          await saveTokens();

          await subject.unregisterDevice('demo-uid');

          expect((await savedTokens()).keys, equals(['other-phone']));
          verify(pushClient.deleteToken).called(1);
          verifyNever(pushClient.authorization);
        },
      );

      test(
        'deletes the token on a browser that allowed notifications',
        () async {
          when(() => pushClient.platform).thenReturn(PushPlatform.web);
          await saveTokens();

          await subject.unregisterDevice('demo-uid');

          expect((await savedTokens()).keys, equals(['other-phone']));
          verify(pushClient.deleteToken).called(1);
        },
      );

      for (final authorization in [
        PushAuthorization.notDetermined,
        PushAuthorization.denied,
        PushAuthorization.deniedPermanently,
      ]) {
        test('reads no token on a browser that is $authorization', () async {
          when(() => pushClient.platform).thenReturn(PushPlatform.web);
          when(pushClient.authorization).thenAnswer((_) async => authorization);

          await subject.unregisterDevice('demo-uid');

          verifyNever(pushClient.token);
          verifyNever(pushClient.deleteToken);
        });
      }

      test('only deletes the token when there is none to look up', () async {
        when(pushClient.token).thenAnswer((_) async => null);
        await saveTokens();

        await subject.unregisterDevice('demo-uid');

        expect((await savedTokens()).keys, hasLength(2));
        verify(pushClient.deleteToken).called(1);
      });

      test('throws $UnregisterDeviceFailure, without the token, when the '
          'document cannot be deleted, after deleting the token', () async {
        await expectLater(
          buildSubject(failingFirestore()).unregisterDevice('demo-uid'),
          throwsA(
            isA<UnregisterDeviceFailure>().having(
              (failure) => failure.toString(),
              'description',
              isNot(contains('fake-token')),
            ),
          ),
        );
        verify(pushClient.deleteToken).called(1);
      });

      test('throws $UnregisterDeviceFailure when the token cannot be read, '
          'after deleting it', () async {
        when(pushClient.token).thenThrow(Exception('fake-token'));

        await expectLater(
          subject.unregisterDevice('demo-uid'),
          throwsA(isA<UnregisterDeviceFailure>()),
        );
        verify(pushClient.deleteToken).called(1);
      });

      test('throws $UnregisterDeviceFailure when the token cannot be '
          'deleted', () async {
        await saveTokens();
        when(pushClient.deleteToken).thenThrow(Exception('plugin'));

        await expectLater(
          subject.unregisterDevice('demo-uid'),
          throwsA(isA<UnregisterDeviceFailure>()),
        );
        expect((await savedTokens()).keys, equals(['other-phone']));
      });

      test('gives up on a step after ${PushRepository.unregisterTimeout}', () {
        fakeAsync((async) {
          when(pushClient.token).thenAnswer((_) => Completer<String?>().future);
          Object? error;
          unawaited(
            subject.unregisterDevice('demo-uid').catchError((Object e) {
              error = e;
            }),
          );

          async.elapse(PushRepository.unregisterTimeout);

          expect(error, isA<UnregisterDeviceFailure>());
          verify(pushClient.deleteToken).called(1);
        });
      });
    });

    group('promptSnoozed', () {
      void stored(String? value) =>
          when(() => deviceStore.read(any())).thenAnswer((_) async => value);

      test('reads ${PushRepository.promptSnoozeKey}', () async {
        stored(null);

        await subject.promptSnoozed();

        verify(() => deviceStore.read(PushRepository.promptSnoozeKey))
            .called(1);
      });

      test('is false when "Ahora no" was never tapped', () async {
        stored(null);

        expect(await subject.promptSnoozed(), isFalse);
      });

      test('is true less than ${PushRepository.promptSnooze} after', () async {
        stored(
          _now
              .subtract(
                PushRepository.promptSnooze - const Duration(minutes: 1),
              )
              .toIso8601String(),
        );

        expect(await subject.promptSnoozed(), isTrue);
      });

      test('is false ${PushRepository.promptSnooze} after', () async {
        stored(_now.subtract(PushRepository.promptSnooze).toIso8601String());

        expect(await subject.promptSnoozed(), isFalse);
      });

      test('is false when the stored time is ahead of the clock', () async {
        stored(_now.add(const Duration(days: 1)).toIso8601String());

        expect(await subject.promptSnoozed(), isFalse);
      });

      test('is false when the stored value is not a time', () async {
        stored('later');

        expect(await subject.promptSnoozed(), isFalse);
      });

      test('is false when the store cannot be read', () async {
        when(() => deviceStore.read(any())).thenThrow(Exception('keystore'));

        expect(await subject.promptSnoozed(), isFalse);
      });
    });

    group('snoozePrompt', () {
      test('stores the time as ISO 8601 UTC', () async {
        when(() => deviceStore.write(any(), any())).thenAnswer((_) async {});

        await subject.snoozePrompt();

        verify(
          () => deviceStore.write(
            PushRepository.promptSnoozeKey,
            '2026-10-29T21:00:00.000Z',
          ),
        ).called(1);
      });

      test('throws $SnoozePromptFailure when it cannot be stored', () {
        when(() => deviceStore.write(any(), any()))
            .thenThrow(Exception('keystore'));

        expect(subject.snoozePrompt, throwsA(isA<SnoozePromptFailure>()));
      });
    });

    group('clearPromptSnooze', () {
      test('deletes the stored time', () async {
        when(() => deviceStore.delete(any())).thenAnswer((_) async {});

        await subject.clearPromptSnooze();

        verify(() => deviceStore.delete(PushRepository.promptSnoozeKey))
            .called(1);
      });

      test('throws $SnoozePromptFailure when it cannot be deleted', () {
        when(() => deviceStore.delete(any())).thenThrow(Exception('keystore'));

        expect(subject.clearPromptSnooze, throwsA(isA<SnoozePromptFailure>()));
      });
    });
  });
}
