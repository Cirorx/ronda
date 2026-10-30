import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'ronda_setup_state.dart';

/// The hours a ronda in band [bandId] may start at, every half hour, with
/// an hour of the band left for the meeting (`functions/rsvp.py`
/// `hour_in_band`): 09:00–11:00, 14:00–17:00, 19:00–20:00.
List<String> hourChoices(String bandId) {
  final (first, last) = switch (bandId) {
    'morning' => (9, 11),
    'afternoon' => (14, 17),
    'evening' => (19, 20),
    _ => (0, -1),
  };
  return [
    for (var hour = first; hour <= last; hour++)
      for (final minutes in const ['00', '30'])
        if (hour < last || minutes == '00')
          '${hour.toString().padLeft(2, '0')}:$minutes',
  ];
}

/// The admin's "Lugar, hora y anfitriones": every ronda that still meets,
/// and setting one's public place, hour and hosts.
class RondaSetupCubit extends Cubit<RondaSetupState> {
  new({required this._rondaRepository}) : super(const RondaSetupState());

  final RondaRepository _rondaRepository;

  /// Reads every ronda.
  Future<void> load() async {
    emit(const RondaSetupState());
    try {
      final rondas = await _rondaRepository.rondaSetups();
      emit(RondaSetupState(status: RondaSetupStatus.ready, rondas: rondas));
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(
        RondaSetupState(
          status: failure.reason == HostsFailureReason.forbidden
              ? RondaSetupStatus.forbidden
              : RondaSetupStatus.failure,
        ),
      );
    }
  }

  /// Sets ronda [rondaId]'s place, hour and hosts, then reads every ronda
  /// again; a `null` takes each one away. [RondaSetupState.saving] goes
  /// back to `false` either way, with [RondaSetupState.saveFailure] when it
  /// wasn't saved.
  Future<void> save({
    required String rondaId,
    String? placeName,
    String? placeLandmark,
    String? hour,
    String? anfitrionUid,
    String? colaUid,
  }) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true, saveFailure: () => null));
    try {
      await _rondaRepository.setRondaSetup(
        rondaId: rondaId,
        placeName: placeName,
        placeLandmark: placeLandmark,
        hour: hour,
        anfitrionUid: anfitrionUid,
        colaUid: colaUid,
      );
      final rondas = await _rondaRepository.rondaSetups();
      emit(RondaSetupState(status: RondaSetupStatus.ready, rondas: rondas));
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(state.copyWith(saving: false, saveFailure: () => failure.reason));
    }
  }

  /// The sheet closed: its failure line goes with it.
  void sheetClosed() => emit(state.copyWith(saveFailure: () => null));
}
