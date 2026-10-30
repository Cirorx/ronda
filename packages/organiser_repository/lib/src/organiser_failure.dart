/// Why an organiser read or call failed.
enum OrganiserFailureReason {
  /// The server refused the account: not the admin, not a member of that
  /// ronda, or not its host.
  forbidden,

  /// The time for it passed: the host picked after the deadline.
  late,

  /// Anything else: no connection, a server error, a document of another
  /// shape.
  other,
}

/// {@template organiser_failure}
/// Reading the trace, the acta or a rain proposal, or answering one, failed.
/// {@endtemplate}
class const OrganiserFailure(final OrganiserFailureReason reason)
    implements Exception {
  /// {@macro organiser_failure}
  this;
}
