import 'package:equatable/equatable.dart';

/// What about a person doesn't match a ronda. Never blocks adding them.
enum CandidateWarning {
  /// They didn't pick the ronda's day and time.
  slot,

  /// They didn't pick its pretext.
  pretext,

  /// They live more than the solver's ten blocks away.
  barrio,

  /// Their phone didn't mark its seat as one that works for them (which
  /// need, the server never knows).
  seat,
}

/// {@template ronda_candidates}
/// A ronda the admin may add someone to: who is in it now and who could
/// join it.
/// {@endtemplate}
class const RondaCandidates({
  /// The ronda's id.
  required final String rondaId,

  /// Its es-419 line ("Sábado a la tarde · mate en la rambla").
  required final String line,

  /// The first names of its members.
  required final List<String> members,

  /// Seats taken: active and paused members.
  required final int taken,

  /// The most its pretext allows.
  required final int cap,

  /// Who could join: those in no ronda first.
  required final List<Candidate> people,
}) extends Equatable {
  /// {@macro ronda_candidates}
  this;

  /// Whether no seat is left.
  bool get full => taken >= cap;

  @override
  List<Object?> get props => [rondaId, line, members, taken, cap, people];
}

/// {@template candidate}
/// A signed-up member the admin could add to a ronda.
/// {@endtemplate}
class const Candidate({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// Their age band id.
  required final String ageBandId,

  /// Their barrio id.
  required final String barrioId,

  /// The slot ids they picked.
  required final List<String> slotIds,

  /// What doesn't match the ronda.
  required final List<CandidateWarning> warnings,

  /// Blocks from their barrio to the ronda's; `null` when unknown.
  final int? blocks,

  /// The ronda they sit in now, if any: adding them moves them.
  final String? currentRondaId,

  /// That ronda's es-419 line.
  final String? currentRondaLine,
}) extends Equatable {
  /// {@macro candidate}
  this;

  @override
  List<Object?> get props => [
    uid,
    firstName,
    ageBandId,
    barrioId,
    slotIds,
    warnings,
    blocks,
    currentRondaId,
    currentRondaLine,
  ];
}

/// {@template added_to_ronda}
/// Someone the admin just added to a ronda.
/// {@endtemplate}
class const AddedToRonda({
  /// The ronda.
  required final String rondaId,

  /// Who joined.
  required final String uid,

  /// What doesn't match the ronda.
  required final List<CandidateWarning> warnings,

  /// The ronda they left, after a move.
  final String? movedFrom,
}) extends Equatable {
  /// {@macro added_to_ronda}
  this;

  @override
  List<Object?> get props => [rondaId, uid, warnings, movedFrom];
}
