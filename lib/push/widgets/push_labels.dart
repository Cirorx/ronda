import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';

/// The words for notifications where this browser can't get them.
extension PushLabels on AppLocalizations {
  /// Where notifications would work instead of here: the home screen on an
  /// iPhone, another browser or the app anywhere else.
  String pushUnsupported(PermissionPlace place) => switch (place) {
    PermissionPlace.iPhoneBrowser => pushUnsupportedIphone,
    PermissionPlace.app || PermissionPlace.browser => pushUnsupportedBrowser,
  };
}
