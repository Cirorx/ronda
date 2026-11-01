part of 'shared_plans_cubit.dart';

/// Whether the ronda's plans have been read.
enum SharedPlansStatus {
  /// Reading.
  loading,

  /// Read; [SharedPlansState.plans] holds them.
  ready,

  /// They couldn't be read; the screen shows nothing rather than an error.
  failure,
}

/// What went wrong on the last tap, so the screen can say it in plain words.
enum SharedPlansProblem {
  /// The plan couldn't be opened or taken back: the connection failed.
  shareFailed,

  /// "Me sumo" or taking it back didn't go through.
  joinFailed,

  /// The plan someone tried to join is over or was withdrawn.
  planGone,
}

final class const SharedPlansState({
  final SharedPlansStatus status = SharedPlansStatus.loading,

  /// The others' plans and this member's own, once read.
  final SharedPlans plans = const SharedPlans(),

  /// Opening or taking back the member's own plan is on its way.
  final bool sharing = false,

  /// The author whose plan "Me sumo" is being said or taken back for.
  final String? joining,

  /// Why the last plan was not opened to the ronda; it stays private.
  final ShareHoldReason? held,

  /// What went wrong on the last tap, if anything.
  final SharedPlansProblem? problem,
}) extends Equatable {
  /// A copy with the given fields changed. [held] and [problem] are
  /// replaced, so a call without them clears them.
  SharedPlansState copyWith({
    SharedPlansStatus? status,
    SharedPlans? plans,
    bool? sharing,
    String? Function()? joining,
    ShareHoldReason? held,
    SharedPlansProblem? problem,
  }) => SharedPlansState(
    status: status ?? this.status,
    plans: plans ?? this.plans,
    sharing: sharing ?? this.sharing,
    joining: joining == null ? this.joining : joining(),
    held: held,
    problem: problem,
  );

  @override
  List<Object?> get props => [status, plans, sharing, joining, held, problem];
}
