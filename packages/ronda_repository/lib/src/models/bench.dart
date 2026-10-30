import 'package:equatable/equatable.dart';
import 'package:ronda_repository/src/models/seguimos.dart';

/// Where an offer of a freed seat stands for the person it went to.
enum BenchOfferStatus {
  /// Waiting for "Lo tomo" or "Esta vez no" until its deadline.
  pending,

  /// They took it: they go to that meeting.
  taken,

  /// It is over: they said "Esta vez no", the deadline passed, or the seat
  /// filled again. Nothing is held against anyone.
  over,
}

/// {@template bench_offer}
/// A seat an "esta no" freed, offered to this person from a ronda's bench:
/// the meeting, until when they may answer, and what came of it.
/// {@endtemplate}
class const BenchOffer({
  /// The offer's id, which the answer carries.
  required final String offerId,

  /// The ronda's id.
  required final String rondaId,

  /// The meeting's date (local, at midnight).
  required final DateTime date,

  /// The pretext id.
  required final String pretextId,

  /// The slot's weekday id.
  required final String slotDayId,

  /// The slot's time band id.
  required final String slotBandId,

  /// Until when they may answer.
  required final DateTime deadline,

  /// Where it stands.
  required final BenchOfferStatus status,

  /// The hour the ronda meets (`16:00`), once one is set.
  final String? hour,

  /// The public place's name, once one is set.
  final String? placeName,

  /// How to find the place, when there is one.
  final String? placeLandmark,
}) extends Equatable {
  /// {@macro bench_offer}
  this;

  @override
  List<Object?> get props => [
    offerId,
    rondaId,
    date,
    pretextId,
    slotDayId,
    slotBandId,
    deadline,
    status,
    hour,
    placeName,
    placeLandmark,
  ];
}

/// Where a person's waiting list stands.
enum WaitingStatus {
  /// Short of the threshold, before its deadline.
  open,

  /// At the threshold: the ronda is being put together.
  full,

  /// The last round ended short of the threshold: they pick how to go on.
  didntFill,

  /// After a round that didn't fill, they asked to join a nearby ronda.
  joined,
}

/// The person's pick after their waiting list didn't fill.
enum WaitlistChoice {
  /// "Sumarte a otro ya".
  join,

  /// "Esperar dos semanas más".
  wait,
}

/// {@template waiting}
/// A person's place on the waiting list nearest to filling: how many wait,
/// how many it takes, and the dates. Counts only: nobody else's name.
/// {@endtemplate}
class const Waiting({
  /// The list's pretext id.
  required final String pretextId,

  /// The list's barrio id.
  required final String barrioId,

  /// The list's slot weekday id.
  required final String slotDayId,

  /// The list's slot time band id.
  required final String slotBandId,

  /// How many wait, this person included.
  required final int count,

  /// How many it takes to start the ronda.
  required final int threshold,

  /// The round's last day.
  required final DateTime deadline,

  /// The day the ronda would start.
  required final DateTime start,

  /// Where it stands.
  required final WaitingStatus status,

  /// After a round that didn't fill, a nearby ronda with places.
  final NearbyRonda? nearby,

  /// Their pick, once made.
  final WaitlistChoice? choice,
}) extends Equatable {
  /// {@macro waiting}
  this;

  /// How many more it takes.
  int get missing => threshold - count < 0 ? 0 : threshold - count;

  @override
  List<Object?> get props => [
    pretextId,
    barrioId,
    slotDayId,
    slotBandId,
    count,
    threshold,
    deadline,
    start,
    status,
    nearby,
    choice,
  ];
}
