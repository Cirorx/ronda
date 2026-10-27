import 'package:auth_repository/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/app_bloc_observer.dart';
import 'package:ronda/bootstrap.dart';
import 'package:ronda/firebase_options_development.dart';

/// The host running the emulators, as this device sees it. Override with
/// `--dart-define=FIREBASE_EMULATOR_HOST=…` (a USB phone after
/// `adb reverse`: 127.0.0.1); see docs/STACK.md § Native and project
/// checklist.
String _emulatorHost() {
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  if (host.isNotEmpty) return host;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // The Android emulator's alias for the Mac's loopback.
    return '10.0.2.2';
  }
  return 'localhost';
}

/// Signs in on phones with `signInWithProvider`, which opens the Auth
/// emulator's account picker in a browser tab. Pass
/// `--dart-define=EMULATOR_GOOGLE_CREDENTIAL=true` to skip the picker and
/// sign in as the fixed demo account instead (Maestro, CI-like runs).
GoogleSignInFlow _googleSignInFlow() {
  if (kIsWeb) return GoogleSignInFlow.popup;
  const useCredential = bool.fromEnvironment('EMULATOR_GOOGLE_CREDENTIAL');
  return useCredential
      ? GoogleSignInFlow.emulatorCredential
      : GoogleSignInFlow.provider;
}

Future<void> main() async {
  await bootstrap(
    ({required authRepository, required needsRepository}) =>
        App(authRepository: authRepository, needsRepository: needsRepository),
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    googleSignInFlow: _googleSignInFlow(),
    emulators: FirebaseEmulators(host: _emulatorHost()),
    blocObserver: const AppBlocObserver(),
  );
}
