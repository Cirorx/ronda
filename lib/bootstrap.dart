import 'dart:async';
import 'dart:developer';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_store/device_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Builds the root widget from the repositories bootstrap constructs.
typedef AppBuilder = FutureOr<Widget> Function({
  required AuthRepository authRepository,
  required NeedsRepository needsRepository,
  required ProfileRepository profileRepository,
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
  final rondaApi = RondaApi(firestore: firestore);
  final proposalsApi = ProposalsApi(firestore: firestore, functions: functions);

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

  runApp(
    await builder(
      authRepository: authRepository,
      needsRepository: needsRepository,
      profileRepository: profileRepository,
      rondaRepository: rondaRepository,
    ),
  );
}
