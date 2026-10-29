import 'package:equatable/equatable.dart';

/// A member's weekly answer ("voy" / "esta no").
enum RsvpAnswer {
  /// Voy.
  yes,

  /// Esta no. Nobody asks why.
  no,
}

/// {@template this_week}
/// A member's ronda and its upcoming meeting, as the Mi ronda card shows
/// it: what the ronda is, what they bring, their own answer, and "who's
/// coming" (the yeses by first name, only counts for the rest).
///
/// Ids stay as stored (`mate`, `sat`, `afternoon`, `pan`); the app reads them
/// with the profile's enums for their labels.
/// {@endtemplate}
class const ThisWeek({
  /// The ronda's id.
  required final String rondaId,

  /// The pretext id.
  required final String pretextId,

  /// The barrio id.
  required final String barrioId,

  /// The slot's weekday id (`sat`).
  required final String slotDayId,

  /// The slot's time band id (`afternoon`).
  required final String slotBandId,

  /// What this member brings, as ids.
  required final List<String> myBrings,

  /// The public place's name, once the host set one.
  final String? placeName,

  /// The upcoming meeting's ISO week (`2026-W44`); `null` until the server
  /// first writes the week's view.
  final String? week,

  /// The upcoming meeting's date (local, at midnight); `null` with [week].
  final DateTime? date,

  /// This member's answer for [week]; `null` while they haven't answered.
  final RsvpAnswer? myAnswer,

  /// While this member is paused, the first meeting they are back for.
  final DateTime? pausedUntil,

  /// Who said yes, in first-name order.
  final List<GoingNeighbour> going = const [],

  /// How many can't come; `null` with [week].
  final int? noCount,

  /// How many haven't answered; `null` with [week].
  final int? unansweredCount,
}) extends Equatable {
  /// {@macro this_week}
  this;

  @override
  List<Object?> get props => [
    rondaId,
    pretextId,
    barrioId,
    slotDayId,
    slotBandId,
    myBrings,
    placeName,
    week,
    date,
    myAnswer,
    pausedUntil,
    going,
    noCount,
    unansweredCount,
  ];
}

/// {@template going_neighbour}
/// A member who said yes this week: known by first name and what they bring.
/// {@endtemplate}
class const GoingNeighbour({
  /// Their uid, so the card can say "Vos".
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// What they bring, as ids.
  required final List<String> brings,
}) extends Equatable {
  /// {@macro going_neighbour}
  this;

  @override
  List<Object?> get props => [uid, firstName, brings];
}

/// {@template rsvp_push_result}
/// What "send the RSVP now" did, from the `rsvp_push` job's counts.
/// {@endtemplate}
class const RsvpPushResult({
  /// Rondas whose push went out now.
  required final int pushed,

  /// Messages FCM accepted.
  required final int messages,

  /// Rondas that already had this week's push.
  required final int already,

  /// Rondas held by the 21:00–09:00 gate.
  required final int held,
}) extends Equatable {
  /// {@macro rsvp_push_result}
  this;

  @override
  List<Object?> get props => [pushed, messages, already, held];
}
