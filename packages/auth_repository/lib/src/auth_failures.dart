/// Why signing in with Google did not finish.
enum SignInWithGoogleFailureReason {
  /// The person closed the picker or went back: not an error to show.
  cancelled,

  /// No connection, or the request timed out.
  network,

  /// The account is disabled in Firebase Auth.
  userDisabled,

  /// Anything else; details stay out of the UI and the logs.
  unknown,
}

/// {@template sign_in_with_google_failure}
/// Thrown by `AuthRepository.signInWithGoogle` when sign-in does not finish.
/// {@endtemplate}
class const SignInWithGoogleFailure([
  /// Why sign-in did not finish.
  final SignInWithGoogleFailureReason reason =
      SignInWithGoogleFailureReason.unknown,
]) implements Exception {
  /// {@macro sign_in_with_google_failure}
  this;

  /// Maps a Firebase Auth error [code] to a failure.
  factory fromCode(String code) => switch (code) {
    'popup-closed-by-user' ||
    'cancelled-popup-request' ||
    'web-context-cancelled' ||
    'web-context-canceled' ||
    'user-cancelled' ||
    'canceled' => const SignInWithGoogleFailure(
      SignInWithGoogleFailureReason.cancelled,
    ),
    'network-request-failed' || 'timeout' => const SignInWithGoogleFailure(
      SignInWithGoogleFailureReason.network,
    ),
    'user-disabled' => const SignInWithGoogleFailure(
      SignInWithGoogleFailureReason.userDisabled,
    ),
    _ => const SignInWithGoogleFailure(),
  };

  @override
  String toString() => 'SignInWithGoogleFailure($reason)';
}

/// {@template sign_out_failure}
/// Thrown by `AuthRepository.signOut` when signing out fails.
/// {@endtemplate}
class const SignOutFailure() implements Exception {
  /// {@macro sign_out_failure}
  this;
}
