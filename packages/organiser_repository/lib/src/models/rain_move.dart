import 'package:equatable/equatable.dart';

/// The host's choices when rain is likely.
enum MoveChoice {
  /// To the covered public place nearby.
  covered,

  /// To another day.
  postpone,

  /// Going anyway.
  asIs,
}

/// Where a rain proposal stands.
enum RainMoveStatus {
  /// Waiting for the host until the deadline.
  pending,

  /// The host picked, and the members were told.
  decided,

  /// Nobody picked by the deadline: the plan stays as it is.
  expired,
}

/// {@template rain_option}
/// One of the host's buttons, and the one message members get if they
/// pick it.
/// {@endtemplate}
class const RainOption({
  /// Which choice it is.
  required final MoveChoice choice,

  /// The button: "Al Salón Comunal de El Pinar".
  required final String label,

  /// The members' message, exactly: "Por la lluvia, el jueves …".
  required final String message,
}) extends Equatable {
  /// {@macro rain_option}
  this;

  @override
  List<Object?> get props => [choice, label, message];
}

/// {@template rain_move}
/// The organiser's rain proposal to a ronda's host for one meeting. The
/// words are the server's es-419.
/// {@endtemplate}
class const RainMove({
  /// "El jueves puede llover".
  required final String title,

  /// "Jueves 16:00 · lluvia 80%. … Pronóstico de Open-Meteo."
  required final String forecast,

  /// The choices, "Vamos igual" last.
  required final List<RainOption> options,

  /// How many members the pick reaches.
  required final int recipients,

  /// When the plan stays as it is without a pick.
  required final DateTime deadline,

  /// Where it stands.
  required final RainMoveStatus status,

  /// Whether this host stands in: no anfitrión is set yet.
  required final bool standIn,

  /// The pick, once decided.
  final MoveChoice? choice,

  /// How many members it reached, once decided.
  final int? sent,
}) extends Equatable {
  /// {@macro rain_move}
  this;

  /// The option picked, once decided.
  RainOption? get picked => [
    for (final option in options)
      if (option.choice == choice) option,
  ].firstOrNull;

  @override
  List<Object?> get props => [
    title,
    forecast,
    options,
    recipients,
    deadline,
    status,
    standIn,
    choice,
    sent,
  ];
}

/// {@template move_answer}
/// What the host's pick did: how many members it reached, and whether it
/// had already been sent (a second tap sends nothing).
/// {@endtemplate}
class const MoveAnswer({required final int sent, required final bool already})
    extends Equatable {
  /// {@macro move_answer}
  this;

  @override
  List<Object?> get props => [sent, already];
}

/// {@template rain_check_result}
/// What a rain check run by hand did: rondas checked, failed, and already
/// checked this week.
/// {@endtemplate}
class const RainCheckResult({
  required final int checked,
  required final int failed,
}) extends Equatable {
  /// {@macro rain_check_result}
  this;

  @override
  List<Object?> get props => [checked, failed];
}
