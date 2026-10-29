import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'proposals_state.dart';

/// The admin's approval screen: follows the newest proposal, asks the
/// solver for a new one, approves it into rondas and takes that back.
///
/// The server decides who is admin; a refusal from it shows as
/// [ProposalsStatus.forbidden].
class ProposalsCubit extends Cubit<ProposalsState> {
  new({required this._rondaRepository}) : super(const ProposalsState());

  final RondaRepository _rondaRepository;
  StreamSubscription<Proposal?>? _subscription;

  /// Follows the newest proposal.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const ProposalsState());
    _subscription = _rondaRepository.watchLatestProposal().listen(
      (proposal) => emit(
        ProposalsState(
          status: ProposalsStatus.ready,
          proposal: proposal,
          action: state.action,
        ),
      ),
      onError: (Object error) => emit(_refused(error)),
    );
  }

  /// Runs the solver on the current sign-ups. The new proposal arrives
  /// through the subscription.
  Future<void> propose() =>
      _run(ProposalsAction.proposing, _rondaRepository.proposeGroups);

  /// Approves the shown proposal, which writes its rondas.
  Future<void> approve() async {
    if (state.proposal case Proposal(
      :final id,
      status: ProposalStatus.pending,
    )) {
      await _run(
        ProposalsAction.approving,
        () => _rondaRepository.approveProposal(id),
      );
    }
  }

  /// Takes back the approval of the shown proposal.
  Future<void> undo() async {
    if (state.proposal case Proposal(
      :final id,
      status: ProposalStatus.approved,
    )) {
      await _run(
        ProposalsAction.undoing,
        () => _rondaRepository.undoApproval(id),
      );
    }
  }

  Future<void> _run(
    ProposalsAction action,
    Future<void> Function() step,
  ) async {
    if (state.busy || state.status != ProposalsStatus.ready) return;
    emit(_with(action: action));
    try {
      await step();
      emit(_with(action: ProposalsAction.none));
    } on ProposalsFailure catch (failure) {
      emit(
        failure.reason == ProposalsFailureReason.forbidden
            ? _refused(failure)
            : _with(action: ProposalsAction.none, actionFailed: true),
      );
    }
  }

  ProposalsState _with({
    required ProposalsAction action,
    bool actionFailed = false,
  }) => ProposalsState(
    status: state.status,
    proposal: state.proposal,
    action: action,
    actionFailed: actionFailed,
  );

  static ProposalsState _refused(Object error) => ProposalsState(
    status:
        error is ProposalsFailure &&
            error.reason == ProposalsFailureReason.forbidden
        ? ProposalsStatus.forbidden
        : ProposalsStatus.failure,
  );

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
