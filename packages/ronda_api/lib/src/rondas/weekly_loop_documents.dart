import 'package:ronda_api/src/rondas/hosts_documents.dart';

/// {@template host_turn_document}
/// One month's turn on `rondas/{id}.turns` (`functions/rotation.py`): who
/// opens and who closes that month, by uid and first name.
/// {@endtemplate}
class const HostTurnDocument({
  /// The month (`2026-11`).
  required final String month,

  /// Who opens.
  required final String anfitrionUid,

  /// Their first name.
  required final String anfitrionName,

  /// Who closes.
  required final String colaUid,

  /// Their first name.
  required final String colaName,
}) {
  /// {@macro host_turn_document}
  this;

  /// Reads one turn.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'month': final String month,
      'anfitrion': final String anfitrionUid,
      'anfitrionName': final String anfitrionName,
      'cola': final String colaUid,
      'colaName': final String colaName,
    }) {
      return HostTurnDocument(
        month: month,
        anfitrionUid: anfitrionUid,
        anfitrionName: anfitrionName,
        colaUid: colaUid,
        colaName: colaName,
      );
    }
    throw const FormatException('a turn has another shape');
  }
}

/// {@template despues_document}
/// `rondas/{id}/despues/{isoWeek}` (`functions/despues.py`): one meeting's
/// después. The rules let the ronda's members read it once it is `set`, and
/// whoever set it and whose home it is at any time.
/// {@endtemplate}
class const DespuesDocument({
  /// The meeting's ISO week.
  required final String week,

  /// `none`, `place` or `home`.
  required final String kind,

  /// `set`, `asking` (waiting for the yes of whose home it is) or
  /// `declined`.
  required final String status,

  /// Who set it.
  required final String setByUid,

  /// Their first name.
  required final String setByName,

  /// What there is ("bizcochos").
  final String? what,

  /// The public place, for `place`.
  final String? where,

  /// Whose home it is, for `home`.
  final String? homeOfUid,

  /// Their first name.
  final String? homeName,

  /// The home's address, until the day ends.
  final String? address,
}) {
  /// {@macro despues_document}
  this;

  /// Reads the después from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'week': final String week,
      'kind': final String kind,
      'status': final String status,
      'setBy': final String setByUid,
      'setByName': final String setByName,
    }) {
      return DespuesDocument(
        week: week,
        kind: kind,
        status: status,
        setByUid: setByUid,
        setByName: setByName,
        what: _text(json['what']),
        where: _text(json['where']),
        homeOfUid: _text(json['homeOf']),
        homeName: _text(json['homeName']),
        address: _text(json['address']),
      );
    }
    throw const FormatException('a después has another shape');
  }
}

/// {@template handoff_ask_document}
/// `rondas/{id}/handoff_asks/{uid}` (`functions/handoff.py`): a member's
/// own "¿Abrís vos?", read by that member only.
/// {@endtemplate}
class const HandoffAskDocument({
  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (`2026-11-05`).
  required final String date,

  /// `open`, `taken` (they open it) or `closed`.
  required final String status,

  /// The anfitrión's first name, for the cola; empty for the others.
  required final String fromName,

  /// Why the anfitrión can't (`no`, `away`, `unanswered`), for the cola;
  /// empty for the others.
  required final String reason,

  /// The meeting's hour (`16:00`), when it has one.
  final String? hour,
}) {
  /// {@macro handoff_ask_document}
  this;

  /// Reads the question from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'week': final String week,
      'date': final String date,
      'status': final String status,
    }) {
      return HandoffAskDocument(
        week: week,
        date: date,
        status: status,
        fromName: _text(json['fromName']) ?? '',
        reason: _text(json['reason']) ?? '',
        hour: _text(json['hour']),
      );
    }
    throw const FormatException('an "¿Abrís vos?" has another shape');
  }
}

/// {@template buddy_ask_document}
/// `rondas/{id}/buddy_asks/{uid}` (`functions/buddy.py`): who missed a
/// week and chose this member to hear about it, read by this member only.
/// {@endtemplate}
class const BuddyAskDocument({
  /// `open` until the buddy closes it.
  required final String status,

  /// Each miss, oldest first.
  required final List<BuddyMissDocument> asks,
}) {
  /// {@macro buddy_ask_document}
  this;

  /// Reads the card from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'status': final String status,
      'asks': final List<Object?> asks,
    }) {
      return BuddyAskDocument(
        status: status,
        asks: [for (final ask in asks) BuddyMissDocument.fromJson(ask)],
      );
    }
    throw const FormatException('a buddy card has another shape');
  }
}

/// {@template buddy_miss_document}
/// One miss on a buddy's card: only a first name and the weekday.
/// {@endtemplate}
class const BuddyMissDocument({
  /// Who missed, by first name.
  required final String firstName,

  /// The weekday id of the meeting they missed (`thu`).
  required final String day,
}) {
  /// {@macro buddy_miss_document}
  this;

  /// Reads one entry of `asks`.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {'firstName': final String name, 'day': final String day}) {
      return BuddyMissDocument(firstName: name, day: day);
    }
    throw const FormatException('a miss has another shape');
  }
}

/// {@template buddy_options_document}
/// What the `buddy_options` callable answers: whether it is time to choose,
/// whether the member chose (someone or nobody), who, and the other
/// members by first name.
/// {@endtemplate}
class const BuddyOptionsDocument({
  /// A meeting of the ronda has passed since the member joined.
  required final bool due,

  /// They chose someone, or nobody.
  required final bool chosen,

  /// The other members, in first-name order.
  required final List<SetupMemberDocument> choices,

  /// Who they chose, while still in the ronda.
  final String? buddyUid,

  /// Their first name.
  final String? buddyName,
}) {
  /// {@macro buddy_options_document}
  this;

  /// Reads the callable's answer.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'due': final bool due,
      'chosen': final bool chosen,
      'choices': final List<Object?> choices,
    }) {
      return BuddyOptionsDocument(
        due: due,
        chosen: chosen,
        choices: [
          for (final choice in choices) SetupMemberDocument.fromJson(choice),
        ],
        buddyUid: _text(json['buddyUid']),
        buddyName: _text(json['buddyName']),
      );
    }
    throw const FormatException('buddy_options returned another shape');
  }
}

/// {@template handoff_summary_document}
/// The upcoming meeting's "¿Abrís vos?" on the admin's `ronda_setups` row.
/// {@endtemplate}
class const HandoffSummaryDocument({
  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (`2026-11-05`).
  required final String date,

  /// `cola`, `members`, `taken`, `nobody` or `back`.
  required final String step,

  /// The anfitrión's first name.
  required final String fromName,

  /// Who opens instead, once someone does.
  final String? takenName,
}) {
  /// {@macro handoff_summary_document}
  this;

  /// Reads a row's `handoff`.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'week': final String week,
      'date': final String date,
      'step': final String step,
      'fromName': final String fromName,
    }) {
      return HandoffSummaryDocument(
        week: week,
        date: date,
        step: step,
        fromName: fromName,
        takenName: _text(json['takenName']),
      );
    }
    throw const FormatException('a handoff summary has another shape');
  }
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
