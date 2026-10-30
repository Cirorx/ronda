import 'package:equatable/equatable.dart';

/// {@template opened_roll}
/// A tap on "¿Quién vino hoy?" that should open that meeting's roll, not
/// Mi ronda.
/// {@endtemplate}
class const OpenedRoll({
  /// The ronda's id.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,
}) extends Equatable {
  /// {@macro opened_roll}
  this;

  @override
  List<Object?> get props => [rondaId, week];
}
