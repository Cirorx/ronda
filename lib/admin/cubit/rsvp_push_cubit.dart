import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'rsvp_push_state.dart';

/// "Mandarlo ahora" on the admin screen: sends this week's RSVP push to
/// every ronda ahead of its lead time, once a week and never at night (the
/// server decides both).
class RsvpPushCubit extends Cubit<RsvpPushState> {
  new({required this._rondaRepository}) : super(const RsvpPushState());

  final RondaRepository _rondaRepository;

  /// Sends it now.
  Future<void> sendTapped() async {
    if (state.status == RsvpPushStatus.sending) return;
    emit(const RsvpPushState(status: RsvpPushStatus.sending));
    try {
      final result = await _rondaRepository.sendRsvpNow();
      emit(RsvpPushState(status: RsvpPushStatus.sent, result: result));
    } on RsvpFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const RsvpPushState(status: RsvpPushStatus.failed));
    }
  }
}
