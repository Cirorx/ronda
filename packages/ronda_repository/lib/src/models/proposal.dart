import 'package:equatable/equatable.dart';

/// Where a proposal stands.
enum ProposalStatus {
  /// Waiting for the admin: nobody has been told anything.
  pending,

  /// Approved: its rondas exist.
  approved,
}

/// {@template proposal}
/// The solver's grouping of the current sign-ups, waiting for the admin's
/// approval, with why the next-best grouping lost.
/// {@endtemplate}
class const Proposal({
  /// The proposal's id.
  required final String id,

  /// Pending or approved.
  required final ProposalStatus status,

  /// The rondas it would open.
  required final List<ProposedRonda> rondas,

  /// How many signed-up people it leaves without a seat.
  required final int unseatedCount,

  /// When the solver ran.
  required final DateTime createdAt,

  /// Why the next-best grouping lost, as the solver's es-419 sentence
  /// ("Alternativa B rechazada: …"); `null` when nobody could be seated.
  final String? rejectedReason,
}) extends Equatable {
  /// {@macro proposal}
  this;

  @override
  List<Object?> get props => [
    id,
    status,
    rondas,
    unseatedCount,
    createdAt,
    rejectedReason,
  ];
}

/// {@template proposed_ronda}
/// One ronda of a [Proposal]: a barrio × pretext × slot and who is in it.
///
/// Ids stay as stored (`lagomar-sur`, `mate`, `sat-afternoon`); the app
/// reads them with the profile's enums for their labels.
/// {@endtemplate}
class const ProposedRonda({
  /// The seat id, `{barrio}_{pretext}_{slot}`.
  required final String seatId,

  /// The barrio id.
  required final String barrioId,

  /// The pretext id.
  required final String pretextId,

  /// The slot id.
  required final String slotId,

  /// Its members.
  required final List<ProposedMember> members,
}) extends Equatable {
  /// {@macro proposed_ronda}
  this;

  /// The walk the solver allows at most, in blocks.
  static const maxBlocks = 10;

  /// Whether every member lives within [maxBlocks] of the ronda's barrio.
  bool get allWithinTenBlocks =>
      members.every((member) => member.distanceBlocks <= maxBlocks);

  /// How many members are 60 or older.
  int get sixtyPlusCount => members.where((m) => m.isSixtyPlus).length;

  @override
  List<Object?> get props => [seatId, barrioId, pretextId, slotId, members];
}

/// {@template proposed_member}
/// One member of a [ProposedRonda]: what the admin sees, never more.
/// {@endtemplate}
class const ProposedMember({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// Their age band id (`60-69`).
  required final String ageBandId,

  /// Blocks between their barrio and the ronda's.
  required final double distanceBlocks,

  /// Whether their +1 is in the same ronda; `null` when they bring no +1
  /// who signed up.
  final bool? plusOneInGroup,
}) extends Equatable {
  /// {@macro proposed_member}
  this;

  static const _sixtyPlusBands = {'60-69', '70-79', '80+'};

  /// Whether they are 60 or older ("Hay al menos dos de 60 o más").
  bool get isSixtyPlus => _sixtyPlusBands.contains(ageBandId);

  @override
  List<Object?> get props => [
    uid,
    firstName,
    ageBandId,
    distanceBlocks,
    plusOneInGroup,
  ];
}
