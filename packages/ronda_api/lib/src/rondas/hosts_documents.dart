/// {@template ronda_setup_document}
/// One ronda as the admin's `ronda_setups` callable returns it
/// (`functions/hosts.py`): what it is, its place, hour and hosts (each
/// `null` until set), its members by first name, and its latest roll.
/// {@endtemplate}
class const RondaSetupDocument({
  /// The ronda's id.
  required final String rondaId,

  /// The server's own es-419 line ("Jueves 16:00 · mate en la rambla").
  required final String line,

  /// The pretext id (`mate`).
  required final String pretext,

  /// The barrio id.
  required final String barrio,

  /// The weekday id of its slot (`thu`).
  required final String slotDay,

  /// The time band id of its slot (`afternoon`).
  required final String slotBand,

  /// Its members, in first-name order.
  required final List<SetupMemberDocument> members,

  /// The hour it meets (`16:00`).
  final String? hour,

  /// The public place's name.
  final String? placeName,

  /// How to find the place.
  final String? placeLandmark,

  /// The anfitrión's uid.
  final String? anfitrionUid,

  /// The cola's uid.
  final String? colaUid,

  /// Its latest attendance roll, if one was written.
  final RollSummaryDocument? roll,
}) {
  /// {@macro ronda_setup_document}
  this;

  /// Reads one row of the callable's `rondas`.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'rondaId': final String rondaId,
      'line': final String line,
      'pretext': final String pretext,
      'barrio': final String barrio,
      'slot': {'day': final String day, 'time': final String band},
      'members': final List<Object?> members,
    }) {
      final place = json['place'];
      final hosts = json['hosts'];
      return RondaSetupDocument(
        rondaId: rondaId,
        line: line,
        pretext: pretext,
        barrio: barrio,
        slotDay: day,
        slotBand: band,
        members: [
          for (final member in members) SetupMemberDocument.fromJson(member),
        ],
        hour: _text(json['hour']),
        placeName: place is Map ? _text(place['name']) : null,
        placeLandmark: place is Map ? _text(place['landmark']) : null,
        anfitrionUid: hosts is Map ? _text(hosts['anfitrion']) : null,
        colaUid: hosts is Map ? _text(hosts['cola']) : null,
        roll: switch (json['roll']) {
          null => null,
          final roll => RollSummaryDocument.fromJson(roll),
        },
      );
    }
    throw const FormatException('ronda_setups returned another shape');
  }
}

/// {@template setup_member_document}
/// A member of a ronda, as the admin chooses its hosts.
/// {@endtemplate}
class const SetupMemberDocument({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,
}) {
  /// {@macro setup_member_document}
  this;

  /// Reads one member of a row, or of a roll's `people`.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {'uid': final String uid, 'firstName': final String name}) {
      return SetupMemberDocument(uid: uid, firstName: name);
    }
    throw const FormatException('a member has another shape');
  }
}

/// {@template roll_summary_document}
/// A ronda's latest roll, as the admin's list shows it.
/// {@endtemplate}
class const RollSummaryDocument({
  /// The meeting's ISO week (`2026-W45`).
  required final String week,

  /// The meeting's date (`2026-11-05`).
  required final String date,

  /// How many are on it.
  required final int people,

  /// How many are marked.
  required final int marked,
}) {
  /// {@macro roll_summary_document}
  this;

  /// Reads a row's `roll`.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'week': final String week,
      'date': final String date,
      'people': final int people,
      'marked': final int marked,
    }) {
      return RollSummaryDocument(
        week: week,
        date: date,
        people: people,
        marked: marked,
      );
    }
    throw const FormatException('a roll summary has another shape');
  }
}

/// {@template roll_document}
/// `rondas/{id}/rolls/{isoWeek}`: the host's "¿Quién vino hoy?" for one
/// meeting (`functions/attendance.py`), read by the ronda's anfitrión and
/// cola and the admin: who is on it and the host's marks.
/// {@endtemplate}
class const RollDocument({
  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (`2026-11-05`).
  required final String date,

  /// The server's own es-419 line for the meeting.
  required final String line,

  /// The members in for that meeting, in first-name order.
  required final List<SetupMemberDocument> people,

  /// Who came (`true`) and who didn't, by uid; unmarked people are absent.
  required final Map<String, bool> marks,
}) {
  /// {@macro roll_document}
  this;

  /// Reads the roll from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'week': final String week,
      'date': final String date,
      'line': final String line,
      'people': final List<Object?> people,
      'marks': final Map<Object?, Object?> marks,
    }) {
      return RollDocument(
        week: week,
        date: date,
        line: line,
        people: [
          for (final person in people) SetupMemberDocument.fromJson(person),
        ],
        marks: {
          for (final MapEntry(:key, :value) in marks.entries)
            if ((key, value) case (final String uid, final bool came))
              uid: came,
        },
      );
    }
    throw const FormatException('a roll has another shape');
  }
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
