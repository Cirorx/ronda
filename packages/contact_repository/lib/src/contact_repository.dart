import 'package:contact_repository/contact_repository.dart';
import 'package:link_opener/link_opener.dart';

/// {@template contact_repository}
/// How a member reaches a person at Ronda or a helpline: it opens the
/// phone's mail app on a mail to [email], or its dialer on a [Helpline].
///
/// [email] is the one contact address, set at build time
/// (`RONDA_CONTACT_EMAIL`). Nothing is sent from here: the person sends the
/// mail or places the call in their own app.
/// {@endtemplate}
class ContactRepository {
  /// {@macro contact_repository}
  const new({required this._linkOpener, required this.email});

  final LinkOpener _linkOpener;

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
