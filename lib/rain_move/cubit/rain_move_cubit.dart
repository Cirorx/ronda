import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organiser_repository/organiser_repository.dart';

part 'rain_move_state.dart';

/// The host's side of a rain proposal for ronda [_rondaId]'s [_week]:
/// follows it, shows the exact message of the option tapped, and sends that
/// one message to the members.
class RainMoveCubit extends Cubit<RainMoveState> {
  new({
    required this._rondaId,
    required this._week,
    required this._organiserRepository,
  }) : super(const RainMoveState());

  final String _rondaId;
  final String _week;
  final OrganiserRepository _organiserRepository;
  StreamSubscription<RainMove?>? _subscription;

  /// Follows the proposal.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const RainMoveState());
    _subscription = _organiserRepository
        .watchMove(_rondaId, _week)
        .listen(
          (move) => emit(
            RainMoveState(
              status: move == null
                  ? RainMoveViewStatus.none
                  : RainMoveViewStatus.ready,
              move: move,
              selected: state.selected,
              sending: state.sending,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(
              RainMoveState(
                status:
                    error is OrganiserFailure &&
                        error.reason == OrganiserFailureReason.forbidden
                    ? RainMoveViewStatus.forbidden
                    : RainMoveViewStatus.failure,
              ),
            );
          },
        );
  }

  /// One of the options: its message shows, ready to send.
  void optionTapped(MoveChoice choice) => emit(
    RainMoveState(status: state.status, move: state.move, selected: choice),
  );

  /// «Mandarlo»: sends the tapped option's message. The proposal then
  /// reads as decided through the subscription.
  Future<void> sendTapped() async {
    final choice = state.selectedOption?.choice;
    if (choice == null || state.sending == RainMoveSending.sending) return;
    emit(_sending(RainMoveSending.sending));
    try {
      await _organiserRepository.answerMove(
        rondaId: _rondaId,
        week: _week,
        choice: choice,
      );
      emit(_sending(RainMoveSending.idle));
    } on OrganiserFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(
        _sending(
          failure.reason == OrganiserFailureReason.late
              ? RainMoveSending.late
              : RainMoveSending.failed,
        ),
      );
    }
  }

  RainMoveState _sending(RainMoveSending sending) => RainMoveState(
    status: state.status,
    move: state.move,
    selected: state.selected,
    sending: sending,
  );

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
