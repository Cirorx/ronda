import 'package:equatable/equatable.dart';
import 'package:needs_repository/src/models/walk_distance.dart';

/// {@template seat_facts}
/// What a seat asks of the member who takes it, as computed upstream for one
/// week. Needs are matched against these facts on the phone.
/// {@endtemplate}
class const SeatFacts({
  /// The seat's id, the only thing the server gets back.
  required final String seatId,

  /// How far the meeting place is from the member's barrio.
  required final WalkDistance walkDistance,

  /// Whether reaching the place means climbing stairs.
  required final bool hasStairs,

  /// Whether the meeting ends after that day's sunset.
  required final bool endsAfterDark,

  /// Whether the place is hard to reach without a car.
  required final bool needsCar,
}) extends Equatable {
  /// {@macro seat_facts}
  this;

  @override
  List<Object?> get props => [
    seatId,
    walkDistance,
    hasStairs,
    endsAfterDark,
    needsCar,
  ];
}
