/// Why a step on the proposals failed.
enum ProposalsFailureReason {
  /// The account has no admin claim: the rules or the callable refused it.
  forbidden,

  /// Anything else: no connection, a server error, a document of another
  /// shape.
  other,
}

/// {@template proposals_failure}
/// Reading, proposing, approving or undoing failed.
/// {@endtemplate}
class const ProposalsFailure(final ProposalsFailureReason reason)
    implements Exception {
  /// {@macro proposals_failure}
  this;
}
