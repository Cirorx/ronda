/// Why a safety read or call failed.
enum SafetyFailureReason {
  /// The server refused the account: not the admin, or not the reporter.
  forbidden,

  /// Too many reports today, or a report that takes no more.
  tooMany,

  /// The step no longer applies: the report was withdrawn, the person is
  /// already out, the pair is no longer separated.
  gone,

  /// Anything else: no connection, a server error, a document of another
  /// shape.
  other,
}

/// {@template safety_failure}
/// Reading or sending a report, or acting on one, failed.
/// {@endtemplate}
class const SafetyFailure(final SafetyFailureReason reason)
    implements Exception {
  /// {@macro safety_failure}
  this;
}
