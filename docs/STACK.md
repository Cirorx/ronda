# Stack: packages, tools and setup (checked 2026-10-26)

Research behind this file: three research reports of 2026-10-26, with sources (kept privately).
Versions are from pub.dev / PyPI / npm on 2026-10-26. **First thing on day 1:** `flutter pub get`
with this pubspec. If `material_ui` or anything else doesn't resolve, fix the pubspec before
writing code.

## Toolchain

| Tool | Version | Note |
|---|---|---|
| Flutter / Dart | 3.47.8 / 3.13.7 (stable 2026-10-23) | This Mac has 3.47.1: `flutter upgrade` |
| Android | minSdk 24, compile/target 36, AGP ≥ 8.11.1, core-library desugaring on | FlutterFire BoM 35 and flutter_local_notifications set the floors |
| iOS | deployment target 15.5 (ML Kit), armv7 excluded in the Podfile | CocoaPods still used for ML Kit and flutter_tts |
| Python (functions, scripts) | 3.13 (`uv python install 3.13`) | Firebase Python functions run 3.10–3.13; this Mac's 3.14 won't deploy |
| firebase-tools | 15.34.1 via npm | The Homebrew binary hung on `firebase --version`: reinstall |
| ortools | 9.15.6755, with `protobuf==6.33.6` pinned | Only 6.33.5/6.33.6 satisfy both ortools and google-cloud-firestore |
| scrcpy | 5.0.1 (`brew upgrade scrcpy`) | Two-phone recording |
| Maestro | latest (`curl -fsSL "https://get.maestro.mobile.dev" \| bash`) | Needs Java 17+ (this Mac has 23) |
| FlutterFire CLI | 1.4.1 (`dart pub global activate flutterfire_cli`) | `flutterfire configure` writes `lib/firebase_options.dart` |

## pubspec (resolved with `flutter pub get --dry-run` on 3.47.1)

```yaml
environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter: {sdk: flutter}
  flutter_localizations: {sdk: flutter}
  material_ui: ^1.8.0            # Material now ships outside the framework
  intl: ^0.20.2
  firebase_core: ^5.1.0
  firebase_auth: ^7.0.1
  cloud_firestore: ^7.1.0
  firebase_storage: ^14.0.1
  cloud_functions: ^7.0.1
  firebase_messaging: ^17.0.1
  flutter_local_notifications: ^22.3.3
  bloc: ^9.2.1
  flutter_bloc: ^9.1.1
  equatable: ^2.0.7              # not ^3: fake_cloud_firestore needs ^2
  go_router: ^18.1.1
  record: ^7.1.2                 # WAV 16 kHz mono on every platform
  path_provider: ^2.1.6          # native only
  flutter_tts: ^4.2.5            # read-aloud with the phone's voice
  image_picker: ^1.2.4
  flutter_image_compress: ^2.5.1 # rotation fix, strips EXIF
  google_mlkit_face_detection: ^0.15.1   # native only, detection only
  image: ^4.12.0                 # pixelate face boxes
  flutter_secure_storage: ^11.2.0        # needs, device-only
  shared_preferences: ^2.5.6     # non-sensitive flags only (it is backed up)
  url_launcher: ^6.3.3
  qr_flutter: ^4.1.0             # only for an in-app QR; flyer QRs are made server-side

dev_dependencies:
  flutter_test: {sdk: flutter}
  mocktail: ^1.0.5
  bloc_test: ^10.0.0
  bloc_lint: ^0.4.3
  very_good_analysis: ^11.0.0
  fake_cloud_firestore: ^4.5.0
  firebase_auth_mocks: ^0.16.0

flutter:
  generate: true
  uses-material-design: true
  fonts:          # bundled from github.com/google/fonts (OFL 1.1); register OFL.txt with LicenseRegistry
    - family: YoungSerif
      fonts: [{asset: assets/fonts/YoungSerif-Regular.ttf}]
    - family: AtkinsonHyperlegible
      fonts:
        - asset: assets/fonts/AtkinsonHyperlegible-Regular.ttf
        - {asset: assets/fonts/AtkinsonHyperlegible-Bold.ttf, weight: 700}
```

Python functions (`functions/requirements.txt`): `firebase-functions`, `firebase-admin`,
`ortools==9.15.6755`, `protobuf==6.33.6`, `openai` (Meta and Baseten are OpenAI-compatible), `httpx` (multipart Voice Transcribe),
`pydantic`, `meta-sam-parser`, `Pillow`, `segno` (flyer QR). Check WAV headers with the
stdlib `wave` module (`audioop` is gone in 3.13).

## Choices

- **State: Bloc, Cubit-first.** Farolito uses it (copy patterns, never code: pre-10-27 code is
  banned), the VGV bloc skill and `bloc_lint` keep AI-written code in line, no code generation.
- **E2E: Maestro**, not Patrol or `integration_test`. Black-box YAML on the USB phone and on web,
  grants permissions on launch, and the same flows replay the golden path for the demo
  recording. Give every tappable widget `Semantics(identifier: ...)`.
- **Other tests:** `bloc_test` + `mocktail` for cubits; `fake_cloud_firestore` for repositories;
  `pytest` for the solver and the voice eval; `@firebase/rules-unit-testing` 6.0.0 under
  `firebase emulators:exec` for rules.
- **Agent trace:** Firestore `agent_runs/{id}/steps/{n}`, rendered in the admin web screen. No
  Langfuse (third party, looks like a dev console).
- **Public pages** (Cerca tuyo, QR landing `/f/{id}`): plain HTML on Firebase Hosting. Flutter web
  loads ~1.5 MB of CanvasKit before any app code.

## Gotchas that AI assistants get wrong

1. Import `package:material_ui/material_ui.dart`, not the framework's Material.
2. gen-l10n needs `app_es.arb` (full voseo text) beside `app_es_419.arb` (just
   `{"@@locale": "es_419"}`). Import from `package:ronda/l10n/app_localizations.dart`;
   `flutter_gen` no longer exists. Map any `es_*` device locale to `es_419` in
   `localeListResolutionCallback`.
3. `cloud_functions` calls `us-central1` unless you use
   `FirebaseFunctions.instanceFor(region: 'southamerica-east1')`.
4. `record` defaults to AAC 44.1 kHz stereo. Set `encoder: AudioEncoder.wav, sampleRate: 16000,
   numChannels: 1`. On web `stop()` returns a blob URL: fetch the bytes and `putData`.
5. The FCM web service worker must use the Firebase JS SDK 13.1.0 compat scripts (the plugin's
   example still shows 9.10.0).
6. `path_provider` and ML Kit don't exist on web: guard with `kIsWeb`.

## Push with "Voy / Esta no"

| | Android | iOS (only with the paid Apple Developer Program) | Web |
|---|---|---|---|
| Payload | Data-only, `android.priority: HIGH` | Notification with `aps.category: "RSVP"` (data messages are dropped after force-quit) | Plain notification |
| Buttons | flutter_local_notifications actions on a high-importance "rsvp" channel | Category registered through flutter_local_notifications; both actions `.foreground` | None: the card has big buttons |
| Tap | FLN response handlers; "Voy" → callable `rsvp` | `RemoteMessage.actionIdentifier` via firebase_messaging | Opens the card |

Store `platform` with each FCM token. iPhone web users get push only after Add to Home Screen.

## Native and project checklist

**Firebase project:** Blaze; budget alert at $20; Firestore + Storage + Functions in
`southamerica-east1`; SMS region policy **allow UY only** (new projects allow none); test phone
numbers for demo and judges; authorised domains; Web Push (VAPID) key; admin custom claim for
Ciro; App Check after the hackathon (callables require `auth != null` meanwhile).

**Android:** SHA-1 and SHA-256 (debug and release) in the console; manifest: `RECORD_AUDIO`,
`POST_NOTIFICATIONS` (ask at runtime on 13+), the FLN `ActionBroadcastReceiver`, the TTS
`<queries>` block, `allowBackup="false"` + `dataExtractionRules` excluding cloud backup **and**
device transfer + `fullBackupContent`; handle `ImagePicker.retrieveLostData()`.

**iOS:** Apple Developer Program for push and APNs-based phone auth; APNs key uploaded to
Firebase; Push + Background Modes (remote notifications); Encoded App ID URL scheme;
`NSMicrophoneUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
localised in `es.lproj/InfoPlist.strings`; Podfile 15.5 + armv7 excluded; the
`UNUserNotificationCenter` delegate line. Phone auth needs a real device.

**Web:** HTTPS (mic, secure storage); `usePathUrlStrategy()`; Hosting SPA rewrite for the app,
separate plain-HTML pages; ask notification permission only from a tap.

**Needs on the phone:** one JSON blob in flutter_secure_storage with
`IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)`. On web it is
experimental: say "lo sabe solo este navegador".

## What doesn't work on web
Face blur (no ML Kit): the photo flows say "Hacelo desde la app del teléfono". Push buttons
(Chromium only). iPhone push without a Home Screen install. Everything else works.
