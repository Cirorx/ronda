/// Why setting a ronda up or recording attendance failed.
enum HostsFailureReason {
  /// The server refused the account: not the admin, or not a host.
  forbidden,

  /// The place's words look like a home or an address: the ronda meets in
  /// public places only.
  notPublic,

  /// The meeting is too long ago to record.
  passed,

  /// Anything else: no connection, a server error, a document of another
  /// shape.
  other,
}

/// {@template hosts_failure}
/// Reading or setting a ronda's place, hour and hosts, or its roll, failed.
/// {@endtemplate}
class const HostsFailure(final HostsFailureReason reason) implements Exception {
  /// {@macro hosts_failure}
  this;
}
