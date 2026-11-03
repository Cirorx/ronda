import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// {@template device_store_exception}
/// A value could not be read, written or deleted. On web the plugin does
/// its encryption in the browser, and a failure there (a value no key can
/// decrypt, storage that is full) comes out as the browser's own error,
/// not a Dart [Exception]; [DeviceStore] turns whatever its calls throw
/// into this, so callers' `on Exception` sees it. It carries no detail:
/// what is stored here never leaves the device, not even in a log.
/// {@endtemplate}
class DeviceStoreException implements Exception {
  /// {@macro device_store_exception}
  const new();

  @override
  String toString() => 'DeviceStoreException';
}

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

  /// Runs [call], keeping an [Exception] as it is and turning any other
  /// error into a [DeviceStoreException], with its stack trace.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Exception {
      rethrow;
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(const DeviceStoreException(), stackTrace);
    }
  }

  /// Returns the value stored under [key], or `null` when there is none.
  ///
  /// Throws a [DeviceStoreException] for any error that is not an
  /// [Exception] already, as [write] and [delete] do.
  Future<String?> read(String key) => _guard(
    () => _secureStorage.read(
      key: key,
      iOptions: iosOptions,
      aOptions: androidOptions,
    ),
  );

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value) => _guard(
    () => _secureStorage.write(
      key: key,
      value: value,
      iOptions: iosOptions,
      aOptions: androidOptions,
    ),
  );

  /// Deletes the value stored under [key], if any.
  Future<void> delete(String key) => _guard(
    () => _secureStorage.delete(
      key: key,
      iOptions: iosOptions,
      aOptions: androidOptions,
    ),
  );
}
