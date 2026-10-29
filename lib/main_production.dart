import 'package:auth_repository/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/bootstrap.dart';
import 'package:ronda/firebase_options_production.dart';

Future<void> main() async {
  await bootstrap(
    ({
      required authRepository,
      required needsRepository,
      required onboardingRepository,
      required profileRepository,
      required rondaRepository,
    }) => App(
      authRepository: authRepository,
      needsRepository: needsRepository,
      onboardingRepository: onboardingRepository,
      profileRepository: profileRepository,
      rondaRepository: rondaRepository,
    ),
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    // Production never takes GoogleSignInFlow.emulatorCredential.
    googleSignInFlow: kIsWeb
        ? GoogleSignInFlow.popup
        : GoogleSignInFlow.provider,
  );
}
