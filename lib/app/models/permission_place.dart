import 'package:flutter/foundation.dart';

/// Where Ronda runs, as far as a permission goes: who asks for it, and
/// where the person turns it back on.
enum PermissionPlace {
  /// The app on a phone: the phone's own settings.
  app,

  /// A browser on a computer or an Android phone: the padlock by the
  /// address.
  browser,

  /// A browser on an iPhone (Safari, or Chrome on WebKit): the iPhone's
  /// Ajustes, per browser, and no notifications outside the home screen.
  iPhoneBrowser;

  /// Where this app instance runs.
  static PermissionPlace get current =>
      of(web: kIsWeb, platform: defaultTargetPlatform);

  /// The place for [web] on [platform]; Flutter's web build reads an iPhone
  /// or iPad from the browser as [TargetPlatform.iOS].
  static PermissionPlace of({
    required bool web,
    required TargetPlatform platform,
  }) => switch ((web, platform)) {
    (false, _) => app,
    (true, TargetPlatform.iOS) => iPhoneBrowser,
    (true, _) => browser,
  };
}
