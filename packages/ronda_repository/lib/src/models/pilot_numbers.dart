import 'package:equatable/equatable.dart';

/// {@template count_of}
/// "x of y".
/// {@endtemplate}
class const CountOf(final int count, final int of) extends Equatable {
  /// {@macro count_of}
  this;

  @override
  List<Object?> get props => [count, of];
}

/// {@template pilot_numbers}
/// The pilot's numbers for the admin, invented sign-ups left out on the
/// real project. Counts only.
/// {@endtemplate}
class const PilotNumbers({
  /// Sign-ups who saved a profile, of everyone who accepted the terms.
  required final CountOf profiles,

  /// Of those with a profile, how many sit in a ronda.
  required final CountOf seated,

  /// Each ronda with a member who counts.
  required final List<PilotRonda> rondas,

  /// Came back, over every ronda; `null` until a ronda marked two
  /// meetings.
  final CountOf? cameBack,
}) extends Equatable {
  /// {@macro pilot_numbers}
  this;

  @override
  List<Object?> get props => [profiles, seated, rondas, cameBack];
}

/// {@template pilot_ronda}
/// One ronda's numbers.
/// {@endtemplate}
class const PilotRonda({
  /// The ronda's id.
  required final String rondaId,

  /// Its es-419 line.
  required final String line,

  /// Members sitting in it, of its cap.
  required final CountOf members,

  /// Each week, by week id.
  required final List<PilotWeek> weeks,

  /// Of who came to its first marked meeting, how many came to the next.
  final CountOf? cameBack,

  /// Its ¿seguimos?, once asked.
  final PilotSeguimos? seguimos,
}) extends Equatable {
  /// {@macro pilot_ronda}
  this;

  @override
  List<Object?> get props => [
    rondaId,
    line,
    members,
    weeks,
    cameBack,
    seguimos,
  ];
}

/// {@template pilot_week}
/// One week of one ronda: the RSVP of that week's members, and who came.
/// {@endtemplate}
class const PilotWeek({
  /// The ISO week (`2026-W45`).
  required final String week,

  /// Said voy, of the members that week.
  required final CountOf yes,

  /// Can't.
  required final int no,

  /// Didn't answer.
  required final int unanswered,

  /// The meeting's date, when known.
  final DateTime? date,

  /// Came, of those the host marked; `null` while unmarked.
  final CountOf? came,
}) extends Equatable {
  /// {@macro pilot_week}
  this;

  @override
  List<Object?> get props => [week, yes, no, unanswered, date, came];
}

/// {@template pilot_seguimos}
/// A ronda's ¿seguimos? counts: sí, no and sin contestar of those asked.
/// {@endtemplate}
class const PilotSeguimos({
  /// Said sí, of those asked.
  required final CountOf yes,

  /// Said no.
  required final int no,

  /// Haven't answered.
  required final int unanswered,
}) extends Equatable {
  /// {@macro pilot_seguimos}
  this;

  @override
  List<Object?> get props => [yes, no, unanswered];
}
