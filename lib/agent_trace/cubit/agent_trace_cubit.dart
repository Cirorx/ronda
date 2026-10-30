import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organiser_repository/organiser_repository.dart';

part 'agent_trace_state.dart';

/// The admin's live trace of the organiser agent: follows the newest runs
/// and the selected run's steps as they land, and runs the rain check by
/// hand, now or as if it were 22:00.
///
/// It follows the newest run, so a run started from here shows at once,
/// unless the admin picked an older one. The server decides who is admin:
/// a refusal shows as [AgentTraceStatus.forbidden].
class AgentTraceCubit extends Cubit<AgentTraceState> {
  new({required this._organiserRepository, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const AgentTraceState());

  final OrganiserRepository _organiserRepository;
  final DateTime Function() _now;
  StreamSubscription<List<AgentRun>>? _runs;
  StreamSubscription<List<AgentStep>>? _steps;
  StreamSubscription<int>? _flags;

  /// The hour "Probar a las 22:00" runs at: inside the quiet hours, so the
  /// gates hold whatever the program would send.
  static const nightHour = 22;

  /// Follows the newest runs.
  void subscribe() {
    unawaited(_runs?.cancel());
    emit(const AgentTraceState());
    _runs = _organiserRepository.watchRuns().listen(
      (runs) {
        final keep =
            state.pinned && runs.any((run) => run.id == state.selectedRunId);
        final selected = keep ? state.selectedRunId : runs.firstOrNull?.id;
        final changed = selected != state.selectedRunId;
        emit(
          AgentTraceState(
            status: AgentTraceStatus.ready,
            runs: runs,
            selectedRunId: selected,
            pinned: keep,
            steps: changed ? const [] : state.steps,
            flagCount: changed ? 0 : state.flagCount,
            rainCheck: state.rainCheck,
            result: state.result,
          ),
        );
        if (changed && selected != null) _follow(selected);
      },
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(
          AgentTraceState(
            status:
                error is OrganiserFailure &&
                    error.reason == OrganiserFailureReason.forbidden
                ? AgentTraceStatus.forbidden
                : AgentTraceStatus.failure,
          ),
        );
      },
    );
  }

  /// Shows run [runId]'s steps; an older run stays shown when a new one
  /// lands.
  void runTapped(String runId) {
    if (runId == state.selectedRunId) return;
    emit(
      AgentTraceState(
        status: state.status,
        runs: state.runs,
        selectedRunId: runId,
        pinned: runId != state.runs.firstOrNull?.id,
        rainCheck: state.rainCheck,
        result: state.result,
      ),
    );
    _follow(runId);
  }

  void _follow(String runId) {
    unawaited(_steps?.cancel());
    unawaited(_flags?.cancel());
    _steps = _organiserRepository
        .watchSteps(runId)
        .listen(
          (steps) => emit(state.copyWith(steps: steps)),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(state.copyWith(status: AgentTraceStatus.failure));
          },
        );
    if (state.selectedRun case final run?) {
      _flags = _organiserRepository
          .watchFlagCount(run.rondaId)
          .listen(
            (count) => emit(state.copyWith(flagCount: count)),
            onError: addError,
          );
    }
  }

  /// "Correr el chequeo de lluvia", or with [atNight] "Probar a las 22:00":
  /// the server's gates hold whatever the program would send at that hour.
  Future<void> rainCheckTapped({bool atNight = false}) async {
    if (state.rainCheck == RainCheckStatus.running) return;
    emit(state.copyWith(rainCheck: RainCheckStatus.running));
    final today = _now();
    try {
      final result = await _organiserRepository.runRainCheck(
        at: atNight
            ? DateTime(today.year, today.month, today.day, nightHour)
            : null,
      );
      emit(state.copyWith(rainCheck: RainCheckStatus.done, result: result));
    } on OrganiserFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(state.copyWith(rainCheck: RainCheckStatus.failed));
    }
  }

  @override
  Future<void> close() async {
    await _runs?.cancel();
    await _steps?.cancel();
    await _flags?.cancel();
    await super.close();
  }
}
