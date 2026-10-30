import 'package:equatable/equatable.dart';

/// {@template ronda_setup}
/// One ronda on the admin's "Lugar, hora y anfitriones": what it is, its
/// public place, hour and hosts (each `null` until set), its members to
/// choose hosts from, and its latest roll.
///
/// Ids stay as stored (`mate`, `thu`, `afternoon`); the app reads them with
/// the profile's enums for their labels.
/// {@endtemplate}
class const RondaSetup({
  /// The ronda's id.
  required final String rondaId,

  /// The pretext id.
  required final String pretextId,

  /// The barrio id.
  required final String barrioId,

  /// The slot's weekday id (`thu`).
  required final String slotDayId,

  /// The slot's time band id (`afternoon`).
  required final String slotBandId,

  /// Its members, in first-name order.
  required final List<SetupMember> members,

  /// The hour it meets (`16:00`).
  final String? hour,

  /// The public place's name.
  final String? placeName,

  /// How to find the place.
  final String? placeLandmark,

  /// The anfitrión's uid.
  final String? anfitrionUid,

  /// The cola's uid.
  final String? colaUid,

  /// Its latest roll, once the attendance job wrote one.
  final RollSummary? roll,
}) extends Equatable {
  /// {@macro ronda_setup}
  this;

  @override
  List<Object?> get props => [
    rondaId,
    pretextId,
    barrioId,
    slotDayId,
    slotBandId,
    members,
    hour,
    placeName,
    placeLandmark,
    anfitrionUid,
    colaUid,
    roll,
  ];
}

/// {@template setup_member}
/// A member of a ronda by first name: on the admin's host pickers and on
/// the host's roll.
/// {@endtemplate}
class const SetupMember({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,
}) extends Equatable {
  /// {@macro setup_member}
  this;

  @override
  List<Object?> get props => [uid, firstName];
}

/// {@template roll_summary}
/// A ronda's latest roll on the admin's list: which meeting, and how many
/// of the people on it are marked.
/// {@endtemplate}
class const RollSummary({
  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (local, at midnight).
  required final DateTime date,

  /// How many are on it.
  required final int people,

  /// How many are marked.
  required final int marked,
}) extends Equatable {
  /// {@macro roll_summary}
  this;

  @override
  List<Object?> get props => [week, date, people, marked];
}

/// {@template attendance_roll}
/// "¿Quién vino hoy?": one meeting's roll for its host, with who is on it
/// and what the host marked. Nobody else reads it.
/// {@endtemplate}
class const AttendanceRoll({
  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (local, at midnight).
  required final DateTime date,

  /// The server's es-419 line for the meeting.
  required final String line,

  /// The members in for that meeting, in first-name order.
  required final List<SetupMember> people,

  /// Who came (`true`) and who didn't; unmarked people are absent.
  required final Map<String, bool> marks,
}) extends Equatable {
  /// {@macro attendance_roll}
  this;

  @override
  List<Object?> get props => [week, date, line, people, marks];
}
