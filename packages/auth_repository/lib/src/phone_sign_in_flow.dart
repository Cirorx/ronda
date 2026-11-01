/// How `AuthRepository.sendPhoneCode` sends the code. Bootstrap picks one
/// per platform; the repository never looks at the platform itself.
enum PhoneSignInFlow {
  /// `signInWithPhoneNumber` with an invisible reCAPTCHA: the web. The
  /// Auth emulator skips the reCAPTCHA.
  confirmation,

  /// `verifyPhoneNumber`: Android (Play Integrity, or a reCAPTCHA tab when
  /// it fails, and the SMS read automatically when the phone can) and iOS
  /// (a silent push, or a reCAPTCHA tab without APNs).
  verify,
}
