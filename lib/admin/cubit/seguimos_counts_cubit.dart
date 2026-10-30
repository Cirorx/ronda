import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'seguimos_counts_state.dart';

/// The admin's ¿seguimos? counts per ronda: sí, no and sin contestar, and
/// what came of each close. Never who said what.
class SeguimosCountsCubit extends Cubit<SeguimosCountsState> {
  new({required this._rondaRepository}) : super(const SeguimosCountsState());

  final RondaRepository _rondaRepository;
  StreamSubscription<List<SeguimosCounts>>? _subscription;

  /// Follows every ronda's counts.
  void subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _rondaRepository.watchSeguimosCounts().listen(
      (rondas) => emit(
        SeguimosCountsState(status: SeguimosCountsStatus.ready, rondas: rondas),
      ),
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(const SeguimosCountsState(status: SeguimosCountsStatus.failure));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
