import 'package:auth_repository/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

/// The emulators as this device sees them. A second functions emulator
/// beside the main one is reached with
/// `--dart-define=FIREBASE_FUNCTIONS_PORT=…`.
FirebaseEmulators _emulators() => FirebaseEmulators(
  host: _emulatorHost(),
  // Equal to the default only while no port is defined.
  // ignore: avoid_redundant_argument_values
  functionsPort: const int.fromEnvironment(
    'FIREBASE_FUNCTIONS_PORT',
    defaultValue: FirebaseEmulators.defaultFunctionsPort,
  ),
);

/// "Voy" or "Esta no" tapped on the weekly push, against the emulators.
@pragma('vm:entry-point')
Future<void> answerRsvpFromNotification(NotificationResponse response) =>
    answerRsvpInBackground(
      response,
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      emulators: _emulators(),
    );

/// Signs in with the Auth emulator's account picker: a popup on web,
/// `signInWithProvider` in a browser tab on phones. Pass
/// `--dart-define=EMULATOR_GOOGLE_CREDENTIAL=true` to skip the picker and
/// sign in as the fixed demo account instead (Maestro, browsers that block
/// popups, CI-like runs).
GoogleSignInFlow _googleSignInFlow() {
  const useCredential = bool.fromEnvironment('EMULATOR_GOOGLE_CREDENTIAL');
  if (useCredential) return GoogleSignInFlow.emulatorCredential;
  return kIsWeb ? GoogleSignInFlow.popup : GoogleSignInFlow.provider;
}

Future<void> main() async {
  await bootstrap(
    ({
      required authRepository,
      required contactRepository,
      required flyerRepository,
      required needsRepository,
      required onboardingRepository,
      required organiserRepository,
      required profileRepository,
      required pushRepository,
      required rondaRepository,
      required walkthroughSeen,
    }) => App(
      authRepository: authRepository,
      contactRepository: contactRepository,
      flyerRepository: flyerRepository,
      needsRepository: needsRepository,
      onboardingRepository: onboardingRepository,
      organiserRepository: organiserRepository,
      profileRepository: profileRepository,
      pushRepository: pushRepository,
      rondaRepository: rondaRepository,
      walkthroughSeen: walkthroughSeen,
    ),
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    googleSignInFlow: _googleSignInFlow(),
    emulators: _emulators(),
    blocObserver: AppBlocObserver(),
    onRsvpAction: answerRsvpFromNotification,
  );
}
