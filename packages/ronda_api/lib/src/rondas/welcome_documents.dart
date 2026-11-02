import 'package:ronda_api/src/rondas/hosts_documents.dart';

/// {@template welcome_document}
/// `rondas/{id}/welcomes/{newcomerUid}` (`functions/first_visit.py`): one
/// newcomer's first visit and who waits for them. The newcomer reads their
/// own; the ronda's anfitrión and cola read the ronda's; a waiter a host
/// picked reads the one they were picked for.
/// {@endtemplate}
class const WelcomeDocument({
  /// The newcomer's uid, the document's id.
  required final String newcomerUid,

  /// Their first name.
  required final String newcomerName,

  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (`2026-11-05`).
  required final String date,

  /// `open` while no host picked anyone, `set` once one did.
  required final String status,

  /// Who could wait: the members in for the meeting but the newcomer.
  required final List<SetupMemberDocument> choices,

  /// The meeting's hour (`16:00`), when it has one.
  final String? hour,

  /// Who a host picked to wait.
  final String? waiterUid,

  /// Their first name.
  final String? waiterName,

  /// How to recognise them ("tiene el termo verde").
  final String? sign,

  /// The host who picked.
  final String? setByUid,

  /// Their first name.
  final String? setByName,

  /// Who last said "No puedo", by first name.
  final String? declinedName,
}) {
  /// {@macro welcome_document}
  this;

  /// Reads the document [newcomerUid] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String newcomerUid, Map<String, Object?> json) {
    if (json case {
      'week': final String week,
      'date': final String date,
      'status': final String status,
      'newcomerName': final String newcomerName,
    }) {
      return WelcomeDocument(
        newcomerUid: newcomerUid,
        newcomerName: newcomerName,
        week: week,
        date: date,
        status: status,
        choices: switch (json['choices']) {
          final List<Object?> choices => [
            for (final choice in choices) SetupMemberDocument.fromJson(choice),
          ],
          _ => const [],
        },
        hour: _text(json['hour']),
        waiterUid: _text(json['waiterUid']),
        waiterName: _text(json['waiterName']),
        sign: _text(json['sign']),
        setByUid: _text(json['setBy']),
        setByName: _text(json['setByName']),
        declinedName: _text(json['declinedName']),
      );
    }
    throw FormatException('welcomes/$newcomerUid has another shape');
  }
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
