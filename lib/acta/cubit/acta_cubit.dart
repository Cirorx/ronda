import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organiser_repository/organiser_repository.dart';

part 'acta_state.dart';

/// "Lo que hizo el programa" for ronda [_rondaId]: follows its newest week
/// of the acta and records [_uid]'s [Algo estuvo mal] for the admin.
class ActaCubit extends Cubit<ActaState> {
  new({
    required this._uid,
    required this._rondaId,
    required this._organiserRepository,
  }) : super(const ActaState());

  final String _uid;
  final String _rondaId;
  final OrganiserRepository _organiserRepository;
  StreamSubscription<Acta>? _subscription;

  /// Follows the acta.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const ActaState());
    _subscription = _organiserRepository
        .watchActa(_rondaId)
        .listen(
          (acta) => emit(
            ActaState(
              status: ActaStatus.ready,
              acta: acta,
              report: state.report,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(const ActaState(status: ActaStatus.failure));
          },
        );
  }

  /// [Algo estuvo mal]: records the tap on the shown week, once.
  Future<void> reportTapped() async {
    final week = state.acta.week;
    if (week == null ||
        state.report == ActaReport.sending ||
        state.report == ActaReport.sent) {
      return;
    }
    emit(
      ActaState(
        status: state.status,
        acta: state.acta,
        report: ActaReport.sending,
      ),
    );
    try {
      await _organiserRepository.reportActa(
        rondaId: _rondaId,
        uid: _uid,
        week: week,
      );
      emit(
        ActaState(
          status: state.status,
          acta: state.acta,
          report: ActaReport.sent,
        ),
      );
    } on OrganiserFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(
        ActaState(
          status: state.status,
          acta: state.acta,
          report: ActaReport.failed,
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
