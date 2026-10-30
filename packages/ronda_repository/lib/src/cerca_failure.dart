/// {@template cerca_failure}
/// Cerca tuyo's counts could not be read: no connection, a server error, or
/// no answer in time.
/// {@endtemplate}
class CercaFailure implements Exception {
  /// {@macro cerca_failure}
  const new();
}
