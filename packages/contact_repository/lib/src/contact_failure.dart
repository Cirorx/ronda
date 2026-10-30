/// {@template contact_failure}
/// The phone found no app to write the mail or place the call, or the app
/// failed to open. It carries no detail: the person is shown the address or
/// the number instead.
/// {@endtemplate}
class ContactFailure implements Exception {
  /// {@macro contact_failure}
  const new();
}
