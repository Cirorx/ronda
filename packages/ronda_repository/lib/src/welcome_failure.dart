/// Why reading or saving who waits for a newcomer failed.
enum WelcomeFailureReason {
  /// The recognition line has an emoji.
  emoji,

  /// The recognition line isn't in voseo.
  voseo,

  /// The recognition line talks about money.
  money,

  /// The recognition line looks like a home or an address.
  notPublic,

  /// The meeting started, or the pick is no longer the caller's to change.
  passed,

  /// Anything else: no connection, a server error, a document of another
  /// shape.
  other,
}

/// {@template welcome_failure}
/// Reading a newcomer's welcome, picking who waits for them, or saying
/// "No puedo" failed.
/// {@endtemplate}
class const WelcomeFailure(final WelcomeFailureReason reason)
    implements Exception {
  /// {@macro welcome_failure}
  this;
}
