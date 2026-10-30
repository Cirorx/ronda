import 'package:url_launcher/url_launcher.dart';

/// How [LinkOpener] hands a link to the platform: url_launcher's `launchUrl`
/// in the app, a stand-in in tests.
typedef LaunchLink = Future<bool> Function(Uri url, {LaunchMode mode});

/// {@template link_opener}
/// Hands a link (`mailto:`, `tel:`, `https:`) to the app the phone uses for
/// it: the mail app, the dialer, the browser.
///
/// It holds no domain logic and logs nothing.
/// {@endtemplate}
class LinkOpener {
  /// {@macro link_opener}
  new({LaunchLink? launch}) : _launch = launch ?? launchUrl;

  final LaunchLink _launch;

  /// Opens [uri] outside the app. Returns whether the platform found an
  /// app for it; throws whatever the platform throws.
  Future<bool> open(Uri uri) =>
      _launch(uri, mode: LaunchMode.externalApplication);
}
