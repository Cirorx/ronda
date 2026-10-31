import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'buddy_state.dart';

/// The buddy on Mi ronda (#9): after the member's first meeting, choosing
/// who hears when they miss a week without saying so, and for a buddy, the
/// card that tells them someone did, with [Le escribo] opening WhatsApp
/// with no number and no text. A rule in code sends it, never the model.
class BuddyCubit extends Cubit<BuddyState> {
  new({
    required this._rondaId,
    required this._uid,
    required this._rondaRepository,
    required this._contactRepository,
  }) : super(const BuddyState());

  final String _rondaId;
  final String _uid;
  final RondaRepository _rondaRepository;
  final ContactRepository _contactRepository;
  StreamSubscription<BuddyAsk?>? _asks;

  /// Reads whether it is time to choose and who could be chosen, whether
  /// WhatsApp opens here, and follows the member's buddy card.
  Future<void> load() async {
    await _asks?.cancel();
    _asks = _rondaRepository
        .watchBuddyAsk(_uid)
        .listen(
          (ask) => emit(state.copyWith(ask: () => ask)),
          onError: addError,
        );
    final canWhatsApp = await _contactRepository.canOpenWhatsApp();
    try {
      final options = await _rondaRepository.buddyOptions(_rondaId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BuddyStatus.ready,
          options: options,
          canWhatsApp: canWhatsApp,
        ),
      );
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) emit(state.copyWith(status: BuddyStatus.failure));
    }
  }

  /// A member was picked in the list.
  void picked(String uid) => emit(state.copyWith(selected: () => uid));

  /// "Cambiar" or "Elegir a alguien": the list shows again.
  void changeTapped() => emit(
    state.copyWith(changing: true, selected: () => state.options?.buddy?.uid),
  );

  /// "Elegir": saves who was picked.
  Future<void> chooseTapped() async {
    if (state.selected case final uid?) await _save(uid, BuddySaving.choose);
  }

  /// "Ahora no": saves nobody, so the question stops.
  Future<void> notNowTapped() => _save(null, BuddySaving.notNow);

  Future<void> _save(String? buddyUid, BuddySaving saving) async {
    if (state.saving != null) return;
    emit(state.copyWith(saving: () => saving, saveFailed: false));
    try {
      await _rondaRepository.setBuddy(rondaId: _rondaId, buddyUid: buddyUid);
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(saving: () => null, saveFailed: true));
      }
      return;
    }
    if (isClosed) return;
    final options = state.options!;
    emit(
      state.copyWith(
        saving: () => null,
        changing: false,
        options: BuddyOptions(
          due: options.due,
          chosen: true,
          choices: options.choices,
          buddy: options.choices
              .where((choice) => choice.uid == buddyUid)
              .firstOrNull,
        ),
      ),
    );
  }

  /// "Le escribo": opens WhatsApp with no number and no text, then closes
  /// the card.
  Future<void> writeTapped() async {
    try {
      await _contactRepository.openWhatsApp();
    } on ContactFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
    }
    await askClosed();
  }

  /// "Ahora no" on the buddy card: it goes away until the next miss.
  Future<void> askClosed() async {
    emit(state.copyWith(ask: () => null));
    try {
      await _rondaRepository.closeBuddyAsk(rondaId: _rondaId, uid: _uid);
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _asks?.cancel();
    await super.close();
  }
}
