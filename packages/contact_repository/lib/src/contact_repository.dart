import 'package:contact_repository/contact_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:link_opener/link_opener.dart';

/// {@template contact_repository}
/// How a member reaches a person at Ronda or a helpline: it opens the
/// phone's mail app on a mail to [email], or its dialer on a [Helpline].
///
/// [email] is the one contact address, set at build time
/// (`RONDA_CONTACT_EMAIL`). Nothing is sent from here: the person sends the
/// mail or places the call in their own app.
///
/// For a buddy it opens WhatsApp with no number and no text (#9): they open
/// the chat they already have. Ronda never holds a phone number.
/// {@endtemplate}
class ContactRepository {
  /// {@macro contact_repository}
  const new({
    required this._linkOpener,
    required this.email,
    this._isWeb = kIsWeb,
  });

  final LinkOpener _linkOpener;
  final bool _isWeb;

  /// WhatsApp with no number and no text.
  static final Uri whatsApp = Uri.parse('whatsapp://send');

  /// Where members write to Ronda ("hola@ciroapps.com").
  final String email;

  /// Opens the mail app on a new mail to [email] with [subject], and [body]
  /// when given.
  ///
  /// Throws a [ContactFailure] when no mail app opens.
  Future<void> writeEmail({required String subject, String? body}) => _open(
    Uri(
      scheme: 'mailto',
      path: email,
      // Not queryParameters: mail apps show its "+" for spaces as is.
      query: [
        'subject=${Uri.encodeComponent(subject)}',
        if (body != null) 'body=${Uri.encodeComponent(body)}',
      ].join('&'),
    ),
  );

  /// Opens the dialer on [helpline]'s number.
  ///
  /// Throws a [ContactFailure] when no dialer opens.
  Future<void> callHelpline(Helpline helpline) =>
      _open(Uri(scheme: 'tel', path: helpline.number.replaceAll(' ', '')));

  /// Whether this phone has WhatsApp to open; never on web, where it can't
  /// be told.
  Future<bool> canOpenWhatsApp() async {
    if (_isWeb) return false;
    try {
      return await _linkOpener.canOpen(whatsApp);
    } on Exception {
      return false;
    }
  }

  /// Opens WhatsApp with no number and no text.
  ///
  /// Throws a [ContactFailure] when it doesn't open.
  Future<void> openWhatsApp() => _open(whatsApp);

  Future<void> _open(Uri uri) async {
    final bool opened;
    try {
      opened = await _linkOpener.open(uri);
    } on Exception {
      throw const ContactFailure();
    }
    if (!opened) throw const ContactFailure();
  }
}
