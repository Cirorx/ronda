import 'package:equatable/equatable.dart';

/// {@template cerca}
/// Cerca tuyo's demand in one barrio: how many neighbours signed up and wait
/// for a ronda. Counts only: no name, place or seat.
///
/// Ids stay as stored (`mate`, `sat-afternoon`); the app reads them with the
/// profile's enums for their labels.
/// {@endtemplate}
class const Cerca({
  /// The barrio id.
  required final String barrioId,

  /// How many wait for a pretext at a slot. Only the pretexts and slots an
  /// open ronda has carry a slot count.
  final List<CercaWaiting> bySlot = const [],

  /// How many wait for each pretext, at any slot.
  final List<CercaWaiting> byPretext = const [],
}) extends Equatable {
  /// {@macro cerca}
  this;

  @override
  List<Object?> get props => [barrioId, bySlot, byPretext];
}

/// {@template cerca_waiting}
/// How many neighbours wait for a ronda of [pretextId], at [slotId] when it
/// is known.
/// {@endtemplate}
class const CercaWaiting({
  /// The pretext id (`mate`).
  required final String pretextId,

  /// How many wait.
  required final int count,

  /// The slot id (`sat-afternoon`), or `null` for a count at any slot.
  final String? slotId,
}) extends Equatable {
  /// {@macro cerca_waiting}
  this;

  @override
  List<Object?> get props => [pretextId, count, slotId];
}
