/// {@template seguimos_document}
/// `rondas/{id}/seguimos/{uid}`: a member's own ¿seguimos? and what came of
/// it, as `functions/seguimos.py` writes it. Read by that member only: who
/// said what stays on the server.
/// {@endtemplate}
class const SeguimosDocument({
  /// `open` until the close, then `closed`.
  required final String status,

  /// `yes` or `no`; `null` while they haven't answered.
  final String? answer,

  /// Once closed: `season`, `gracias` (they said no) or `didntFill`.
  final String? outcome,

  /// Nearby rondas with places, after a no or below the floor.
  final List<NearbyRondaDocument> alternatives = const [],

  /// Below the floor, the yeses it needed.
  final int? floor,

  /// Below the floor, the last day to fill up while waiting (`2026-11-16`).
  final String? waitUntil,

  /// Below the floor, the day it would start after waiting (`2026-11-17`).
  final String? waitStart,

  /// Below the floor, `join` or `wait` once they chose.
  final String? choice,
}) {
  /// {@macro seguimos_document}
  this;

  /// Reads the document from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {'status': final String status}) {
      return SeguimosDocument(
        status: status,
        answer: _string(json['answer']),
        outcome: _string(json['outcome']),
        alternatives: switch (json['alternatives']) {
          final List<Object?> rows => [
            for (final row in rows) NearbyRondaDocument.fromJson(row),
          ],
          _ => const [],
        },
        floor: switch (json['floor']) {
          final int floor => floor,
          _ => null,
        },
        waitUntil: switch (json['wait']) {
          {'until': final String until} => until,
          _ => null,
        },
        waitStart: switch (json['wait']) {
          {'start': final String start} => start,
          _ => null,
        },
        choice: _string(json['choice']),
      );
    }
    throw const FormatException('a seguimos document has another shape');
  }
}

/// {@template nearby_ronda_document}
/// A nearby ronda with places, as the close offers it: its ids, places left
/// and next meeting. No name, place or member.
/// {@endtemplate}
class const NearbyRondaDocument({
  /// The ronda's id.
  required final String rondaId,

  /// The pretext id (`truco`).
  required final String pretext,

  /// The barrio id (`el-pinar-norte`).
  required final String barrio,

  /// The weekday id of its slot (`thu`).
  required final String slotDay,

  /// The time band id of its slot (`afternoon`).
  required final String slotBand,

  /// Places left.
  required final int placesLeft,

  /// Its next meeting (`2026-11-05`).
  required final String next,
}) {
  /// {@macro nearby_ronda_document}
  this;

  /// Reads one entry of `alternatives`.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'rondaId': final String rondaId,
      'pretext': final String pretext,
      'barrio': final String barrio,
      'slot': {'day': final String day, 'time': final String band},
      'placesLeft': final int placesLeft,
      'next': final String next,
    }) {
      return NearbyRondaDocument(
        rondaId: rondaId,
        pretext: pretext,
        barrio: barrio,
        slotDay: day,
        slotBand: band,
        placesLeft: placesLeft,
        next: next,
      );
    }
    throw const FormatException('an alternative has another shape');
  }
}

/// {@template seguimos_counts_document}
/// `seguimos_counts/{rondaId}`: what the admin sees of one ronda's
/// ¿seguimos?, counts only.
/// {@endtemplate}
class const SeguimosCountsDocument({
  /// The ronda's id.
  required final String rondaId,

  /// The ronda's line in es-419 ("Sábado a la tarde · mate en la rambla").
  required final String line,

  /// `open`, then `season` or `didntFill`.
  required final String status,

  /// Members asked.
  required final int asked,

  /// Yeses.
  required final int yes,

  /// Noes.
  required final int no,

  /// Asked and not answered.
  required final int unanswered,

  /// Below the floor, how many chose another ronda.
  final int join = 0,

  /// Below the floor, how many chose to wait.
  final int wait = 0,

  /// The season's last meeting (`2026-11-24`), once it started.
  final String? seasonEnd,
}) {
  /// {@macro seguimos_counts_document}
  this;

  /// Reads document [rondaId] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String rondaId, Map<String, Object?> json) {
    if (json case {
      'line': final String line,
      'status': final String status,
      'asked': final int asked,
      'yes': final int yes,
      'no': final int no,
      'unanswered': final int unanswered,
    }) {
      final choices = json['choices'];
      return SeguimosCountsDocument(
        rondaId: rondaId,
        line: line,
        status: status,
        asked: asked,
        yes: yes,
        no: no,
        unanswered: unanswered,
        join: switch (choices) {
          {'join': final int join} => join,
          _ => 0,
        },
        wait: switch (choices) {
          {'wait': final int wait} => wait,
          _ => 0,
        },
        seasonEnd: switch (json['season']) {
          {'end': final String end} => end,
          _ => null,
        },
      );
    }
    throw FormatException('seguimos_counts/$rondaId has another shape');
  }
}

String? _string(Object? value) => value is String ? value : null;
