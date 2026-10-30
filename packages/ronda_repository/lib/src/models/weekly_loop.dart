import 'package:equatable/equatable.dart';
import 'package:ronda_repository/src/models/hosts.dart';
import 'package:ronda_repository/src/models/this_week.dart';

/// {@template host_turn}
/// One month's turn: who opens and who closes ("Este mes abre Jorge y
/// cierra Ana").
/// {@endtemplate}
class const HostTurn({
  /// The month's first day (local, at midnight).
  required final DateTime month,

  /// Who opens that month.
  required final Host anfitrion,

  /// Who closes that month.
  required final Host cola,
}) extends Equatable {
  /// {@macro host_turn}
  this;

  @override
  List<Object?> get props => [month, anfitrion, cola];
}

/// What a después is.
enum DespuesKind {
  /// "Esta semana no".
  none,

  /// A public place nearby.
  place,

  /// Someone's home ("En lo de alguien del grupo").
  home,
}

/// Where a después stands.
enum DespuesStatus {
  /// Members see it.
  set,

  /// Waiting for the yes of whose home it is.
  asking,

  /// Whose home it is said no; the address is gone.
  declined,
}

/// {@template despues}
/// One meeting's después: an optional 20-minute after-spot. Members see it
/// once it is [DespuesStatus.set]; whoever set it and whose home it is see
/// it while it waits.
/// {@endtemplate}
class const Despues({
  /// What it is.
  required final DespuesKind kind,

  /// Where it stands.
  required final DespuesStatus status,

  /// Who set it.
  required final Host setBy,

  /// What there is ("bizcochos").
  final String? what,

  /// The public place, for [DespuesKind.place].
  final String? where,

  /// Whose home it is, for [DespuesKind.home].
  final Host? homeOf,

  /// The home's address, until the day ends.
  final String? address,
}) extends Equatable {
  /// {@macro despues}
  this;

  @override
  List<Object?> get props => [
    kind,
    status,
    setBy,
    what,
    where,
    homeOf,
    address,
  ];
}

/// Why the anfitrión won't open, as the cola is told.
enum HandoffReason {
  /// They said "esta no".
  no,

  /// They are paused, or left the ronda.
  away,

  /// They haven't answered by noon the day before.
  unanswered,
}

/// {@template handoff_ask}
/// "¿Abrís vos?" for one meeting, while it is open to this member. The cola
/// is told who can't ([fromName], [reason]); the others are told nobody
/// opens yet.
/// {@endtemplate}
class const HandoffAsk({
  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (local, at midnight).
  required final DateTime date,

  /// The meeting's hour (`16:00`), when it has one.
  final String? hour,

  /// The anfitrión's first name, for the cola.
  final String? fromName,

  /// Why the anfitrión can't, for the cola.
  final HandoffReason? reason,
}) extends Equatable {
  /// {@macro handoff_ask}
  this;

  @override
  List<Object?> get props => [week, date, hour, fromName, reason];
}

/// {@template buddy_miss}
/// Someone who chose this member and missed a week without saying so: only
/// their first name and the weekday.
/// {@endtemplate}
class const BuddyMiss({
  /// Their first name.
  required final String firstName,

  /// The weekday id of the meeting (`thu`).
  required final String dayId,
}) extends Equatable {
  /// {@macro buddy_miss}
  this;

  @override
  List<Object?> get props => [firstName, dayId];
}

/// {@template buddy_ask}
/// A buddy's open card: who missed, in ronda [rondaId].
/// {@endtemplate}
class const BuddyAsk({
  /// The ronda.
  required final String rondaId,

  /// Each miss, oldest first.
  required final List<BuddyMiss> misses,
}) extends Equatable {
  /// {@macro buddy_ask}
  this;

  @override
  List<Object?> get props => [rondaId, misses];
}

/// {@template buddy_options}
/// Whether it is time to choose a buddy, who could be chosen, and who is.
/// {@endtemplate}
class const BuddyOptions({
  /// A meeting has passed since the member joined.
  required final bool due,

  /// They chose someone, or nobody.
  required final bool chosen,

  /// The other members, in first-name order.
  required final List<SetupMember> choices,

  /// Who they chose, while still in the ronda.
  final SetupMember? buddy,
}) extends Equatable {
  /// {@macro buddy_options}
  this;

  @override
  List<Object?> get props => [due, chosen, choices, buddy];
}

/// How a meeting's "¿Abrís vos?" is going.
enum HandoffStep {
  /// The cola is asked.
  cola,

  /// The other members are asked.
  members,

  /// Someone opens it.
  taken,

  /// Nobody said yes: the admin's call.
  nobody,

  /// The anfitrión said "voy" after all.
  back,
}

/// {@template handoff_summary}
/// The upcoming meeting's "¿Abrís vos?" on the admin's list.
/// {@endtemplate}
class const HandoffSummary({
  /// The meeting's date (local, at midnight).
  required final DateTime date,

  /// How it is going.
  required final HandoffStep step,

  /// The anfitrión's first name.
  required final String fromName,

  /// Who opens instead, once someone does.
  final String? takenName,
}) extends Equatable {
  /// {@macro handoff_summary}
  this;

  @override
  List<Object?> get props => [date, step, fromName, takenName];
}
