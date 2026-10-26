# Stack: packages, tools and setup (checked 2026-10-26)

Research behind this file: three research reports of 2026-10-26, with sources (kept privately).
Versions are from pub.dev / PyPI / npm on 2026-10-26; the VGV conventions are from the
vgv-ai-flutter-plugin skills (`layered-architecture`, `bloc`, `material-theming`,
`internationalization`, `testing`, `green-gate`, `static-security`), checked 2026-10-26.

## Toolchain

| Tool | Version | Note |
|---|---|---|
| Flutter / Dart | 3.47.8 / 3.13.7 (stable 2026-10-23) | This Mac has 3.47.1: `flutter upgrade` |
| Android | minSdk 24, compile/target 36, AGP ≥ 8.11.1, core-library desugaring on | FlutterFire BoM 35 and flutter_local_notifications set the floors |
| iOS | deployment target 15.5 (ML Kit), armv7 excluded in the Podfile | CocoaPods still used for ML Kit and flutter_tts |
| Python (functions, scripts) | 3.13 (`uv python install 3.13`) | Firebase Python functions run 3.10–3.13; this Mac's 3.14 won't deploy |
| firebase-tools | 15.34.1 via npm | Installed under nvm's node 26, but the Hosting emulator (`superstatic`) supports node 20, 22 and 24 only: run the emulators under node 24 (`nvm install 24`, `nvm use 24`, reinstall firebase-tools there) |
| ortools | 9.15.6755, with `protobuf==6.33.6` pinned | Only 6.33.5/6.33.6 satisfy both ortools and google-cloud-firestore |
| scrcpy | 5.0.1 (`brew upgrade scrcpy`) | Two-phone recording |
| Maestro | latest (`curl -fsSL "https://get.maestro.mobile.dev" \| bash`) | Needs Java 17+ (this Mac has 23) |
| FlutterFire CLI | 1.4.1 (`dart pub global activate flutterfire_cli`) | `flutterfire configure` writes `lib/firebase_options.dart` |

## Scaffold: the VGV app template

Create the app with the Very Good CLI MCP `create` tool (`subcommand: flutter_app`, `name: ronda`,
`org_name: com.ciroapps`, `platforms: android,ios,web`) into a temporary directory, then move its
contents to the repo root, keeping Ronda's `.gitignore` rules and `LICENSE`. Checked 2026-10-26,
the template already ships what this file asks for:

- `material_ui`, Bloc, `bloc_lint`, `very_good_analysis`, `mocktail`, `bloc_test`, Dart ^3.13.
- Flavors `main_development.dart`, `main_staging.dart`, `main_production.dart` over one
  `bootstrap.dart`. Ronda uses **development = emulators** and **production = the real project**;
  delete staging.
- l10n: `lib/l10n/arb/app_en.arb` + `app_es.arb`, generated into `lib/l10n/gen/`, read through
  `context.l10n` (`lib/l10n/l10n.dart`). Add `app_es_419.arb` = `{"@@locale": "es_419"}`.
- `test/helpers/pump_app.dart` with the localization delegates.
- GitHub Actions: VGV `flutter_package` build (analyze, format, tests, coverage, bloc_lint), a
  licence check (MIT, BSD, Apache) and a cspell spell check on `**/*.md`. Ronda's docs are half
  Spanish: give cspell a Spanish dictionary and a `words` list, or narrow `includes` to
  English docs, so CI stays green.

Two template defaults to change on day 1:
- `AppBlocObserver` logs every state change. Ronda's states carry phone numbers and needs, so
  log `bloc.runtimeType` and the transition's type names only, and only in development.
- The counter feature is sample code: delete it once the first real feature exists.

## Architecture: VGV layers

Four layers, dependencies pointing one way: **Presentation → Business Logic → Repository → Data**.

| Layer | Where | Holds |
|---|---|---|
| Presentation | `lib/<feature>/view/` | Page (provides the Cubit) + View (`BlocBuilder` / `BlocListener`) |
| Business logic | `lib/<feature>/cubit/` (or `bloc/` when events need transformers) | Cubits with sealed, Equatable states |
| Repository | `packages/<domain>_repository/` | Domain models, orchestration of data clients |
| Data | `packages/<source>/` | One external source each; models match its wire shape |

Target package map (create each when its first feature needs it, with the Very Good CLI MCP
`create` tool: `dart_package` where the source allows, `flutter_package` when it wraps a plugin):

| Package | Layer | Wraps / owns | First issue |
|---|---|---|---|
| `ronda_ui` | UI (`app_ui_package`) | Tokens, `AppTheme` light + dark, `AppSpacing`, fonts, components; labels arrive as parameters | #17 |
| `ronda_api` | Data | Firestore, Storage and the callables (`extract`, `propose_groups`, `rsvp`, `run_job`) | #13 |
| `device_store` | Data | flutter_secure_storage (needs) and shared_preferences (flags) | #18 |
| `voice_recorder` | Data | `record`, WAV 16 kHz mono | #19 |
| `push_client` | Data | firebase_messaging + flutter_local_notifications | #27 |
| `face_blur` | Data | ML Kit face detection + `image` pixelation (native only) | #30 |
| `auth_repository` | Repository | `FirebaseAuth` passed in from bootstrap | #13 |
| `profile_repository` | Repository | Profile, eligible seat ids (over `ronda_api`) | #18 |
| `needs_repository` | Repository | Needs and the seat filter, over `device_store` only: this repository has no network path | #18 |
| `onboarding_repository` | Repository | Voice note → upload → `extract` → fields (over `voice_recorder` + `ronda_api`) | #19 |
| `ronda_repository` | Repository | Rondas, weeks, RSVPs, proposals, acta | #25 |

Rules the agents apply (from `layered-architecture` and `bloc`):
- Bootstrap (`main_<flavor>.dart` / `bootstrap.dart`) builds every data client and repository and
  hands the repositories to `App`, which exposes them with `MultiRepositoryProvider`. Only
  entrypoints and bootstrap import a data package.
- Repositories receive every source through the constructor, import no other repository, and
  turn wire models into domain models. Business rules live in Cubits.
- Path dependencies between local packages; every package exports through its barrel file.
- Dart 3.13 primary constructors for models, states, events and widgets
  (`class const User(final String id, final String firstName) extends Equatable`).
- Pages provide, Views consume; `context.read` in callbacks, `BlocBuilder` / `context.watch` in
  `build`. Cubits talk to each other only through repositories or the UI.

## Theme and copy (from `material-theming` and `internationalization`)
- `ronda_ui` maps the DESIGN.md tokens onto two `ColorScheme`s (light and dark: paper → surface,
  ink → onSurface, birome → primary, yerba → tertiary, ámbar → secondary) inside `AppTheme.light`
  / `AppTheme.dark`, passed to `MaterialApp` as `theme` / `darkTheme`. Yerba, ámbar and margen also
  sit in a `RondaPalette` ThemeExtension for the roles Material has no slot for.
- Typography: `AppTextStyle` → `TextTheme`; widgets read `Theme.of(context).textTheme`.
- Component looks (buttons 48 dp, radius 12, cards, inputs) live in component themes in
  `ThemeData`; call sites declare only what is unique to them.
- `AppSpacing` with base unit 16: `xxs` 4, `xs` 8, `sm` 12, `md` 16, `lg` 24, `xlg` 32, each a
  multiple of the unit. `EdgeInsets.only` / `.symmetric` / `EdgeInsetsDirectional`.
- Every user-facing string comes from the ARB files via `context.l10n`; `ronda_ui` widgets take
  their labels as `final String` parameters.

## Quality bar: green gate
Every issue ends **green**: the `green-gate` skill's four gates, analyze (`applyFixes`) →
format (zero files changed) → test → coverage, all passing in the same final round, through the
dart and very_good_cli MCP tools. Coverage target **100%** for `packages/*`, **≥ 90%** for the app
(`lib/l10n/gen/**` and `*.g.dart` excluded). Tests follow the `testing` skill: groups that read
as sentences, `late` + `setUp` inside groups, private `_Mock` classes, `pumpApp`, `MockCubit` in
widget tests, goldens tagged `TestTag.golden` for the three hero screens (read-back, Mi ronda
card, flyer).

## Security (from `static-security`)
- Meta and Baseten keys exist only in Cloud Functions config. The app ships Firebase's web/app
  config, which is public by design: restrict those API keys to the Firebase APIs and the app ids
  in the Google Cloud console.
- Needs, tokens and anything personal go to flutter_secure_storage; shared_preferences holds
  only flags such as "onboarding seen".
- Logs carry ids and type names: phone numbers, names, transcripts, needs and FCM tokens stay
  out of `log()`, `debugPrint()` and the BlocObserver.
- Form fields (first name, phone number) are validated `formz` inputs held in Cubit state; the
  submit reads state, never a `TextEditingController`.
- Release builds use `--obfuscate --split-debug-info`; `osv-scanner --lockfile=pubspec.lock`
  before the submission (#32).

## pubspec (resolved with `flutter pub get --dry-run` on 3.47.1)

The flat list below is the resolved version set. With the package map above, each dependency
goes into the package that owns its source; the app's own pubspec keeps the Flutter SDK
packages, Bloc, go_router, Firebase core and the path dependencies.

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
  formz: ^0.8.1                  # validated form inputs (VGV static-security)
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

- **State: Bloc, Cubit-first**, laid out as above. Farolito uses the same stack (copy patterns,
  never code: pre-10-27 code is banned); the VGV skills and `bloc_lint` keep AI-written code in
  line; no code generation.
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
   `{"@@locale": "es_419"}`). Strings come from `package:ronda/l10n/l10n.dart` (`context.l10n`),
   generated into `lib/l10n/gen/`; `flutter_gen` no longer exists. Map any `es_*` device locale
   to `es_419` in `localeListResolutionCallback`.
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
