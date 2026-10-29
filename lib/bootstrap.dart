import 'dart:async';
import 'dart:developer';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_store/device_store.dart';
import 'package:face_blur/face_blur.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:push_client/push_client.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:share_sheet/share_sheet.dart';
import 'package:voice_recorder/voice_recorder.dart';

/// Builds the root widget from the repositories bootstrap constructs.
typedef AppBuilder = FutureOr<Widget> Function({
  required AuthRepository authRepository,
  required FlyerRepository flyerRepository,
  required NeedsRepository needsRepository,
  required OnboardingRepository onboardingRepository,
  required ProfileRepository profileRepository,
  required PushRepository pushRepository,
  required RondaRepository rondaRepository,
});

/// Where every Ronda function and callable runs (`docs/STACK.md` gotcha 3).
const functionsRegion = 'southamerica-east1';

/// The local Firebase emulators the development flavor talks to. The ports
/// match `firebase.json`.
class const FirebaseEmulators({
  /// The machine running `firebase emulators:start`, as this device sees it.
  required final String host,
}) {
  /// Auth emulator port.
  static const authPort = 9099;

  /// Firestore emulator port (8080 is often taken by web dev servers).
  static const firestorePort = 8088;

  /// Functions emulator port.
  static const functionsPort = 5001;

  /// Storage emulator port.
  static const storagePort = 9199;
}

/// The web push certificate's public key, passed as
/// `--dart-define=FCM_VAPID_KEY=…` (`docs/STACK.md` § Push). It is public by
/// design: browsers receive it to subscribe. Empty until the owner creates
/// it in the console; without it web uses Firebase's default key, if any.
const fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Shows a data-only push that arrived while the app was in the background
/// or closed (Android). FCM runs it in its own isolate, so it starts Firebase
/// again before anything else.
@pragma('vm:entry-point')
Future<void> showPushInBackground(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushClient(
    messaging: FirebaseMessaging.instance,
    notifications: FlutterLocalNotificationsPlugin(),
  ).showMessage(message);
}

/// Starts Firebase, builds the data clients and repositories, then runs the
/// app built by [builder].
///
/// [firebaseOptions] come from the flavor's generated options file. When
/// [emulators] is given (development only) every Firebase client talks to
/// the local emulators instead of the real project. [googleSignInFlow] says
/// how this platform reaches Google. [blocObserver] is installed only when
/// given: the development entrypoint passes `AppBlocObserver`, production
/// passes nothing.
Future<void> bootstrap(
  AppBuilder builder, {
  required FirebaseOptions firebaseOptions,
  required GoogleSignInFlow googleSignInFlow,
  FirebaseEmulators? emulators,
  BlocObserver? blocObserver,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  if (blocObserver != null) Bloc.observer = blocObserver;

  // Clean URLs on web (/ronda instead of /#/ronda); a no-op elsewhere.
  usePathUrlStrategy();

  // The OFL notices of the fonts ronda_ui bundles, for the licence page.
  registerRondaUiLicenses();

  await Firebase.initializeApp(options: firebaseOptions);

  // Data layer
  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
  final storage = FirebaseStorage.instance;
  const deviceStore = DeviceStore();
  final proposalsApi = ProposalsApi(firestore: firestore, functions: functions);
  final rondaApi = RondaApi(
    firestore: firestore,
    storage: storage,
    functions: functions,
  );
  final voiceRecorder = VoiceRecorder();
  // ML Kit is built on the first detection, which never happens on web.
  final faceBlur = FaceBlur();
  final flyersApi = FlyersApi(storage: storage, functions: functions);
  final shareSheet = ShareSheet();
  final pushClient = PushClient(
    messaging: FirebaseMessaging.instance,
    notifications: FlutterLocalNotificationsPlugin(),
    vapidKey: fcmVapidKey,
  );

  // Push: there is no FCM emulator, so even the development flavor gets its
  // token from the real project; the token is then saved in the emulator.
  if (!kIsWeb) FirebaseMessaging.onBackgroundMessage(showPushInBackground);
  // The channel's name shows in the phone's settings, in the phone's
  // language.
  final strings = lookupAppLocalizations(
    resolveAppLocale(PlatformDispatcher.instance.locales),
  );
  await pushClient.initialize(
    channelName: strings.pushChannelName,
    channelDescription: strings.pushChannelDescription,
  );
  pushClient.showForegroundMessages();

  if (emulators != null) {
    final host = emulators.host;
    await firebaseAuth.useAuthEmulator(host, FirebaseEmulators.authPort);
    firestore.useFirestoreEmulator(host, FirebaseEmulators.firestorePort);
    functions.useFunctionsEmulator(host, FirebaseEmulators.functionsPort);
    await storage.useStorageEmulator(host, FirebaseEmulators.storagePort);
  }

  // Repository layer
  final authRepository = AuthRepository(
    firebaseAuth: firebaseAuth,
    googleSignInFlow: googleSignInFlow,
  );
  const needsRepository = NeedsRepository(deviceStore: deviceStore);
  final profileRepository = ProfileRepository(rondaApi: rondaApi);
  final rondaRepository = RondaRepository(proposalsApi: proposalsApi);
  final pushRepository = PushRepository(
    pushClient: pushClient,
    rondaApi: rondaApi,
  );
  final flyerRepository = FlyerRepository(
    faceBlur: faceBlur,
    flyersApi: flyersApi,
    shareSheet: shareSheet,
  );
  final onboardingRepository = OnboardingRepository(
    voiceRecorder: voiceRecorder,
    rondaApi: rondaApi,
  );

  runApp(
    await builder(
      authRepository: authRepository,
      flyerRepository: flyerRepository,
      needsRepository: needsRepository,
      onboardingRepository: onboardingRepository,
      profileRepository: profileRepository,
      pushRepository: pushRepository,
      rondaRepository: rondaRepository,
    ),
  );
}
