import 'dart:async';
import 'dart:developer';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:contact_repository/contact_repository.dart';
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
import 'package:link_opener/link_opener.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:organiser_repository/organiser_repository.dart';
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
  required ContactRepository contactRepository,
  required FlyerRepository flyerRepository,
  required NeedsRepository needsRepository,
  required OnboardingRepository onboardingRepository,
  required OrganiserRepository organiserRepository,
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

  /// The functions emulator's port: [defaultFunctionsPort] unless a second
  /// one runs beside it (`--dart-define=FIREBASE_FUNCTIONS_PORT=…`).
  final int functionsPort = defaultFunctionsPort,
}) {
  /// Auth emulator port.
  static const authPort = 9099;

  /// Firestore emulator port (8080 is often taken by web dev servers).
  static const firestorePort = 8088;

  /// Functions emulator port in `firebase.json`.
  static const defaultFunctionsPort = 5001;

  /// Storage emulator port.
  static const storagePort = 9199;
}

/// The web push certificate's public key, passed as
/// `--dart-define=FCM_VAPID_KEY=…` (`docs/STACK.md` § Push). It is public by
/// design: browsers receive it to subscribe. Empty until the owner creates
/// it in the console; without it web uses Firebase's default key, if any.
const fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

const _contactEmailDefine = String.fromEnvironment('RONDA_CONTACT_EMAIL');

/// Where members write to Ronda from Ajustes ("Contar algo que pasó", "Tus
/// datos"): `--dart-define=RONDA_CONTACT_EMAIL=…` (`docs/STACK.md` § Pilot
/// builds), or the brand address when it is missing or empty. A person
/// reads it, so the owner routes it to an inbox before a build reaches
/// members.
const String rondaContactEmail = _contactEmailDefine == ''
    ? 'hola@ciroapps.com'
    : _contactEmailDefine;

/// The app's strings in the phone's language, for what shows outside a
/// screen: the channel's name and the push's buttons.
AppLocalizations _phoneStrings() => lookupAppLocalizations(
  resolveAppLocale(PlatformDispatcher.instance.locales),
);

PushClient _pushClient(AppLocalizations strings) => PushClient(
  messaging: FirebaseMessaging.instance,
  notifications: FlutterLocalNotificationsPlugin(),
  vapidKey: fcmVapidKey,
  rsvpLabels: RsvpActionLabels(
    yes: strings.thisWeekYes,
    no: strings.thisWeekNo,
  ),
  seguimosLabels: SeguimosActionLabels(
    yes: strings.seguimosYes,
    no: strings.seguimosNo,
  ),
);

/// Shows a data-only push that arrived while the app was in the background
/// or closed (Android). FCM runs it in its own isolate, so it starts Firebase
/// again before anything else.
@pragma('vm:entry-point')
Future<void> showPushInBackground(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _pushClient(_phoneStrings()).showMessage(message);
}

/// Answers the weekly push's "Voy" or "Esta no", or the ¿seguimos? push's
/// "Sí" or "No", without opening the app (Android).
/// flutter_local_notifications runs it in a background isolate, even with
/// the app closed, so it starts Firebase with the flavor's [firebaseOptions]
/// and [emulators], waits for the signed-in member, calls `answer_rsvp` or
/// `answer_seguimos` through the same repository as the cards, and puts a
/// notice in the push's place saying what happened.
///
/// Each flavor's entrypoint wraps it in a top-level
/// `@pragma('vm:entry-point')` function and hands that to [bootstrap].
Future<void> answerRsvpInBackground(
  NotificationResponse response, {
  required FirebaseOptions firebaseOptions,
  FirebaseEmulators? emulators,
}) async {
  final action = PushClient.rsvpActionFrom(response);
  final seguimos = PushClient.seguimosActionFrom(response);
  if (action == null && seguimos == null) return;
  await Firebase.initializeApp(options: firebaseOptions);
  final auth = FirebaseAuth.instance;
  final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
  if (emulators != null) {
    await auth.useAuthEmulator(emulators.host, FirebaseEmulators.authPort);
    functions.useFunctionsEmulator(emulators.host, emulators.functionsPort);
  }
  final strings = _phoneStrings();
  final pushClient = _pushClient(strings);
  final repository = RondaRepository(
    proposalsApi: ProposalsApi(
      firestore: FirebaseFirestore.instance,
      functions: functions,
    ),
    rondasApi: RondasApi(
      firestore: FirebaseFirestore.instance,
      functions: functions,
    ),
  );
  try {
    if (await auth.authStateChanges().first == null) {
      throw const RsvpFailure(RsvpFailureReason.forbidden);
    }
    if (action != null) {
      await repository.answerRsvp(
        rondaId: action.rondaId,
        week: action.week,
        answer: action.going ? RsvpAnswer.yes : RsvpAnswer.no,
      );
      await pushClient.showNotice(
        id: response.id ?? 0,
        title: action.going ? strings.rsvpNoticeYes : strings.rsvpNoticeNo,
        body: strings.rsvpNoticeBody,
      );
    } else if (seguimos != null) {
      await repository.answerSeguimos(
        rondaId: seguimos.rondaId,
        answer: seguimos.yes ? SeguimosAnswer.yes : SeguimosAnswer.no,
      );
      // The lock screen shows it: the notice never says which answer.
      await pushClient.showNotice(
        id: response.id ?? 0,
        title: strings.seguimosNoticeTitle,
        body: strings.seguimosNoticeBody,
      );
    }
  } on RsvpFailure catch (failure) {
    log('answer from the notification failed: ${failure.reason.name}');
    await pushClient.showNotice(
      id: response.id ?? 0,
      title: strings.rsvpNoticeFailedTitle,
      body: strings.rsvpNoticeFailedBody,
    );
  }
}

/// Starts Firebase, builds the data clients and repositories, then runs the
/// app built by [builder].
///
/// [firebaseOptions] come from the flavor's generated options file. When
/// [emulators] is given (development only) every Firebase client talks to
/// the local emulators instead of the real project. [googleSignInFlow] says
/// how this platform reaches Google. [blocObserver] is installed only when
/// given: the development entrypoint passes `AppBlocObserver`, production
/// passes nothing. [onRsvpAction] answers the weekly push's buttons in the
/// background ([answerRsvpInBackground]).
Future<void> bootstrap(
  AppBuilder builder, {
  required FirebaseOptions firebaseOptions,
  required GoogleSignInFlow googleSignInFlow,
  FirebaseEmulators? emulators,
  BlocObserver? blocObserver,
  DidReceiveBackgroundNotificationResponseCallback? onRsvpAction,
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
  final rondasApi = RondasApi(firestore: firestore, functions: functions);
  final organiserApi = OrganiserApi(firestore: firestore, functions: functions);
  final voiceRecorder = VoiceRecorder();
  // ML Kit is built on the first detection, which never happens on web.
  final faceBlur = FaceBlur();
  final flyersApi = FlyersApi(storage: storage, functions: functions);
  final shareSheet = ShareSheet();
  final linkOpener = LinkOpener();
  // The channel's name shows in the phone's settings, and the push's
  // buttons, in the phone's language.
  final strings = _phoneStrings();
  final pushClient = _pushClient(strings);

  // Push: there is no FCM emulator, so even the development flavor gets its
  // token from the real project; the token is then saved in the emulator.
  if (!kIsWeb) FirebaseMessaging.onBackgroundMessage(showPushInBackground);
  await pushClient.initialize(
    channelName: strings.pushChannelName,
    channelDescription: strings.pushChannelDescription,
    onRsvpAction: onRsvpAction,
  );
  pushClient.showForegroundMessages();

  if (emulators != null) {
    final host = emulators.host;
    await firebaseAuth.useAuthEmulator(host, FirebaseEmulators.authPort);
    firestore.useFirestoreEmulator(host, FirebaseEmulators.firestorePort);
    functions.useFunctionsEmulator(host, emulators.functionsPort);
    await storage.useStorageEmulator(host, FirebaseEmulators.storagePort);
  }

  // Repository layer
  final authRepository = AuthRepository(
    firebaseAuth: firebaseAuth,
    googleSignInFlow: googleSignInFlow,
  );
  const needsRepository = NeedsRepository(deviceStore: deviceStore);
  final profileRepository = ProfileRepository(
    rondaApi: rondaApi,
    deviceStore: deviceStore,
  );
  final rondaRepository = RondaRepository(
    proposalsApi: proposalsApi,
    rondasApi: rondasApi,
  );
  final pushRepository = PushRepository(
    pushClient: pushClient,
    rondaApi: rondaApi,
    deviceStore: deviceStore,
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
  final organiserRepository = OrganiserRepository(organiserApi: organiserApi);
  final contactRepository = ContactRepository(
    linkOpener: linkOpener,
    email: rondaContactEmail,
  );

  runApp(
    await builder(
      authRepository: authRepository,
      contactRepository: contactRepository,
      flyerRepository: flyerRepository,
      needsRepository: needsRepository,
      onboardingRepository: onboardingRepository,
      organiserRepository: organiserRepository,
      profileRepository: profileRepository,
      pushRepository: pushRepository,
      rondaRepository: rondaRepository,
    ),
  );
}
