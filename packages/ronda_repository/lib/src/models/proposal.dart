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

  /// Who it leaves without a seat, by name; empty on a proposal written
  /// before names were kept (then only [unseatedCount] says how many).
  final List<UnseatedPerson> unseated = const [],
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
    unseated,
  ];
}

/// {@template unseated_person}
/// Someone a [Proposal] leaves without a ronda: what the admin needs to
/// place them by hand.
/// {@endtemplate}
class const UnseatedPerson({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// Their barrio id.
  required final String barrioId,

  /// The slot ids they picked.
  required final List<String> slotIds,

  /// The pretext ids they picked.
  required final List<String> pretextIds,
}) extends Equatable {
  /// {@macro unseated_person}
  this;

  @override
  List<Object?> get props => [uid, firstName, barrioId, slotIds, pretextIds];
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

  /// The ronda it became once approved; `null` while pending.
  final String? rondaId,
}) extends Equatable {
  /// {@macro proposed_ronda}
  this;

  /// The walk the solver allows at most, in blocks.
  static const maxBlocks = 10;

  /// Whether every member lives within [maxBlocks] of the ronda's barrio.
  bool get allWithinTenBlocks =>
      members.every((member) => member.distanceBlocks <= maxBlocks);

  /// "Nadie es el único de su edad", for every [AgeGroup] the solver
  /// compares, in order, whether or not anyone of it is in the ronda.
  List<AgeGroupCheck> get ageChecks => [
    for (final group in AgeGroup.values)
      AgeGroupCheck(
        group: group,
        firstNames: [
          for (final member in members)
            if (AgeGroup.ofBand(member.ageBandId) == group) member.firstName,
        ],
      ),
  ];

  @override
  List<Object?> get props => [
    seatId,
    barrioId,
    pretextId,
    slotId,
    members,
    rondaId,
  ];
}

/// The age groups the solver keeps from being alone in a ronda
/// (`solver/ronda_solver/rules.py` `AGE_GROUPS`): people pick a decade, the
/// solver compares three groups.
enum AgeGroup {
  /// 18-29.
  under30,

  /// 30-39 to 50-59.
  from30To59,

  /// 60-69 and up.
  sixtyPlus;

  static const Map<String, AgeGroup> _bands = {
    '18-29': under30,
    '30-39': from30To59,
    '40-49': from30To59,
    '50-59': from30To59,
    '60-69': sixtyPlus,
    '70-79': sixtyPlus,
    '80+': sixtyPlus,
  };

  /// The group of age band [ageBandId]; `null` for a band outside them.
  static AgeGroup? ofBand(String ageBandId) => _bands[ageBandId];
}

/// {@template age_group_check}
/// One age group of a ronda: who is in it, and whether nobody is the only
/// one of their age.
/// {@endtemplate}
class const AgeGroupCheck({
  /// The group.
  required final AgeGroup group,

  /// The first names of the members in it.
  required final List<String> firstNames,
}) extends Equatable {
  /// {@macro age_group_check}
  this;

  /// How many members are in it.
  int get count => firstNames.length;

  /// Whether nobody is the only one of their age: none, or two or more.
  bool get kept => count != 1;

  @override
  List<Object?> get props => [group, firstNames];
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

  @override
  List<Object?> get props => [
    uid,
    firstName,
    ageBandId,
    distanceBlocks,
    plusOneInGroup,
  ];
}
