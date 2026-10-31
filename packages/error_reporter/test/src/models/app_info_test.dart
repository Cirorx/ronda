import 'dart:async';

import 'package:error_reporter/error_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _info() => PackageInfo(
  appName: 'Ronda',
  packageName: 'com.ciroapps.ronda',
  version: '1.0.0',
  buildNumber: '3',
);

void main() {
  group(AppInfo, () {
    group('load', () {
      test('reads the version and build on a phone', () async {
        final app = await AppInfo.load(
          flavor: 'production',
          isWeb: false,
          platform: TargetPlatform.iOS,
          packageInfo: () async => _info(),
        );

        expect(
          app,
          equals(
            const AppInfo(
              platform: 'ios',
              version: '1.0.0',
              build: '3',
              flavor: 'production',
            ),
          ),
        );
      });

      test('says web on web', () async {
        final app = await AppInfo.load(
          flavor: 'development',
          isWeb: true,
          packageInfo: () async => _info(),
        );

        expect(app.platform, equals('web'));
      });

      test('falls back to the running platform', () async {
        final app = await AppInfo.load(
          flavor: 'development',
          packageInfo: () async => _info(),
        );

        expect(app.platform, equals(defaultTargetPlatform.name.toLowerCase()));
      });

      test('is unknown when the version takes too long', () async {
        final app = await AppInfo.load(
          flavor: 'production',
          packageInfo: () => Completer<PackageInfo>().future,
          timeout: const Duration(milliseconds: 10),
        );

        expect(app.version, equals('unknown'));
      });

      test('is unknown when the version can not be read', () async {
        final app = await AppInfo.load(
          flavor: 'development',
          packageInfo: () => Future.error(Exception('offline')),
        );

        expect(app.version, equals('unknown'));
        expect(app.build, equals('unknown'));
      });
    });
  });
}
