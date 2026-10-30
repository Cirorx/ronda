import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'pilot_numbers_state.dart';

/// "Los números del piloto" on the admin screen: counted by the server when
/// asked, never stored, invented sign-ups left out.
class PilotNumbersCubit extends Cubit<PilotNumbersState> {
  new({required this._rondaRepository}) : super(const PilotNumbersState());

  final RondaRepository _rondaRepository;

  /// Counts them now; the numbers shown stay while it counts again.
  Future<void> load() async {
    emit(PilotNumbersState(numbers: state.numbers));
    try {
      final numbers = await _rondaRepository.pilotNumbers();
      emit(
        PilotNumbersState(status: PilotNumbersStatus.ready, numbers: numbers),
      );
    } on ProposalsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(
        PilotNumbersState(
          status: failure.reason == ProposalsFailureReason.forbidden
              ? PilotNumbersStatus.forbidden
              : PilotNumbersStatus.failure,
          numbers: state.numbers,
        ),
      );
    }
  }
}
