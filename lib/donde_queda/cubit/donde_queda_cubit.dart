import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:equatable/equatable.dart';

part 'donde_queda_state.dart';

/// ¿Dónde queda? on Mi ronda, for ronda [_rondaId]: follows this week's
/// game and last week's answer as [_uid] sees them, and records "Esta
/// semana no" when it is their turn. Nothing here sends a notification:
/// the card is something people open themselves.
class DondeQuedaCubit extends Cubit<DondeQuedaState> {
  new({
    required this._rondaId,
    required this._uid,
    required this._dondeQuedaRepository,
  }) : super(const DondeQuedaState());

  final String _rondaId;
  final String _uid;
  final DondeQuedaRepository _dondeQuedaRepository;
  StreamSubscription<DondeQuedaWeek>? _subscription;

  /// Follows the game.
  void subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _dondeQuedaRepository
        .watch(rondaId: _rondaId, uid: _uid)
        .listen(
          (week) => emit(
            DondeQuedaState(
              status: DondeQuedaLoad.ready,
              week: week,
              passing: state.passing,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(const DondeQuedaState(status: DondeQuedaLoad.failure));
          },
        );
  }

  /// "Esta semana no": the turn passes on, and nobody hears why.
  Future<void> passTapped() async {
    final game = state.week?.game;
    if (game == null || !game.isMyTurn || state.passing) return;
    emit(state.copyWith(passing: true, passFailed: false));
    try {
      await _dondeQuedaRepository.pass(rondaId: _rondaId, week: game.week);
      if (!isClosed) emit(state.copyWith(passing: false));
    } on NotYourTurnFailure {
      if (!isClosed) emit(state.copyWith(passing: false));
    } on DondeQuedaFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) emit(state.copyWith(passing: false, passFailed: true));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
