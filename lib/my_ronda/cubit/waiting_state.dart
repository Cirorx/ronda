part of 'waiting_cubit.dart';

/// Whether the waiting-list card has anything to show.
enum WaitingCardStatus {
  /// Reading.
  loading,

  /// The person waits on no list: no card.
  none,

  /// [WaitingState.waiting] is their list.
  ready,

  /// It couldn't be read.
  failure,
}

final class const WaitingState({
  final WaitingCardStatus status = WaitingCardStatus.loading,
  final Waiting? waiting,

  /// The pick on its way to the server, if one is.
  final WaitlistChoice? saving,

  /// The last pick didn't reach the server.
  final bool saveFailed = false,
}) extends Equatable {
  WaitingState copyWith({
    WaitlistChoice? Function()? saving,
    bool? saveFailed,
  }) => WaitingState(
    status: status,
    waiting: waiting,
    saving: saving == null ? this.saving : saving(),
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  List<Object?> get props => [status, waiting, saving, saveFailed];
}
