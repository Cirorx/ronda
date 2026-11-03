import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:safety_repository/safety_repository.dart';

part 'safety_queue_state.dart';

/// The admin's queue of reports: follows it, puts anyone reported by two or
/// more different people on top, marks what the admin sees as read (the
/// Admin tab's count goes down), and acts on a report.
///
/// The server decides who is admin: a refusal shows as
/// [SafetyQueueStatus.forbidden].
class SafetyQueueCubit extends Cubit<SafetyQueueState> implements StepNamed {
  new({required this._safetyRepository}) : super(const SafetyQueueState());

  final SafetyRepository _safetyRepository;
  StreamSubscription<SafetyQueue>? _queue;

  /// The unread reports this visit already marked read.
  final _marked = <String>{};

  /// Follows the queue.
  void subscribe() {
    unawaited(_queue?.cancel());
    emit(SafetyQueueState(tab: state.tab, fresh: state.fresh));
    _queue = _safetyRepository.watchQueue().listen(
      _onQueue,
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(
          state.copyWith(
            status:
                error is SafetyFailure &&
                    error.reason == SafetyFailureReason.forbidden
                ? SafetyQueueStatus.forbidden
                : SafetyQueueStatus.failure,
          ),
        );
      },
    );
  }

  void _onQueue(SafetyQueue queue) {
    final unread = [
      for (final report in queue.reports)
        if (report.unread && _marked.add(report.id)) report.id,
    ];
    emit(
      state.copyWith(
        status: SafetyQueueStatus.ready,
        queue: queue,
        fresh: {...state.fresh, ...unread},
      ),
    );
    for (final id in unread) {
      unawaited(_markRead(id));
    }
  }

  Future<void> _markRead(String reportId) async {
    try {
      await _safetyRepository.markRead(reportId);
    } on SafetyFailure catch (error, stackTrace) {
      _marked.remove(reportId);
      addError(error, stackTrace);
    }
  }

  /// "Abiertos" or "Archivados".
  void tabChanged(SafetyQueueTab tab) => emit(state.copyWith(tab: tab));

  /// "Archivar".
  Future<void> archive(String reportId) =>
      _act(reportId, () => _safetyRepository.archive(reportId));

  /// "Reabrir".
  Future<void> reopen(String reportId) =>
      _act(reportId, () => _safetyRepository.reopen(reportId));

  /// "Separarlos".
  Future<void> separate(String reportId) =>
      _act(reportId, () => _safetyRepository.separate(reportId));

  /// "Sacar de Ronda", once the admin confirmed it.
  Future<void> remove(String reportId) =>
      _act(reportId, () => _safetyRepository.remove(reportId));

  /// "Juntarlos de nuevo".
  Future<void> joinAgain(String pairId) =>
      _act(pairId, () => _safetyRepository.joinAgain(pairId));

  /// "Dejar entrar de nuevo".
  Future<void> letBackIn(String uid) =>
      _act(uid, () => _safetyRepository.letBackIn(uid));

  Future<void> _act(String id, Future<void> Function() call) async {
    emit(state.copyWith(busy: () => id, actionFailed: false));
    try {
      await call();
      emit(state.copyWith(busy: () => null));
    } on SafetyFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(busy: () => null, actionFailed: true));
    }
  }

  @override
  Future<void> close() async {
    await _queue?.cancel();
    await super.close();
  }

  @override
  String get reportStep => 'SafetyQueueCubit';
}
