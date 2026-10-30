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

/// {@template read_published_seats_failure}
/// Reading the seats the server publishes failed.
/// {@endtemplate}
class ReadPublishedSeatsFailure implements Exception {
  /// {@macro read_published_seats_failure}
  const new();
}

/// {@template save_eligible_seat_ids_failure}
/// Writing `users/{uid}/private/eligible` failed.
/// {@endtemplate}
class SaveEligibleSeatIdsFailure implements Exception {
  /// {@macro save_eligible_seat_ids_failure}
  const new();
}

/// {@template hold_on_phone_failure}
/// Keeping the conditions or the onboarding answers on this phone until
/// sign-in, or deleting them, failed.
/// {@endtemplate}
class HoldOnPhoneFailure implements Exception {
  /// {@macro hold_on_phone_failure}
  const new();
}
