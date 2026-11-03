import 'package:equatable/equatable.dart';

/// {@template opened_rain_move}
/// A tap on "El jueves puede llover", the host's rain proposal, that should
/// open that proposal, not Mi ronda.
/// {@endtemplate}
class const OpenedRainMove({
  /// The ronda's id.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,
}) extends Equatable {
  /// {@macro opened_rain_move}
  this;

  @override
  List<Object?> get props => [rondaId, week];
}
