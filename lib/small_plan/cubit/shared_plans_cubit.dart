import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

part 'shared_plans_state.dart';

/// ¿Alguien se suma? on Mi ronda, for ronda [_rondaId]: follows the others'
/// plans and [_uid]'s own, opens the member's plan to the ronda when they
/// turn "Avisarle a la ronda" on and takes it back when they turn it off,
/// and says "Me sumo" for them. Nothing here sends a notification: people see
/// a plan when they open Mi ronda.
class SharedPlansCubit extends Cubit<SharedPlansState> implements StepNamed {
  new({
    required this._rondaId,
    required this._uid,
    required this._smallPlanRepository,
  }) : super(const SharedPlansState());

  final String _rondaId;
  final String _uid;
  final SmallPlanRepository _smallPlanRepository;
  StreamSubscription<SharedPlans>? _subscription;

  /// Follows the ronda's plans.
  void subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _smallPlanRepository
        .watchShared(rondaId: _rondaId, uid: _uid)
        .listen(
          (plans) => emit(
            state.copyWith(
              status: SharedPlansStatus.ready,
              plans: plans,
              held: state.held,
              problem: state.problem,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(state.copyWith(status: SharedPlansStatus.failure));
          },
        );
  }

  /// "Avisarle a la ronda" turned on: opens [plan], worded as [what], to the
  /// ronda. When a check holds it, the reason shows and the plan stays
  /// private.
  Future<void> shareTapped(SmallPlan plan, String what) async {
    if (state.sharing) return;
    emit(state.copyWith(sharing: true));
    try {
      await _smallPlanRepository.share(
        rondaId: _rondaId,
        plan: plan,
        what: what,
      );
      if (!isClosed) emit(state.copyWith(sharing: false));
    } on SharedPlanHeld catch (held) {
      if (!isClosed) emit(state.copyWith(sharing: false, held: held.reason));
    } on SmallPlanFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            sharing: false,
            problem: SharedPlansProblem.shareFailed,
          ),
        );
      }
    }
  }

  /// "Avisarle a la ronda" turned off: the plan is taken back, with every
  /// "Me sumo", and nobody hears about it.
  Future<void> withdrawTapped() async {
    if (state.sharing) return;
    emit(state.copyWith(sharing: true));
    await _withdraw();
  }

  /// The member's plan was replaced by another: what was opened to the ronda
  /// is taken back, quietly. Does nothing when nothing was opened.
  Future<void> planChanged() async {
    if (state.plans.mine == null) return;
    await _withdraw();
  }

  Future<void> _withdraw() async {
    try {
      await _smallPlanRepository.withdraw(_rondaId);
      if (!isClosed) emit(state.copyWith(sharing: false));
    } on SmallPlanFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            sharing: false,
            problem: SharedPlansProblem.shareFailed,
          ),
        );
      }
    }
  }

  /// [Me sumo] on [authorUid]'s plan.
  Future<void> joinTapped(String authorUid) =>
      _join(authorUid, _smallPlanRepository.join);

  /// "Ya no voy": takes "Me sumo" on [authorUid]'s plan back.
  Future<void> leaveTapped(String authorUid) =>
      _join(authorUid, _smallPlanRepository.leave);

  Future<void> _join(
    String authorUid,
    Future<void> Function({required String rondaId, required String authorUid})
    call,
  ) async {
    if (state.joining != null) return;
    emit(state.copyWith(joining: () => authorUid));
    try {
      await call(rondaId: _rondaId, authorUid: authorUid);
      if (!isClosed) emit(state.copyWith(joining: () => null));
    } on SmallPlanFailure catch (failure, stackTrace) {
      if (failure.kind != SmallPlanFailureKind.planGone) {
        addError(failure, stackTrace);
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            joining: () => null,
            problem: failure.kind == SmallPlanFailureKind.planGone
                ? SharedPlansProblem.planGone
                : SharedPlansProblem.joinFailed,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }

  @override
  String get reportStep => 'SharedPlansCubit';
}
