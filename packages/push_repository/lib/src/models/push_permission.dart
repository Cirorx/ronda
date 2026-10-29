/// Whether Ronda may send this phone notifications.
enum PushPermission {
  /// Allowed.
  allowed,

  /// Never asked: the system's prompt shows on the next ask.
  notAsked,

  /// Refused once; the system will still show its prompt again.
  refused,

  /// Refused for good: only the phone's settings turn it back on.
  blocked,
}
