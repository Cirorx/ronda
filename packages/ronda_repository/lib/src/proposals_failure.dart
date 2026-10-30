/// Why a step on the proposals failed.
enum ProposalsFailureReason {
  /// The account has no admin claim: the rules or the callable refused it.
  forbidden,

  /// "Sumar a esta ronda": the ronda has no seat left.
  full,

  /// "Sumar a esta ronda": they are already in it.
  alreadyIn,

  /// Anything else: no connection, a server error, a document of another
  /// shape.
  other,
}

/// {@template proposals_failure}
/// Reading, proposing, approving or undoing failed, or adding someone to a
/// ronda, or reading the pilot's numbers.
/// {@endtemplate}
class const ProposalsFailure(final ProposalsFailureReason reason)
    implements Exception {
  /// {@macro proposals_failure}
  this;
}
