import 'package:url_launcher/url_launcher.dart';

/// How [LinkOpener] hands a link to the platform: url_launcher's `launchUrl`
/// in the app, a stand-in in tests.
typedef LaunchLink = Future<bool> Function(Uri url, {LaunchMode mode});

/// How [LinkOpener] asks whether an app takes a link: url_launcher's
/// `canLaunchUrl` in the app, a stand-in in tests.
typedef CanLaunchLink = Future<bool> Function(Uri url);

/// {@template link_opener}
/// Hands a link (`mailto:`, `tel:`, `https:`, `whatsapp:`) to the app the
/// phone uses for it: the mail app, the dialer, the browser, WhatsApp.
///
/// It holds no domain logic and logs nothing.
/// {@endtemplate}
class LinkOpener {
  /// {@macro link_opener}
  new({LaunchLink? launch, CanLaunchLink? canLaunch})
    : _launch = launch ?? launchUrl,
      _canLaunch = canLaunch ?? canLaunchUrl;

  final LaunchLink _launch;
  final CanLaunchLink _canLaunch;

  /// Whether an app on the phone takes [uri]. On Android it only knows the
  /// schemes the manifest's `<queries>` names.
  Future<bool> canOpen(Uri uri) => _canLaunch(uri);

  /// Opens [uri] outside the app. Returns whether the platform found an
  /// app for it; throws whatever the platform throws.
  Future<bool> open(Uri uri) =>
      _launch(uri, mode: LaunchMode.externalApplication);
}
