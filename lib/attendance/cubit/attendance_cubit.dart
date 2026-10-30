import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'attendance_state.dart';

/// "¿Quién vino hoy?" for ronda [_rondaId]'s meeting of [_week]: follows
/// the host's roll and records each «Vino» / «No vino» tap.
///
/// A tap shows at once and stays until the roll comes back with it; a tap
/// that doesn't reach the server goes back to what the roll says, with
/// [AttendanceState.tapFailure] for the line that says why.
class AttendanceCubit extends Cubit<AttendanceState> {
  new({
    required this._rondaId,
    required this._week,
    required this._rondaRepository,
  }) : super(const AttendanceState());

  final String _rondaId;
  final String _week;
  final RondaRepository _rondaRepository;
  StreamSubscription<AttendanceRoll?>? _subscription;

  /// Follows the roll.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const AttendanceState());
    _subscription = _rondaRepository
        .watchRoll(_rondaId, _week)
        .listen(
          (roll) => emit(
            AttendanceState(
              status: roll == null
                  ? AttendanceStatus.none
                  : AttendanceStatus.ready,
              roll: roll,
              pending: {
                for (final MapEntry(:key, :value) in state.pending.entries)
                  if (roll?.marks[key] != value) key: value,
              },
              tapFailure: state.tapFailure,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(
              AttendanceState(
                status:
                    error is HostsFailure &&
                        error.reason == HostsFailureReason.forbidden
                    ? AttendanceStatus.forbidden
                    : AttendanceStatus.failure,
              ),
            );
          },
        );
  }

  /// «Vino» (`true`) or «No vino» for [uid].
  Future<void> marked(String uid, {required bool came}) async {
    emit(
      state.withTaps(pending: {...state.pending, uid: came}, tapFailure: null),
    );
    try {
      await _rondaRepository.recordAttendance(
        rondaId: _rondaId,
        week: _week,
        uid: uid,
        came: came,
      );
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (isClosed) return;
      emit(
        state.withTaps(
          pending: {...state.pending}..remove(uid),
          tapFailure: failure.reason,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
