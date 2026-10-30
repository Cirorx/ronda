import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ronda_api/src/rondas/seguimos_documents.dart';

/// {@template bench_offer_document}
/// `users/{uid}/offers/{offerId}`: a seat an "esta no" freed, offered to
/// this person from the bench, as `functions/bench.py` writes it. Read by
/// that person only.
/// {@endtemplate}
class const BenchOfferDocument({
  /// The document id (`{rondaId}_{isoWeek}_{n}`).
  required final String id,

  /// The ronda's id.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,

  /// The meeting's date (`2026-11-05`).
  required final String date,

  /// The pretext id (`mate`).
  required final String pretext,

  /// The slot's weekday id (`thu`).
  required final String slotDay,

  /// The slot's time band id (`afternoon`).
  required final String slotBand,

  /// Until when the person may answer.
  required final DateTime deadline,

  /// `pending`, `taken`, `declined`, `expired` or `withdrawn`.
  required final String status,

  /// The hour the ronda meets (`16:00`), once one is set.
  final String? hour,

  /// The public place's name, once one is set.
  final String? placeName,

  /// How to find the place, when there is one.
  final String? placeLandmark,
}) {
  /// {@macro bench_offer_document}
  this;

  /// Reads offer [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) {
    if (json case {
      'rondaId': final String rondaId,
      'week': final String week,
      'date': final String date,
      'pretext': final String pretext,
      'slot': {'day': final String day, 'time': final String band},
      'deadline': final Timestamp deadline,
      'status': final String status,
    }) {
      return BenchOfferDocument(
        id: id,
        rondaId: rondaId,
        week: week,
        date: date,
        pretext: pretext,
        slotDay: day,
        slotBand: band,
        deadline: deadline.toDate(),
        status: status,
        hour: _string(json['hour']),
        placeName: _string(json['placeName']),
        placeLandmark: _string(json['placeLandmark']),
      );
    }
    throw FormatException('offer $id has another shape');
  }
}

/// {@template waiting_document}
/// `waiting/{uid}`: the person's place on the waiting list nearest to
/// filling, as `functions/waitlists.py` writes it. Counts and dates only;
/// read by that person only.
/// {@endtemplate}
class const WaitingDocument({
  /// The list's seat id (`el-pinar-sur_mate_sat-afternoon`).
  required final String seatId,

  /// The barrio id.
  required final String barrio,

  /// The pretext id.
  required final String pretext,

  /// The slot id (`sat-afternoon`).
  required final String slot,

  /// How many wait on the list, this person included.
  required final int count,

  /// How many it takes to start the ronda.
  required final int threshold,

  /// The round's last day (`2026-11-01`).
  required final String deadline,

  /// The day the ronda would start (`2026-11-07`).
  required final String start,

  /// `open`, `full`, `didntFill` or `joined`.
  required final String status,

  /// After a round that didn't fill, a nearby ronda with places.
  final List<NearbyRondaDocument> alternatives = const [],

  /// The person's pick after a round that didn't fill (`join` or `wait`).
  final String? choice,
}) {
  /// {@macro waiting_document}
  this;

  /// Reads the card from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'seatId': final String seatId,
      'barrio': final String barrio,
      'pretext': final String pretext,
      'slot': final String slot,
      'count': final int count,
      'threshold': final int threshold,
      'deadline': final String deadline,
      'start': final String start,
      'status': final String status,
    }) {
      return WaitingDocument(
        seatId: seatId,
        barrio: barrio,
        pretext: pretext,
        slot: slot,
        count: count,
        threshold: threshold,
        deadline: deadline,
        start: start,
        status: status,
        alternatives: switch (json['alternatives']) {
          final List<Object?> rows => [
            for (final row in rows) NearbyRondaDocument.fromJson(row),
          ],
          _ => const [],
        },
        choice: _string(json['choice']),
      );
    }
    throw const FormatException('a waiting card has another shape');
  }
}

String? _string(Object? value) => value is String ? value : null;
