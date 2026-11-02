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

/// {@template admin_claim_failure}
/// Thrown by `AuthRepository.hasAdminClaim` when the ID token can't be read,
/// offline say, while forcing a refresh.
/// {@endtemplate}
class const AdminClaimFailure() implements Exception {
  /// {@macro admin_claim_failure}
  this;
}

/// {@template open_create_account_failure}
/// Thrown by `AuthRepository.openCreateAccount` when no browser opens
/// Google's page to make an account.
/// {@endtemplate}
class const OpenCreateAccountFailure() implements Exception {
  /// {@macro open_create_account_failure}
  this;
}

/// Why no code went out by SMS.
enum SendPhoneCodeFailureReason {
  /// Firebase Auth refused the number.
  invalidNumber,

  /// This phone or number asked for too many codes; Firebase Auth blocks it
  /// for a while.
  tooManyRequests,

  /// Asked again before `PhoneVerification.resendAvailableAt`, or after the
  /// last resend. Nothing was sent.
  tooSoon,

  /// SMS can't go out now: the project's quota, a region the SMS policy
  /// doesn't allow, or an app check that failed.
  unavailable,

  /// The person closed the reCAPTCHA tab: not an error to show.
  cancelled,

  /// No connection, or the request timed out.
  network,

  /// Anything else; details stay out of the UI and the logs.
  unknown,
}

/// {@template send_phone_code_failure}
/// Thrown by `AuthRepository.sendPhoneCode` when no code goes out.
/// {@endtemplate}
class const SendPhoneCodeFailure([
  /// Why no code went out.
  final SendPhoneCodeFailureReason reason = SendPhoneCodeFailureReason.unknown,
]) implements Exception {
  /// {@macro send_phone_code_failure}
  this;

  /// Maps a Firebase Auth error [code] to a failure.
  factory fromCode(String code) => switch (code) {
    'invalid-phone-number' || 'missing-phone-number' =>
      const SendPhoneCodeFailure(SendPhoneCodeFailureReason.invalidNumber),
    'too-many-requests' => const SendPhoneCodeFailure(
      SendPhoneCodeFailureReason.tooManyRequests,
    ),
    'quota-exceeded' ||
    'operation-not-allowed' ||
    'app-not-authorized' ||
    'invalid-app-credential' ||
    'missing-client-identifier' ||
    'captcha-check-failed' => const SendPhoneCodeFailure(
      SendPhoneCodeFailureReason.unavailable,
    ),
    'web-context-cancelled' || 'web-context-canceled' || 'user-cancelled' =>
      const SendPhoneCodeFailure(SendPhoneCodeFailureReason.cancelled),
    'network-request-failed' ||
    'timeout' => const SendPhoneCodeFailure(SendPhoneCodeFailureReason.network),
    _ => const SendPhoneCodeFailure(),
  };

  @override
  String toString() => 'SendPhoneCodeFailure($reason)';
}

/// Why the typed code did not sign the person in.
enum ConfirmPhoneCodeFailureReason {
  /// Not the code that was sent.
  invalidCode,

  /// The code is too old; a new one is needed.
  expired,

  /// Too many tries; Firebase Auth blocks it for a while.
  tooManyRequests,

  /// No connection, or the request timed out.
  network,

  /// The account is disabled in Firebase Auth.
  userDisabled,

  /// Anything else; details stay out of the UI and the logs.
  unknown,
}

/// {@template confirm_phone_code_failure}
/// Thrown by `AuthRepository.confirmPhoneCode` when the code does not sign
/// the person in.
/// {@endtemplate}
class const ConfirmPhoneCodeFailure([
  /// Why the code did not sign the person in.
  final ConfirmPhoneCodeFailureReason reason =
      ConfirmPhoneCodeFailureReason.unknown,
]) implements Exception {
  /// {@macro confirm_phone_code_failure}
  this;

  /// Maps a Firebase Auth error [code] to a failure.
  factory fromCode(String code) => switch (code) {
    'invalid-verification-code' || 'missing-verification-code' =>
      const ConfirmPhoneCodeFailure(ConfirmPhoneCodeFailureReason.invalidCode),
    'session-expired' || 'code-expired' || 'invalid-verification-id' =>
      const ConfirmPhoneCodeFailure(ConfirmPhoneCodeFailureReason.expired),
    'too-many-requests' => const ConfirmPhoneCodeFailure(
      ConfirmPhoneCodeFailureReason.tooManyRequests,
    ),
    'network-request-failed' || 'timeout' => const ConfirmPhoneCodeFailure(
      ConfirmPhoneCodeFailureReason.network,
    ),
    'user-disabled' => const ConfirmPhoneCodeFailure(
      ConfirmPhoneCodeFailureReason.userDisabled,
    ),
    _ => const ConfirmPhoneCodeFailure(),
  };

  @override
  String toString() => 'ConfirmPhoneCodeFailure($reason)';
}
