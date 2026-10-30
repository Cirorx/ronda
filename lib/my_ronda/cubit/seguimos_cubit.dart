import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'seguimos_state.dart';

/// The ¿seguimos? card on Mi ronda: follows [_uid]'s own question in their
/// ronda, records "Sí" or "No" (changeable until the close), and after a
/// close below the floor their pick between another ronda and waiting.
///
/// A failed answer leaves the card as it was, with [SeguimosState.saveFailed]
/// for the line that says so, or [SeguimosState.closed] when the question
/// closed meanwhile.
class SeguimosCubit extends Cubit<SeguimosState> {
  new({required this._uid, required this._rondaRepository})
    : super(const SeguimosState());

  final String _uid;
  final RondaRepository _rondaRepository;
  StreamSubscription<Seguimos?>? _subscription;

  /// Follows the member's question.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const SeguimosState());
    _subscription = _rondaRepository
        .watchSeguimos(_uid)
        .listen(
          (seguimos) => emit(
            SeguimosState(
              status: seguimos == null
                  ? SeguimosCardStatus.none
                  : SeguimosCardStatus.ready,
              seguimos: seguimos,
              saving: state.saving,
              changing: state.changing && (seguimos?.open ?? false),
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(const SeguimosState(status: SeguimosCardStatus.failure));
          },
        );
  }

  /// "Sí".
  Future<void> yesTapped() => _save(
    (rondaId) => _rondaRepository.answerSeguimos(
      rondaId: rondaId,
      answer: SeguimosAnswer.yes,
    ),
  );

  /// "No".
  Future<void> noTapped() => _save(
    (rondaId) => _rondaRepository.answerSeguimos(
      rondaId: rondaId,
      answer: SeguimosAnswer.no,
    ),
  );

  /// "Cambiar": the question shows again.
  void changeTapped() => emit(state.copyWith(changing: true));

  /// "Sumarte a otro ya".
  Future<void> joinTapped() => _save(
    (rondaId) => _rondaRepository.chooseAfterSeguimos(
      rondaId: rondaId,
      choice: SeguimosChoice.join,
    ),
  );

  /// "Esperar dos semanas más".
  Future<void> waitTapped() => _save(
    (rondaId) => _rondaRepository.chooseAfterSeguimos(
      rondaId: rondaId,
      choice: SeguimosChoice.wait,
    ),
  );

  Future<void> _save(Future<void> Function(String rondaId) call) async {
    final seguimos = state.seguimos;
    if (seguimos == null || state.saving) return;
    emit(state.copyWith(saving: true, saveFailed: false, closed: false));
    try {
      await call(seguimos.rondaId);
    } on RsvpFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      final passed = error.reason == RsvpFailureReason.passed;
      emit(state.copyWith(saving: false, saveFailed: !passed, closed: passed));
      return;
    }
    if (!isClosed) emit(state.copyWith(saving: false, changing: false));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
