import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/app/app.dart';

void main() {
  group(PermissionPlace, () {
    test('is the app off the web, on any platform', () {
      for (final platform in TargetPlatform.values) {
        expect(
          PermissionPlace.of(web: false, platform: platform),
          equals(PermissionPlace.app),
        );
      }
    });

    test("is an iPhone's browser on the web on iOS", () {
      expect(
        PermissionPlace.of(web: true, platform: TargetPlatform.iOS),
        equals(PermissionPlace.iPhoneBrowser),
      );
    });

    test('is a browser on the web anywhere else', () {
      expect(
        PermissionPlace.of(web: true, platform: TargetPlatform.android),
        equals(PermissionPlace.browser),
      );
      expect(
        PermissionPlace.of(web: true, platform: TargetPlatform.macOS),
        equals(PermissionPlace.browser),
      );
    });

    test('reads this app instance, which tests run as the app', () {
      expect(PermissionPlace.current, equals(PermissionPlace.app));
    });
  });
}
