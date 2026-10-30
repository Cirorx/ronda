import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'add_to_ronda_state.dart';

/// "Sumar a esta ronda": who could join one ronda, and adding one of them.
/// The server checks the cap, the one-ronda rule and the demo rule; this
/// only reports what it said.
class AddToRondaCubit extends Cubit<AddToRondaState> {
  new({required this._rondaRepository, required this._rondaId})
    : super(const AddToRondaState());

  final RondaRepository _rondaRepository;

  /// The ronda people join.
  final String _rondaId;

  /// Reads who could join, keeping the last outcome on screen.
  Future<void> load() async {
    emit(state.copyWith(status: AddToRondaStatus.loading));
    try {
      final candidates = await _rondaRepository.rondaCandidates(_rondaId);
      emit(
        state.copyWith(status: AddToRondaStatus.ready, candidates: candidates),
      );
    } on ProposalsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(state.copyWith(status: AddToRondaStatus.failure));
    }
  }

  /// Adds [candidate]; one who sits in another ronda moves out of it.
  Future<void> add(Candidate candidate) async {
    if (state.adding != null) return;
    emit(state.copyWith(adding: candidate, outcome: AddOutcome.none));
    try {
      final added = await _rondaRepository.addToRonda(
        rondaId: _rondaId,
        uid: candidate.uid,
        move: candidate.currentRondaId != null,
      );
      emit(
        AddToRondaState(
          status: state.status,
          candidates: state.candidates,
          outcome: AddOutcome.added,
          lastName: candidate.firstName,
          warnings: added.warnings,
        ),
      );
      await load();
    } on ProposalsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(
        AddToRondaState(
          status: state.status,
          candidates: state.candidates,
          outcome: switch (failure.reason) {
            ProposalsFailureReason.full => AddOutcome.full,
            ProposalsFailureReason.alreadyIn => AddOutcome.alreadyIn,
            _ => AddOutcome.failed,
          },
          lastName: candidate.firstName,
        ),
      );
    }
  }
}
