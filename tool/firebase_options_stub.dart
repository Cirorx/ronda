// A stand-in for the generated lib/firebase_options_<flavor>.dart files,
// which hold the real project's config and are git-ignored. CI copies this
// file to both names before analyze and test (.github/workflows/main.yaml);
// a fresh clone runs `flutterfire configure` instead (docs/STACK.md
// § Native and project checklist). Every value is fake: an app built with
// it starts but can't reach Firebase.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Ronda ships on Android, iOS and web only.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'fake-api-key',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-ronda',
    authDomain: 'demo-ronda.firebaseapp.com',
    storageBucket: 'demo-ronda.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'fake-api-key',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-ronda',
    storageBucket: 'demo-ronda.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'fake-api-key',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-ronda',
    storageBucket: 'demo-ronda.firebasestorage.app',
    iosBundleId: 'com.ciroapps.ronda',
  );
}
