/// Why a weekly-loop step failed.
enum RsvpFailureReason {
  /// The server refused the account: not in that ronda, or not the admin.
  forbidden,

  /// The meeting it answered has passed (an old notification).
  passed,

  /// Anything else: no connection, a server error, a document of another
  /// shape.
  other,
}

/// {@template rsvp_failure}
/// Reading the week, answering or sending the RSVP failed.
/// {@endtemplate}
class const RsvpFailure(final RsvpFailureReason reason) implements Exception {
  /// {@macro rsvp_failure}
  this;
}
