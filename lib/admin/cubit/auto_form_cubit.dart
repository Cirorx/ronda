import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'auto_form_state.dart';

/// "Rondas que se arman solas" on the admin screen: follows
/// `config/auto_form`, turns it on or off, and sets the minutes the admin
/// has to stop a proposal before it approves itself.
class AutoFormCubit extends Cubit<AutoFormState> implements StepNamed {
  new({required this._rondaRepository}) : super(const AutoFormState());

  final RondaRepository _rondaRepository;
  StreamSubscription<AutoFormSettings>? _subscription;

  /// Follows the switch and the hold.
  void subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _rondaRepository.watchAutoForm().listen(
      (settings) => emit(
        state.copyWith(status: AutoFormStatus.ready, settings: settings),
      ),
      onError: (Object error) =>
          emit(state.copyWith(status: AutoFormStatus.failure)),
    );
  }

  /// Turns rondas forming themselves on or off, keeping the hold.
  Future<void> enabledToggled({required bool enabled}) async {
    if (state.settings case final settings?) {
      await _save(
        AutoFormSettings(enabled: enabled, holdMinutes: settings.holdMinutes),
      );
    }
  }

  /// The admin typed [text] in the minutes field.
  void holdChanged(String text) => emit(state.copyWith(holdDraft: text));

  /// Saves the typed minutes, when they are a hold the server takes.
  Future<void> holdSaved() async {
    if ((state.settings, state.draftMinutes) case (
      final settings?,
      final minutes?,
    )) {
      await _save(
        AutoFormSettings(enabled: settings.enabled, holdMinutes: minutes),
      );
    }
  }

  Future<void> _save(AutoFormSettings settings) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true, saveFailed: false));
    try {
      await _rondaRepository.setAutoForm(settings);
      emit(state.copyWith(saving: false, clearDraft: true));
    } on ProposalsFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(saving: false, saveFailed: true));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }

  @override
  String get reportStep => 'AutoFormCubit';
}
