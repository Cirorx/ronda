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

  /// A pick is on its way to the server.
  final bool saving = false,

  /// The last pick didn't reach the server.
  final bool saveFailed = false,
}) extends Equatable {
  WaitingState copyWith({bool? saving, bool? saveFailed}) => WaitingState(
    status: status,
    waiting: waiting,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  List<Object?> get props => [status, waiting, saving, saveFailed];
}
