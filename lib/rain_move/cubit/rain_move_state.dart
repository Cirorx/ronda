part of 'rain_move_cubit.dart';

/// Whether the host's screen can show the proposal.
enum RainMoveViewStatus {
  /// Reading.
  loading,

  /// [RainMoveState.move] is the proposal.
  ready,

  /// There is no proposal for that week.
  none,

  /// The account isn't this proposal's host.
  forbidden,

  /// It couldn't be read.
  failure,
}

/// Where «Mandarlo» stands.
enum RainMoveSending {
  /// Not tapped.
  idle,

  /// On its way.
  sending,

  /// The deadline passed before it got there: it stays as it is.
  late,

  /// It didn't reach the server.
  failed,
}

final class const RainMoveState({
  final RainMoveViewStatus status = RainMoveViewStatus.loading,
  final RainMove? move,

  /// The option the host tapped, whose message shows before it goes.
  final MoveChoice? selected,
  final RainMoveSending sending = RainMoveSending.idle,
}) extends Equatable {
  /// The tapped option, if it is still offered.
  RainOption? get selectedOption => [
    for (final option in move?.options ?? const <RainOption>[])
      if (option.choice == selected) option,
  ].firstOrNull;

  @override
  List<Object?> get props => [status, move, selected, sending];
}
