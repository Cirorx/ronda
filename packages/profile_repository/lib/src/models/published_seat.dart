import 'package:equatable/equatable.dart';

/// {@template published_seat}
/// What the server publishes about one seat, for the phone's needs filter:
/// how far it is from each barrio, and what the place and slot ask of
/// whoever takes it.
///
/// The phone turns it into a needs filter input; the needs themselves never
/// leave the device.
/// {@endtemplate}
class const PublishedSeat({
  /// The seat's id, `{barrio}_{pretext}_{slot}`.
  required final String seatId,

  /// Blocks from each barrio's centroid to the seat's barrio, by barrio id.
  required final Map<String, double> blocksFrom,

  /// Whether reaching the place means climbing stairs.
  required final bool hasStairs,

  /// Whether the slot ends after that week's sunset.
  required final bool endsAfterDark,

  /// Whether the place is hard to reach without a car.
  required final bool needsCar,
}) extends Equatable {
  /// {@macro published_seat}
  this;

  @override
  List<Object?> get props => [
    seatId,
    blocksFrom,
    hasStairs,
    endsAfterDark,
    needsCar,
  ];
}
