/// {@template accept_terms_failure}
/// Recording the accepted conditions on `users/{uid}` failed.
/// {@endtemplate}
class AcceptTermsFailure implements Exception {
  /// {@macro accept_terms_failure}
  const new();
}

/// {@template save_profile_failure}
/// Saving the profile on `users/{uid}` failed.
/// {@endtemplate}
class SaveProfileFailure implements Exception {
  /// {@macro save_profile_failure}
  const new();
}
