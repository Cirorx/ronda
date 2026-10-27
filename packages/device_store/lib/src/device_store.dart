import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// {@template device_store}
/// Thin client over flutter_secure_storage for string values that never
/// leave this device.
///
/// Every call passes the same platform options: on iOS the Keychain item is
/// readable after the first unlock and is never migrated to another device;
/// on Android the plugin's default ciphers (RSA OAEP key wrapping, AES-GCM
/// data) are used. It logs nothing.
/// {@endtemplate}
class DeviceStore {
  /// {@macro device_store}
  const new({this._secureStorage = const FlutterSecureStorage()});

  final FlutterSecureStorage _secureStorage;

  /// iOS Keychain options used on every call.
  static const iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Android options used on every call: the plugin's recommended default.
  static const AndroidOptions androidOptions = AndroidOptions.defaultOptions;

  /// Returns the value stored under [key], or `null` when there is none.
  Future<String?> read(String key) => _secureStorage.read(
    key: key,
    iOptions: iosOptions,
    aOptions: androidOptions,
  );

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value) => _secureStorage.write(
    key: key,
    value: value,
    iOptions: iosOptions,
    aOptions: androidOptions,
  );

  /// Deletes the value stored under [key], if any.
  Future<void> delete(String key) => _secureStorage.delete(
    key: key,
    iOptions: iosOptions,
    aOptions: androidOptions,
  );
}
