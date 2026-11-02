part of 'first_visit_cubit.dart';

/// Whether the ronda's newcomers could be read.
enum FirstVisitStatus {
  /// Reading.
  loading,

  /// [FirstVisitState.card], [FirstVisitState.toChoose] and
  /// [FirstVisitState.waitingFor] hold what to show.
  ready,

  /// They couldn't be read: the section shows nothing.
  failure,
}

/// Where a host's pick or a waiter's "No puedo" stands.
enum WelcomeSaveStatus {
  /// Nothing on its way.
  idle,

  /// On its way to the server.
  saving,

  /// Saved: the sheet closes.
  saved,

  /// Not saved; [FirstVisitState.failure] says why.
  failed,
}

final class const FirstVisitState({
  final FirstVisitStatus status = FirstVisitStatus.loading,

  /// The member's own "Así va a ser", from two days before their first
  /// meeting until its day.
  final Welcome? card,

  /// The newcomers whose waiter this member, a host, chooses, until their
  /// meeting's day.
  final List<Welcome> toChoose = const [],

  /// The newcomers another member picked this one to wait for.
  final List<Welcome> waitingFor = const [],

  final WelcomeSaveStatus save = WelcomeSaveStatus.idle,

  /// Why the last pick or "No puedo" wasn't saved.
  final WelcomeFailureReason? failure,
}) extends Equatable {
  FirstVisitState copyWith({
    WelcomeSaveStatus? save,
    WelcomeFailureReason? Function()? failure,
  }) => FirstVisitState(
    status: status,
    card: card,
    toChoose: toChoose,
    waitingFor: waitingFor,
    save: save ?? this.save,
    failure: failure == null ? this.failure : failure(),
  );

  @override
  List<Object?> get props => [
    status,
    card,
    toChoose,
    waitingFor,
    save,
    failure,
  ];
}
