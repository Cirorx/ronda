/// {@template cerca_document}
/// One `cerca/{barrio}` document, in its wire shape: Cerca tuyo's public
/// counts for a barrio (`functions/cerca_tuyo.py`). Counts only: no uid,
/// name or place is ever in it.
///
/// Only the demand is read here: how many neighbours wait, for each open
/// ronda's pretext and slot and for each pretext. The seats are not.
/// {@endtemplate}
class const CercaDocument({
  /// The barrio id, which is also the document id.
  required final String barrio,

  /// The open rondas' demand: each ronda's pretext and slot, and how many
  /// sign-ups wait for that pretext and slot.
  final List<CercaSlotWaiting> slotWaiting = const [],

  /// How many sign-ups in the barrio wait, by pretext.
  final List<CercaPretextWaiting> pretextWaiting = const [],
}) {
  /// {@macro cerca_document}
  this;

  /// Reads `cerca/{barrio}` from its [json] data. A row or a count without
  /// its shape is skipped: a count that can't be read is not shown.
  factory fromJson(String barrio, Map<String, Object?> json) => CercaDocument(
    barrio: barrio,
    slotWaiting: [
      if (json['rondas'] case final List<Object?> rows)
        for (final row in rows)
          if (row case {
            'pretext': final String pretext,
            'slot': final String slot,
            'waiting': final int count,
          })
            CercaSlotWaiting(pretext: pretext, slot: slot, count: count),
    ],
    pretextWaiting: [
      if (json['waiting'] case final List<Object?> counts)
        for (final entry in counts)
          if (entry case {
            'pretext': final String pretext,
            'count': final int count,
          })
            CercaPretextWaiting(pretext: pretext, count: count),
    ],
  );
}

/// {@template cerca_slot_waiting}
/// How many sign-ups wait for an open ronda's pretext and slot.
/// {@endtemplate}
class const CercaSlotWaiting({
  /// The pretext id (`mate`).
  required final String pretext,

  /// The slot id (`sat-afternoon`).
  required final String slot,

  /// How many wait.
  required final int count,
}) {
  /// {@macro cerca_slot_waiting}
  this;
}

/// {@template cerca_pretext_waiting}
/// How many sign-ups in a barrio wait for a ronda of one pretext.
/// {@endtemplate}
class const CercaPretextWaiting({
  /// The pretext id (`mate`).
  required final String pretext,

  /// How many wait.
  required final int count,
}) {
  /// {@macro cerca_pretext_waiting}
  this;
}
