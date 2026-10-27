/// How [signInWithGoogle] reaches Google. Bootstrap picks one per platform
/// and flavor; the repository never looks at the platform itself.
///
/// [signInWithGoogle]: AuthRepository.signInWithGoogle
enum GoogleSignInFlow {
  /// `signInWithPopup`: the web. Against the Auth emulator the popup is the
  /// emulator's own account picker.
  popup,

  /// `signInWithProvider`: Android and iOS, through a browser tab. Against
  /// the Auth emulator the tab opens the emulator's account picker.
  provider,

  /// `signInWithCredential` with an unsigned JSON id token for a fixed demo
  /// account. Only the Auth emulator accepts such a token (the real project
  /// rejects it), and only the development entrypoint can pick this flow.
  emulatorCredential,
}
