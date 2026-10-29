import 'package:auth_repository/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/bootstrap.dart';
import 'package:ronda/firebase_options_production.dart';

/// "Voy" or "Esta no" tapped on the weekly push.
@pragma('vm:entry-point')
Future<void> answerRsvpFromNotification(NotificationResponse response) =>
    answerRsvpInBackground(
      response,
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    );

Future<void> main() async {
  await bootstrap(
    ({
      required authRepository,
      required flyerRepository,
      required needsRepository,
      required onboardingRepository,
      required profileRepository,
      required pushRepository,
      required rondaRepository,
    }) => App(
      authRepository: authRepository,
      flyerRepository: flyerRepository,
      needsRepository: needsRepository,
      onboardingRepository: onboardingRepository,
      profileRepository: profileRepository,
      pushRepository: pushRepository,
      rondaRepository: rondaRepository,
    ),
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    // Production never takes GoogleSignInFlow.emulatorCredential.
    googleSignInFlow: kIsWeb
        ? GoogleSignInFlow.popup
        : GoogleSignInFlow.provider,
    onRsvpAction: answerRsvpFromNotification,
  );
}
