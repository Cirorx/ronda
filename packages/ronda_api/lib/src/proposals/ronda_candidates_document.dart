/// {@template ronda_candidates_document}
/// What `ronda_candidates` answers: a ronda, who is in it now, and who the
/// admin could add to it (`functions/ronda_members.py`).
/// {@endtemplate}
class const RondaCandidatesDocument({
  /// The ronda's id.
  required final String rondaId,

  /// The ronda's es-419 line ("Sábado a la tarde · mate en la rambla").
  required final String line,

  /// The first names of the members sitting in it.
  required final List<String> members,

  /// How many seats are taken: active and paused members.
  required final int taken,

  /// The most members its pretext allows.
  required final int cap,

  /// Who could be added: those in no ronda first.
  required final List<CandidateDocument> people,
}) {
  /// {@macro ronda_candidates_document}
  this;

  /// Reads the callable's answer.
  ///
  /// Throws a [FormatException] for any other shape.
  factory fromJson(Object? json) {
    if (json case {
      'rondaId': final String rondaId,
      'line': final String line,
      'members': final List<Object?> members,
      'taken': final int taken,
      'cap': final int cap,
      'people': final List<Object?> people,
    }) {
      return RondaCandidatesDocument(
        rondaId: rondaId,
        line: line,
        members: _strings(members),
        taken: taken,
        cap: cap,
        people: [
          for (final person in people) CandidateDocument.fromJson(person),
        ],
      );
    }
    throw _shape;
  }
}

/// {@template candidate_document}
/// One person the admin could add to a ronda, and what doesn't match it.
/// {@endtemplate}
class const CandidateDocument({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// Their age band id (`60-69`).
  required final String ageBand,

  /// Their barrio id.
  required final String barrio,

  /// The slot ids they picked.
  required final List<String> slots,

  /// The pretext ids they picked.
  required final List<String> pretexts,

  /// What doesn't match the ronda: `slot`, `pretext`, `barrio`, `seat`.
  required final List<String> warnings,

  /// Blocks from their barrio to the ronda's; `null` when unknown.
  final int? blocks,

  /// The ronda they sit in now, if any.
  final String? rondaId,

  /// That ronda's es-419 line.
  final String? rondaLine,
}) {
  /// {@macro candidate_document}
  this;

  /// Reads one entry of `people`.
  factory fromJson(Object? json) {
    if (json case {
      'uid': final String uid,
      'firstName': final String firstName,
      'ageBand': final String ageBand,
      'barrio': final String barrio,
      'slots': final List<Object?> slots,
      'pretexts': final List<Object?> pretexts,
      'warnings': final List<Object?> warnings,
      'blocks': final int? blocks,
      'rondaId': final String? rondaId,
      'rondaLine': final String? rondaLine,
    }) {
      return CandidateDocument(
        uid: uid,
        firstName: firstName,
        ageBand: ageBand,
        barrio: barrio,
        slots: _strings(slots),
        pretexts: _strings(pretexts),
        warnings: _strings(warnings),
        blocks: blocks,
        rondaId: rondaId,
        rondaLine: rondaLine,
      );
    }
    throw _shape;
  }
}

/// {@template add_to_ronda_document}
/// What `add_to_ronda` answers once the member is in.
/// {@endtemplate}
class const AddToRondaDocument({
  /// The ronda they joined.
  required final String rondaId,

  /// Who joined.
  required final String uid,

  /// What doesn't match the ronda, as in [CandidateDocument.warnings].
  required final List<String> warnings,

  /// The ronda they left, after a move.
  final String? movedFrom,
}) {
  /// {@macro add_to_ronda_document}
  this;

  /// Reads the callable's answer.
  factory fromJson(Object? json) {
    if (json case {
      'rondaId': final String rondaId,
      'uid': final String uid,
      'warnings': final List<Object?> warnings,
      'movedFrom': final String? movedFrom,
    }) {
      return AddToRondaDocument(
        rondaId: rondaId,
        uid: uid,
        warnings: _strings(warnings),
        movedFrom: movedFrom,
      );
    }
    throw _shape;
  }
}

List<String> _strings(List<Object?> values) => [
  for (final value in values)
    if (value is String) value else throw _shape,
];

const _shape = FormatException('not the shape ronda_members.py answers');
