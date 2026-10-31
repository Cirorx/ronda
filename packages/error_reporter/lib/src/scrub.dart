import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The longest scrubbed message kept, in characters.
const maxMessageLength = 300;

/// The longest scrubbed stack kept, in characters.
const maxStackLength = 4000;

/// The most stack frames kept.
const maxStackLines = 40;

/// The longest error code kept, in characters.
const maxCodeLength = 120;

final _urlQuery = RegExp(r'''(https?://[^\s?#'"]+)\?[^\s'"]*''');
final _email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
final _quoted = RegExp('"[^"\n]*"|\'[^\'\n]*\'|«[^»\n]*»|“[^”\n]*”');
// Firestore and Auth ids: 20+ letters and digits, at least one of each.
final _id = RegExp(
  r'(?<![A-Za-z0-9_-])(?=[A-Za-z0-9_-]*\d)(?=[A-Za-z0-9_-]*[A-Za-z])'
  '[A-Za-z0-9_-]{20,}',
);
// Phone numbers and other long numbers.
final _number = RegExp(r'\+?\d[\d ().-]{6,}\d');

/// [text] with URL queries, emails, quoted text, ids and long numbers
/// replaced by `?<query>`, `<email>`, `<text>`, `<id>` and `<number>`.
///
/// The same rules as `functions/client_errors.py`, which scrubs again on
/// the server. A quote is where free text people typed lands in an error
/// message; an id is where a uid lands (`users/<id>/private/eligible`).
String scrub(String text) => text
    .replaceAllMapped(_urlQuery, (match) => '${match[1]}?<query>')
    .replaceAll(_email, '<email>')
    .replaceAll(_quoted, '<text>')
    .replaceAll(_id, '<id>')
    .replaceAll(_number, '<number>');

/// The first line of [text] only, scrubbed and capped: a `FormatException`
/// prints the text it couldn't read on the lines after.
String scrubMessage(String text) =>
    _cap(scrub(text.trim().split('\n').first), maxMessageLength);

/// At most [maxStackLines] frames of [text], scrubbed and capped.
String scrubStack(String text) {
  if (text.trim().isEmpty) return '';
  final lines = text.trim().split('\n').take(maxStackLines).join('\n');
  return _cap(scrub(lines), maxStackLength);
}

/// [text] cut to [length] characters.
String capText(String text, int length) => _cap(text, length);

String _cap(String text, int length) =>
    text.length <= length ? text : text.substring(0, length);

/// The uid as error reports carry it: the first 16 hex characters of
/// SHA-256 over a fixed salt and the uid, the same as the server's
/// `client_errors.uid_hash`. It keeps raw uids out of error tools; the salt
/// is public, so it is a pseudonym, not anonymity.
String uidHash(String uid) => sha256
    .convert(utf8.encode('ronda-client-errors:$uid'))
    .toString()
    .substring(0, 16);
