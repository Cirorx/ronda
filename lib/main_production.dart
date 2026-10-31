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
    // Production never takes GoogleSignInFlow.emulatorCredential.
    googleSignInFlow: kIsWeb
        ? GoogleSignInFlow.popup
        : GoogleSignInFlow.provider,
    onRsvpAction: answerRsvpFromNotification,
  );
}
