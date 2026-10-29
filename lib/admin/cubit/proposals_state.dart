part of 'proposals_cubit.dart';

/// Whether the screen can show a proposal.
enum ProposalsStatus {
  /// Reading the newest proposal.
  loading,

  /// Read: [ProposalsState.proposal] is the newest one, or `null` if none.
  ready,

  /// The account has no admin claim.
  forbidden,

  /// The read failed for another reason.
  failure,
}

/// The step the admin asked for, while it runs.
enum ProposalsAction { none, proposing, approving, undoing }

final class const ProposalsState({
  final ProposalsStatus status = ProposalsStatus.loading,
  final Proposal? proposal,
  final ProposalsAction action = ProposalsAction.none,

  /// Whether the last step the admin asked for failed.
  final bool actionFailed = false,
}) extends Equatable {
  /// Whether a step is running, so every button waits.
  bool get busy => action != ProposalsAction.none;

  @override
  List<Object?> get props => [status, proposal, action, actionFailed];
}
