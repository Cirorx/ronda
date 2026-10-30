import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'waiting_state.dart';

/// The waiting-list card on Mi ronda, before a group exists: follows
/// [_uid]'s place on the list nearest to filling ("Con vos son 5 de 6"),
/// and after a round that didn't fill records their pick between joining a
/// nearby ronda and waiting two weeks more.
class WaitingCubit extends Cubit<WaitingState> {
  new({required this._uid, required this._rondaRepository})
    : super(const WaitingState());

  final String _uid;
  final RondaRepository _rondaRepository;
  StreamSubscription<Waiting?>? _subscription;

  /// Follows the person's waiting list.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const WaitingState());
    _subscription = _rondaRepository
        .watchWaiting(_uid)
        .listen(
          (waiting) => emit(
            WaitingState(
              status: waiting == null
                  ? WaitingCardStatus.none
                  : WaitingCardStatus.ready,
              waiting: waiting,
              saving: state.saving,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(const WaitingState(status: WaitingCardStatus.failure));
          },
        );
  }

  /// "Sumarte a otro ya".
  Future<void> joinTapped() => _choose(WaitlistChoice.join);

  /// "Esperar dos semanas más".
  Future<void> waitTapped() => _choose(WaitlistChoice.wait);

  Future<void> _choose(WaitlistChoice choice) async {
    if (state.waiting == null || state.saving) return;
    emit(state.copyWith(saving: true, saveFailed: false));
    try {
      await _rondaRepository.chooseAfterWaitlist(choice);
    } on RsvpFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(state.copyWith(saving: false, saveFailed: true));
      return;
    }
    if (!isClosed) emit(state.copyWith(saving: false));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
