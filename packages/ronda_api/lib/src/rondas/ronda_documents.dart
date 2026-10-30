/// {@template ronda_document}
/// One `rondas/{id}` document, in its wire shape, as `approve_proposal`
/// writes it (`functions/proposals.py`) and the admin's `set_ronda_setup`
/// completes it (`functions/hosts.py`): only the fields a member's card
/// reads.
/// {@endtemplate}
class const RondaDocument({
  /// The document id.
  required final String id,

  /// The pretext id (`mate`).
  required final String pretext,

  /// The barrio id (`el-pinar-sur`).
  required final String barrio,

  /// The weekday id of its slot (`sat`).
  required final String slotDay,

  /// The time band id of its slot (`afternoon`).
  required final String slotBand,

  /// The public place's name, once the admin set one.
  final String? placeName,

  /// How to find the place ("al lado de la parada"), when the admin gave
  /// one.
  final String? placeLandmark,

  /// The hour the ronda meets (`16:00`), once the admin set one.
  final String? slotHour,

  /// The anfitrión's uid ("llega primero"), once the admin chose one.
  final String? anfitrionUid,

  /// The anfitrión's first name.
  final String? anfitrionName,

  /// The cola's uid ("se queda al final"), once the admin chose one.
  final String? colaUid,

  /// The cola's first name.
  final String? colaName,

  /// The season's first meeting (`2026-11-03`), once ¿seguimos? started one.
  final String? seasonStart,

  /// The season's last meeting (`2026-11-24`).
  final String? seasonEnd,
}) {
  /// {@macro ronda_document}
  this;

  /// Reads the document [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) {
    if (json case {
      'pretext': final String pretext,
      'barrio': final String barrio,
      'slot': {'day': final String day, 'time': final String band},
    }) {
      return RondaDocument(
        id: id,
        pretext: pretext,
        barrio: barrio,
        slotDay: day,
        slotBand: band,
        placeName: switch (json['place']) {
          {'name': final String name} when name.isNotEmpty => name,
          _ => null,
        },
        placeLandmark: switch (json['place']) {
          {'landmark': final String landmark} when landmark.isNotEmpty =>
            landmark,
          _ => null,
        },
        slotHour: switch (json['slot']) {
          {'hour': final String hour} => hour,
          _ => null,
        },
        anfitrionUid: _host(json, 'anfitrion'),
        anfitrionName: _host(json, 'anfitrionName'),
        colaUid: _host(json, 'cola'),
        colaName: _host(json, 'colaName'),
        seasonStart: switch (json['season']) {
          {'start': final String start} => start,
          _ => null,
        },
        seasonEnd: switch (json['season']) {
          {'end': final String end} => end,
          _ => null,
        },
      );
    }
    throw FormatException('rondas/$id has another shape');
  }
}

/// {@template member_document}
/// One `rondas/{id}/members/{uid}` document, in its wire shape.
/// {@endtemplate}
class const MemberDocument({
  /// What the member brings, as ids (`pan`).
  required final List<String> brings,

  /// `active`, `paused` or `left`.
  required final String state,

  /// While paused, the first meeting they are back for (`2026-11-14`).
  final String? pausedUntil,
}) {
  /// {@macro member_document}
  this;

  /// Reads a member document from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {'brings': final List<Object?> brings}) {
      return MemberDocument(
        brings: _ids(brings),
        state: switch (json['state']) {
          final String state => state,
          _ => 'active',
        },
        pausedUntil: switch (json['pausedUntil']) {
          final String until => until,
          _ => null,
        },
      );
    }
    throw const FormatException('a member document has another shape');
  }
}

/// {@template week_view_document}
/// `rondas/{id}/views/week`: "who's coming" to the ronda's upcoming
/// meeting, as the `answer_rsvp` callable and the RSVP job write it
/// (`functions/rsvp.py`). It carries the yeses' first names and only counts
/// for the rest: members never read the raw answers.
/// {@endtemplate}
class const WeekViewDocument({
  /// The meeting's ISO week (`2026-W44`).
  required final String week,

  /// The meeting's date (`2026-10-31`).
  required final String date,

  /// The members who said yes.
  required final List<GoingDocument> going,

  /// How many can't come this week.
  required final int noCount,

  /// How many haven't answered.
  required final int unansweredCount,
}) {
  /// {@macro week_view_document}
  this;

  /// Reads the view from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'week': final String week,
      'date': final String date,
      'going': final List<Object?> going,
      'noCount': final int noCount,
      'unansweredCount': final int unansweredCount,
    }) {
      return WeekViewDocument(
        week: week,
        date: date,
        going: [for (final person in going) GoingDocument.fromJson(person)],
        noCount: noCount,
        unansweredCount: unansweredCount,
      );
    }
    throw const FormatException('views/week has another shape');
  }
}

/// {@template going_document}
/// One member who said yes, in `views/week`.
/// {@endtemplate}
class const GoingDocument({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// What they bring, as ids.
  required final List<String> brings,
}) {
  /// {@macro going_document}
  this;

  /// Reads one entry of `going`.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'uid': final String uid,
      'firstName': final String firstName,
      'brings': final List<Object?> brings,
    }) {
      return GoingDocument(
        uid: uid,
        firstName: firstName,
        brings: _ids(brings),
      );
    }
    throw const FormatException('views/week has another shape');
  }
}

/// {@template answer_document}
/// `rondas/{id}/answers/{uid}`: the member's own last answer, readable by
/// that member only.
/// {@endtemplate}
class const AnswerDocument({
  /// The ISO week it answers (`2026-W44`).
  required final String week,

  /// `yes` or `no`.
  required final String answer,
}) {
  /// {@macro answer_document}
  this;

  /// Reads the answer from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {'week': final String week, 'answer': final String answer}) {
      return AnswerDocument(week: week, answer: answer);
    }
    throw const FormatException('an answer document has another shape');
  }
}

String? _host(Map<String, Object?> json, String key) => switch (json['hosts']) {
  final Map<Object?, Object?> hosts => switch (hosts[key]) {
    final String value when value.isNotEmpty => value,
    _ => null,
  },
  _ => null,
};

List<String> _ids(List<Object?> values) {
  if (values.any((value) => value is! String)) {
    throw const FormatException('a list of ids holds something else');
  }
  return values.cast<String>().toList();
}
