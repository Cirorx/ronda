import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:equatable/equatable.dart';

part 'donde_queda_guess_state.dart';

/// A member drops their one pin on this week's ¿Dónde queda? photo for
/// ronda [_rondaId]: the photo and the hint, a small map of the barrio, a
/// tap for the pin, and [Es acá]. The photographer doesn't guess, and a pin
/// can't be moved once sent.
class DondeQuedaGuessCubit extends Cubit<DondeQuedaGuessState> {
  new({
    required this._uid,
    required this._rondaId,
    required this._dondeQuedaRepository,
  }) : super(const DondeQuedaGuessState());

  final String _uid;
  final String _rondaId;
  final DondeQuedaRepository _dondeQuedaRepository;

  /// Reads the game and its photo. A game that isn't open, the member's
  /// own photo, or a pin already dropped closes the screen.
  Future<void> started() async {
    try {
      final week = await _dondeQuedaRepository
          .watch(rondaId: _rondaId, uid: _uid)
          .first;
      final game = week.game;
      if (game == null) {
        emit(const DondeQuedaGuessState(status: DondeQuedaGuessStatus.closed));
        return;
      }
      if (game.guessed) {
        emit(
          DondeQuedaGuessState(status: DondeQuedaGuessStatus.done, game: game),
        );
        return;
      }
      final path = game.photoPath;
      if (game.status != DondeQuedaStatus.open || game.posted || path == null) {
        emit(const DondeQuedaGuessState(status: DondeQuedaGuessStatus.closed));
        return;
      }
      final photo = await _dondeQuedaRepository.photo(path);
      emit(
        DondeQuedaGuessState(
          status: DondeQuedaGuessStatus.ready,
          game: game,
          photo: photo,
        ),
      );
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const DondeQuedaGuessState(status: DondeQuedaGuessStatus.failure));
    }
  }

  /// A tap on the map: the pin goes there, until it is sent.
  void pinDropped(MapPoint pin) {
    if (state.status != DondeQuedaGuessStatus.ready) return;
    emit(state.copyWith(pin: pin, sendFailed: false));
  }

  /// «Es acá»: the one pin is sent.
  Future<void> confirmTapped() async {
    final (game, pin) = (state.game, state.pin);
    if (state.status != DondeQuedaGuessStatus.ready ||
        game == null ||
        pin == null) {
      return;
    }
    emit(state.copyWith(status: DondeQuedaGuessStatus.sending));
    try {
      await _dondeQuedaRepository.guess(
        rondaId: _rondaId,
        week: game.week,
        pin: pin,
      );
      emit(state.copyWith(status: DondeQuedaGuessStatus.done));
    } on AlreadyGuessedFailure {
      emit(state.copyWith(status: DondeQuedaGuessStatus.done));
    } on NotYourTurnFailure {
      emit(state.copyWith(status: DondeQuedaGuessStatus.closed));
    } on DondeQuedaFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(
        state.copyWith(status: DondeQuedaGuessStatus.ready, sendFailed: true),
      );
    }
  }
}
