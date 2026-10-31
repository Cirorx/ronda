import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// {@template app_info}
/// Where a report comes from: the platform, the app's version and build,
/// and the flavor.
/// {@endtemplate}
class const AppInfo({
  /// `web`, `android` or `ios`.
  required final String platform,

  /// The `pubspec.yaml` version (`1.0.0`).
  required final String version,

  /// The build number (`3`).
  required final String build,

  /// `development` or `production`.
  required final String flavor,
}) extends Equatable {
  /// {@macro app_info}
  this;

  /// Reads the version and build of the running app. [isWeb], [platform]
  /// and [packageInfo] are the running app's unless a test passes them; a
  /// version that can't be read within [timeout] is `unknown`. Web fetches
  /// `version.json` for it, and the app waits for this before it starts.
  static Future<AppInfo> load({
    required String flavor,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
    Future<PackageInfo> Function() packageInfo = PackageInfo.fromPlatform,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    var version = 'unknown';
    var build = 'unknown';
    try {
      final info = await packageInfo().timeout(timeout);
      version = info.version;
      build = info.buildNumber;
    } on Object {
      // Web reads version.json; offline or missing, the report still goes.
    }
    return AppInfo(
      platform: isWeb
          ? 'web'
          : (platform ?? defaultTargetPlatform).name.toLowerCase(),
      version: version,
      build: build,
      flavor: flavor,
    );
  }

  @override
  List<Object?> get props => [platform, version, build, flavor];
}
