part of 'this_week_cubit.dart';

/// Whether the card can show the member's ronda.
enum ThisWeekStatus {
  /// Reading.
  loading,

  /// The member is in no ronda yet: "Todavía no tenés grupo".
  noGroup,

  /// [ThisWeekState.week] is their ronda's upcoming meeting.
  ready,

  /// The ronda couldn't be read.
  failure,
}

final class const ThisWeekState({
  final ThisWeekStatus status = ThisWeekStatus.loading,
  final ThisWeek? week,

  /// The answer on its way to the server, if one is.
  final RsvpAnswer? answering,

  /// The last answer didn't reach the server.
  final bool answerFailed = false,

  /// "Cambiar mi respuesta" was tapped: the question shows again.
  final bool changing = false,

  /// The "Esta no" sheet is up.
  final bool estaNoSheet = false,

  /// An answer to "¿Abrís vos?" or to the después at this member's home is
  /// on its way.
  final bool acting = false,

  /// Why the last of those answers wasn't saved.
  final HostsFailureReason? actionFailure,
}) extends Equatable {
  /// Whether the card asks "¿Venís?": nothing answered yet (a pause answers
  /// for them), or changing it.
  bool get asks =>
      (week?.myAnswer == null && week?.pausedUntil == null) || changing;

  ThisWeekState copyWith({
    RsvpAnswer? Function()? answering,
    bool? answerFailed,
    bool? changing,
    bool? estaNoSheet,
    bool? acting,
    HostsFailureReason? Function()? actionFailure,
  }) => ThisWeekState(
    status: status,
    week: week,
    answering: answering == null ? this.answering : answering(),
    answerFailed: answerFailed ?? this.answerFailed,
    changing: changing ?? this.changing,
    estaNoSheet: estaNoSheet ?? this.estaNoSheet,
    acting: acting ?? this.acting,
    actionFailure: actionFailure == null ? this.actionFailure : actionFailure(),
  );

  @override
  List<Object?> get props => [
    status,
    week,
    answering,
    answerFailed,
    changing,
    estaNoSheet,
    acting,
    actionFailure,
  ];
}
