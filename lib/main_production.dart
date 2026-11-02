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
      required cuadernoRepository,
      required dondeQuedaRepository,
      required flyerRepository,
      required needsRepository,
      required onboardingRepository,
      required organiserRepository,
      required profileRepository,
      required pushRepository,
      required rondaRepository,
      required safetyRepository,
      required smallPlanRepository,
      required walkthroughSeen,
      required language,
    }) => App(
      authRepository: authRepository,
      contactRepository: contactRepository,
      cuadernoRepository: cuadernoRepository,
      dondeQuedaRepository: dondeQuedaRepository,
      flyerRepository: flyerRepository,
      needsRepository: needsRepository,
      onboardingRepository: onboardingRepository,
      organiserRepository: organiserRepository,
      profileRepository: profileRepository,
      pushRepository: pushRepository,
      rondaRepository: rondaRepository,
      safetyRepository: safetyRepository,
      smallPlanRepository: smallPlanRepository,
      walkthroughSeen: walkthroughSeen,
      language: language,
    ),
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    // Production never takes GoogleSignInFlow.emulatorCredential.
    googleSignInFlow: kIsWeb
        ? GoogleSignInFlow.popup
        : GoogleSignInFlow.provider,
    onRsvpAction: answerRsvpFromNotification,
  );
}
