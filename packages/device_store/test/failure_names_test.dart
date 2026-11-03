import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const DeviceStoreException().toString(),
        equals('DeviceStoreException'),
      );
    });
  });
}
