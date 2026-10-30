part of 'agent_trace_cubit.dart';

/// Whether the trace can show the runs.
enum AgentTraceStatus {
  /// Reading.
  loading,

  /// [AgentTraceState.runs] are the newest runs.
  ready,

  /// The account isn't the admin.
  forbidden,

  /// The trace couldn't be read.
  failure,
}

/// Where "Correr el chequeo de lluvia" stands.
enum RainCheckStatus {
  /// Not run from here yet.
  idle,

  /// Running.
  running,

  /// Ran: [AgentTraceState.result] says what it did.
  done,

  /// The call failed.
  failed,
}

final class const AgentTraceState({
  final AgentTraceStatus status = AgentTraceStatus.loading,

  /// The newest runs, newest first.
  final List<AgentRun> runs = const [],

  /// The run whose steps show.
  final String? selectedRunId,

  /// Whether the admin picked an older run, so a new one doesn't take its
  /// place.
  final bool pinned = false,

  /// The selected run's steps, in order.
  final List<AgentStep> steps = const [],

  /// How many members of the selected run's ronda tapped
  /// [Algo estuvo mal].
  final int flagCount = 0,

  /// The rain check run from this screen.
  final RainCheckStatus rainCheck = RainCheckStatus.idle,

  /// What it did, once [rainCheck] is [RainCheckStatus.done].
  final RainCheckResult? result,
}) extends Equatable {
  /// The run whose steps show, if any.
  AgentRun? get selectedRun =>
      runs.where((run) => run.id == selectedRunId).firstOrNull;

  AgentTraceState copyWith({
    AgentTraceStatus? status,
    List<AgentRun>? runs,
    String? selectedRunId,
    bool? pinned,
    List<AgentStep>? steps,
    int? flagCount,
    RainCheckStatus? rainCheck,
    RainCheckResult? result,
  }) => AgentTraceState(
    status: status ?? this.status,
    runs: runs ?? this.runs,
    selectedRunId: selectedRunId ?? this.selectedRunId,
    pinned: pinned ?? this.pinned,
    steps: steps ?? this.steps,
    flagCount: flagCount ?? this.flagCount,
    rainCheck: rainCheck ?? this.rainCheck,
    result: result ?? this.result,
  );

  @override
  List<Object?> get props => [
    status,
    runs,
    selectedRunId,
    pinned,
    steps,
    flagCount,
    rainCheck,
    result,
  ];
}
