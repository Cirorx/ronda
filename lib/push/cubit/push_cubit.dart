import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:push_repository/push_repository.dart';

part 'push_state.dart';

/// "¿Te avisamos los martes?": asks for notifications from a tap, never on
/// its own, and keeps this phone's token saved for [_uid] once they are
/// allowed. "Ahora no" keeps the card away for
/// [PushRepository.promptSnooze], across launches.
///
/// A token that can't be saved (no network, an iPhone without APNs) is
/// reported to the observer and tried again on the next launch; the person
/// sees nothing. Neither the token nor any failure detail reaches the state.
class PushCubit extends Cubit<PushState> {
  new({required this._uid, required this._pushRepository})
    : super(const PushState());

  final String _uid;
  final PushRepository _pushRepository;
  StreamSubscription<void>? _registrations;

  /// Reads whether notifications are allowed: if they are, saves this
  /// phone's token; if the phone can still ask, offers the card, unless
  /// "Ahora no" was tapped lately.
  Future<void> started() async {
    final PushPermission permission;
    try {
      permission = await _pushRepository.permission();
    } on PushPermissionFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const PushState(status: PushStatus.dismissed));
      return;
    }
    if (isClosed) return;
    switch (permission) {
      case PushPermission.allowed:
        emit(const PushState(status: PushStatus.allowed));
        await _register();
      case PushPermission.notAsked || PushPermission.refused:
        final snoozed = await _pushRepository.promptSnoozed();
        if (isClosed) return;
        emit(
          PushState(
            status: snoozed ? PushStatus.dismissed : PushStatus.offered,
          ),
        );
      case PushPermission.blocked:
        emit(const PushState(status: PushStatus.dismissed));
    }
  }

  /// "Sí, avisame": the system's prompt, then the token when allowed.
  Future<void> allowTapped() async {
    emit(const PushState(status: PushStatus.requesting));
    final PushPermission permission;
    try {
      permission = await _pushRepository.askPermission();
    } on PushPermissionFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const PushState(status: PushStatus.offered));
      return;
    }
    if (isClosed) return;
    switch (permission) {
      case PushPermission.allowed:
        emit(const PushState(status: PushStatus.allowed));
        await _register();
      case PushPermission.blocked:
        emit(const PushState(status: PushStatus.blocked));
      case PushPermission.notAsked || PushPermission.refused:
        emit(const PushState(status: PushStatus.dismissed));
    }
  }

  /// "Ahora no" or "Entendido": the card goes. "Ahora no" is remembered on
  /// the phone, so the card stays away on the next launches too; a failure
  /// to remember it is reported, and the card comes back on the next launch.
  /// "Entendido" needs nothing remembered: a phone that refused for good
  /// never gets the card at launch.
  Future<void> dismissed() async {
    final later = state.status == PushStatus.offered;
    emit(const PushState(status: PushStatus.dismissed));
    if (!later) return;
    try {
      await _pushRepository.snoozePrompt();
    } on SnoozePromptFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _register() async {
    try {
      await _pushRepository.registerDevice(_uid);
    } on RegisterDeviceFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    if (isClosed) return;
    _registrations ??= _pushRepository
        .keepDeviceRegistered(_uid)
        .listen((_) {}, onError: addError);
  }

  @override
  Future<void> close() async {
    await _registrations?.cancel();
    await super.close();
  }
}
