import 'package:equatable/equatable.dart';

/// A member's ¿seguimos? answer.
enum SeguimosAnswer {
  /// Sí.
  yes,

  /// No.
  no,
}

/// What came of ¿seguimos? for this member, once it closed.
enum SeguimosOutcome {
  /// The yeses reached the floor: the season started.
  season,

  /// They said no: "Gracias por venir.", with nearby rondas; their seat
  /// reopened.
  gracias,

  /// The yeses didn't reach the floor: the "didn't fill" choices.
  didntFill,
}

/// The member's pick after a close below the floor.
enum SeguimosChoice {
  /// "Sumarte a otro ya".
  join,

  /// "Esperar dos semanas más".
  wait,
}

/// {@template seguimos}
/// A member's own ¿seguimos? and what came of it: never anyone else's
/// answer, and no count.
/// {@endtemplate}
class const Seguimos({
  /// The ronda's id.
  required final String rondaId,

  /// The ronda's slot day id now (`tue`): the question names it.
  required final String slotDayId,

  /// Whether the question is still open (the answer can change).
  required final bool open,

  /// Their answer; `null` while they haven't answered.
  final SeguimosAnswer? myAnswer,

  /// Once closed, what came of it.
  final SeguimosOutcome? outcome,

  /// The season's last meeting, once it started.
  final DateTime? seasonEnd,

  /// Nearby rondas with places (after a no, or below the floor).
  final List<NearbyRonda> alternatives = const [],

  /// Below the floor, the yeses it needed.
  final int? floor,

  /// Below the floor, the last day to fill up while waiting.
  final DateTime? waitUntil,

  /// Below the floor, the day it would start after waiting.
  final DateTime? waitStart,

  /// Below the floor, their pick once made.
  final SeguimosChoice? choice,
}) extends Equatable {
  /// {@macro seguimos}
  this;

  @override
  List<Object?> get props => [
    rondaId,
    slotDayId,
    open,
    myAnswer,
    outcome,
    seasonEnd,
    alternatives,
    floor,
    waitUntil,
    waitStart,
    choice,
  ];
}

/// {@template nearby_ronda}
/// A ronda near this one with places: what it is, places left and its next
/// meeting. No name, place or member.
/// {@endtemplate}
class const NearbyRonda({
  /// Its id.
  required final String rondaId,

  /// Its pretext id.
  required final String pretextId,

  /// Its barrio id.
  required final String barrioId,

  /// Its slot's weekday id.
  required final String slotDayId,

  /// Its slot's time band id.
  required final String slotBandId,

  /// Places left.
  required final int placesLeft,

  /// Its next meeting.
  required final DateTime next,
}) extends Equatable {
  /// {@macro nearby_ronda}
  this;

  @override
  List<Object?> get props => [
    rondaId,
    pretextId,
    barrioId,
    slotDayId,
    slotBandId,
    placesLeft,
    next,
  ];
}

/// Where one ronda's ¿seguimos? stands, for the admin.
enum SeguimosStatus {
  /// Asked, closing with the next RSVP push.
  open,

  /// Closed with a season.
  season,

  /// Closed below the floor.
  didntFill,
}

/// {@template seguimos_counts}
/// One ronda's ¿seguimos? as the admin sees it: counts only, never who.
/// {@endtemplate}
class const SeguimosCounts({
  /// The ronda's id.
  required final String rondaId,

  /// The ronda's line, in Spanish as the server writes it.
  required final String line,

  /// Where it stands.
  required final SeguimosStatus status,

  /// Sí.
  required final int yes,

  /// No.
  required final int no,

  /// Sin contestar.
  required final int unanswered,

  /// Below the floor, how many want another ronda now.
  final int join = 0,

  /// Below the floor, how many wait two weeks.
  final int wait = 0,

  /// The season's last meeting, once it started.
  final DateTime? seasonEnd,
}) extends Equatable {
  /// {@macro seguimos_counts}
  this;

  @override
  List<Object?> get props => [
    rondaId,
    line,
    status,
    yes,
    no,
    unanswered,
    join,
    wait,
    seasonEnd,
  ];
}
