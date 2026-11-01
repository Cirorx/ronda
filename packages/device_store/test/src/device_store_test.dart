import 'package:device_store/device_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage;

void main() {
  group(DeviceStore, () {
    late FlutterSecureStorage secureStorage;
    late DeviceStore subject;

    setUp(() {
      secureStorage = _MockFlutterSecureStorage();
      subject = DeviceStore(secureStorage: secureStorage);
    });

    test('can be instantiated without arguments', () {
      expect(const DeviceStore(), isA<DeviceStore>());
    });

    group('iosOptions', () {
      test('keep the item on this device, readable after first unlock', () {
        expect(
          DeviceStore.iosOptions.accessibility,
          equals(KeychainAccessibility.first_unlock_this_device),
        );
        expect(DeviceStore.iosOptions.synchronizable, isFalse);
      });
    });

    group('androidOptions', () {
      test("use the plugin's default RSA OAEP and AES-GCM ciphers", () {
        final options = DeviceStore.androidOptions.toMap();

        expect(
          options['keyCipherAlgorithm'],
          equals(KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding.name),
        );
        expect(
          options['storageCipherAlgorithm'],
          equals(StorageCipherAlgorithm.AES_GCM_NoPadding.name),
        );
      });
    });

    group('read', () {
      test('returns the stored value', () async {
        when(
          () => secureStorage.read(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenAnswer((_) async => 'value');

        expect(await subject.read('key'), equals('value'));
        verify(
          () => secureStorage.read(
            key: 'key',
            iOptions: DeviceStore.iosOptions,
            aOptions: DeviceStore.androidOptions,
          ),
        ).called(1);
      });

      test('returns null when nothing is stored', () async {
        when(
          () => secureStorage.read(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenAnswer((_) async => null);

        expect(await subject.read('key'), isNull);
      });
    });

    group('write', () {
      test('stores the value under the key with the device options', () async {
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenAnswer((_) async {});

        await subject.write('key', 'value');

        verify(
          () => secureStorage.write(
            key: 'key',
            value: 'value',
            iOptions: DeviceStore.iosOptions,
            aOptions: DeviceStore.androidOptions,
          ),
        ).called(1);
      });
    });

    group('delete', () {
      test('deletes the key with the device options', () async {
        when(
          () => secureStorage.delete(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenAnswer((_) async {});

        await subject.delete('key');

        verify(
          () => secureStorage.delete(
            key: 'key',
            iOptions: DeviceStore.iosOptions,
            aOptions: DeviceStore.androidOptions,
          ),
        ).called(1);
      });
    });

    group("turns a browser's error into a $DeviceStoreException", () {
      // What the web plugin lets out when crypto.subtle refuses: not an
      // Exception.
      final browserError = StateError('OperationError');

      setUp(() {
        when(
          () => secureStorage.read(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenThrow(browserError);
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenThrow(browserError);
        when(
          () => secureStorage.delete(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenThrow(browserError);
      });

      test('from read, write and delete', () async {
        for (final call in [
          () => subject.read('key'),
          () => subject.write('key', 'value'),
          () => subject.delete('key'),
        ]) {
          await expectLater(call(), throwsA(isA<DeviceStoreException>()));
        }
      });

      test('keeping an exception as it is', () async {
        final failure = Exception('keychain');
        when(
          () => secureStorage.read(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
            aOptions: any(named: 'aOptions'),
          ),
        ).thenThrow(failure);

        await expectLater(subject.read('key'), throwsA(same(failure)));
      });
    });
  });
}
