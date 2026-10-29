# Stack: packages, tools and setup (checked 2026-10-26)

Research behind this file: three research reports of 2026-10-26, with sources (kept privately).
Versions are from pub.dev / PyPI / npm on 2026-10-26; the VGV conventions are from the
vgv-ai-flutter-plugin skills (`layered-architecture`, `bloc`, `material-theming`,
`internationalization`, `testing`, `green-gate`, `static-security`), checked 2026-10-26.

## Toolchain

| Tool | Version | Note |
|---|---|---|
| Flutter / Dart | 3.47.8 / 3.13.7 (stable 2026-10-23) | This Mac has 3.47.1: `flutter upgrade` |
| Android | minSdk 24, compile/target 36, Gradle 9.3.1, AGP 9.1.0, Kotlin plugin 2.3.20 (`compilerOptions` DSL, not `kotlinOptions`), JDK 17+ (this Mac runs 23); core-library desugaring is not configured yet (add it with flutter_local_notifications) | Gradle 9.3.1 and AGP 9.1.0 are Flutter 3.47.8's template versions (AGP 9.1 needs Gradle ≥ 9.3.1; Flutter warns below Gradle 9.1 / AGP 9.0.1 / Kotlin 2.3.20). Like the template, `gradle.properties` keeps `android.builtInKotlin=false` and `android.newDsl=false`; `org.jetbrains.kotlin.android` stays in `settings.gradle.kts` (`apply false`) and the app module does not apply it, because the Flutter Gradle plugin applies it to the app and plugins while built-in Kotlin is off. FlutterFire BoM 35 sets the floors; `firebase-auth` 25.0.0 ships Kotlin 2.4 metadata, which Kotlin 2.2 can't read (checked 2026-10-27). Upgraded 2026-10-28 |
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
- Flavors over one `bootstrap.dart`: **development** (emulators) and **production** (the real
  project); staging is removed. There is no `lib/main.dart`, so every command names its target:
  `flutter run --flavor development -t lib/main_development.dart` on a phone,
  `flutter run -d chrome -t lib/main_development.dart` on web (no `--flavor`),
  `flutter build web -t lib/main_production.dart`.
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
| `device_store` | Data | flutter_secure_storage (needs); a flags API over shared_preferences is added when a feature needs one | #18 |
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
  entrypoints and bootstrap import a data package. A new repository is a new named parameter of
  `AppBuilder` and of `App`.
- Repositories receive every source through the constructor, import no other repository, and
  turn wire models into domain models. Business rules live in Cubits.
- Path dependencies between local packages; every package exports through its barrel file.
- Dart 3.13 primary constructors for models, states, events and widgets
  (`class const User(final String id, final String firstName) extends Equatable`).
- Pages provide, Views consume; `context.read` in callbacks, `BlocBuilder` / `context.watch` in
  `build`. Cubits talk to each other only through repositories or the UI.

## Theme and copy (from `material-theming` and `internationalization`)
- Names in `ronda_ui`: `AppColors` (token constants), `RondaPalette` (the ThemeExtension, read with
  `context.rondaPalette`), `AppTextStyle`, `AppSpacing`, `AppRadius` (8/10/12/16/22), `AppTheme`.
  `material_ui` 1.8.0's `inputDecorationTheme` takes `InputDecorationThemeData`.
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
card, flyer). MCP quirks: `analyze_files` needs absolute `file:` URIs (relative paths silently
report "No errors"), `dart_format` takes relative paths, and `check_ignore` is rejected for
Flutter projects, so `// coverage:ignore` has no effect there (passing it fails the whole run
with exit 64).
- Coverage counts only files a test imports: `bootstrap.dart` and `main_*.dart` have no test (as
  in the VGV template), so the web and development APK builds are what prove the wiring.
- The app's `pumpApp` pumps `AppTheme.light` and the es-419 locale, like ronda_ui's helper, so
  page tests see what the app shows.
- Golden test files carry library-level `@Tags(['golden', 'skip_very_good_optimization'])` as
  string literals: the very_good optimizer merges test files and its golden comparator then
  crashes, and both the optimizer and the runner read only literal file-level tags.
- Maestro identifiers sit on the node that has the tap action:
  `MergeSemantics(child: Semantics(identifier: …, child: button))`; when the spoken label must
  differ from the visible text, `Semantics(container: true, identifier: …, label: …, button: true,
  onTap: …, excludeSemantics: true)`. A bare `Semantics(identifier:)` lands on a wrapper with no
  action.

## End-to-end flows (Maestro)

The flows live in `flows/`, one YAML file each, and reach widgets only through their
`Semantics(identifier:)` (§ Quality bar), never through visible text. On Android an identifier is
the node's `resource-id`, so `maestro hierarchy` shows what a flow can target. Chips and switches
end in the Dart enum name (`onboarding.barrio.solymarNorte`); a slot cell ends in its day and
band indexes (`onboarding.slots.6.1` is Sunday afternoon).

| Flow | Starts from | Ends on |
|---|---|---|
| `flows/onboarding_buttons.yaml` | a reset, signed out | Mi ronda (`myRonda`), with `users/{uid}` and its `private/eligible` written |

Each flow runs the development flavor against the local emulators, on an Android emulator or a
USB phone; checked with Maestro 2.12.0 on an Android 15 emulator. `maestro` must be on `PATH`
(the installer puts it under `~/.maestro/bin`). `<serial>` is the device's name in `adb devices`;
pass it everywhere, so nothing lands on another attached device.

1. **Emulators:** `firebase emulators:start` from the repo root (§ Native and project checklist).
2. **Device:** an Android emulator (`emulator -avd <avd>`) reaches the emulators at `10.0.2.2`
   without setup. A USB phone needs
   `for p in 9099 8088 5001 9199; do adb -s <serial> reverse tcp:$p tcp:$p; done` after every
   reconnect, and the build below with `--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1` added.
3. **Build and install** the development flavor with the demo Google account, so sign-in needs no
   browser:
   `flutter build apk --debug --flavor development -t lib/main_development.dart --dart-define=EMULATOR_GOOGLE_CREDENTIAL=true`,
   then `adb -s <serial> install -r build/app/outputs/flutter-apk/app-development-debug.apk`
   (the app id is `com.ciroapps.ronda.dev`).
4. **Reset before every run:**
   `FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 uv run --python 3.13 scripts/reset.py`
   leaves no Auth accounts and Firestore with the seat facts and the 30 demo sign-ups
   (§ Native and project checklist, Demo data). A flow
   signs in as the same demo account every time (`vecina@example.com`), and once that account has
   a profile the app skips onboarding, so a second run without a reset fails on the first
   question. `launchApp` with `clearState: true` signs the phone out and clears its needs.
5. **Run:** `maestro --device <serial> test flows/onboarding_buttons.yaml`, or `flows/` for every
   flow.
6. **Check what it wrote** with the emulator's REST API, which skips the rules with the `owner`
   token:
   `curl -H "Authorization: Bearer owner" "http://127.0.0.1:8088/v1/projects/ronda-uy/databases/(default)/documents/users/<uid>/private/eligible"`.
   After `onboarding_buttons` the profile is Marta, 60-69, Solymar Norte, mate, Sunday afternoon,
   pan, and the eligible ids are the 32 seats of Solymar Norte and Solymar Sur, the barrios
   within ten blocks of Solymar Norte ("Caminar mucho" leaves out the far ones; the need itself
   stays on the phone).

## Security (from `static-security`)
- Meta and Baseten keys exist only in Cloud Functions config. The app ships Firebase's web/app
  config, which is public by design: restrict those API keys to the Firebase APIs and the app ids
  in the Google Cloud console.
- Needs, tokens and anything personal go to flutter_secure_storage; shared_preferences holds
  only flags such as "onboarding seen".
- Logs carry ids and type names: phone numbers, names, transcripts, needs and FCM tokens stay
  out of `log()`, `debugPrint()` and the BlocObserver.
- Form fields (first name) are validated `formz` inputs held in Cubit state; the
  submit reads state, never a `TextEditingController`.
- Release builds use `--obfuscate --split-debug-info`; `osv-scanner --lockfile=pubspec.lock`
  before the submission (#32).
- **Photos leave the phone without location or faces, in this order:** `flutter_image_compress`
  first (long side 1600 px, `keepExif: false`, `autoCorrectionAngle: true`), so the pixels are
  upright and carry no EXIF; ML Kit on a ≥ 2400 px copy made the same way (`accurate`,
  `minFaceSize` ≈ 0.03, boxes padded 25%); `image` pixelates in `Isolate.run`, then
  `image.exif = ExifData()` before `encodeJpg` (the `image` package otherwise writes EXIF back,
  and `image_picker` on Android copies GPS tags onto its resized file); the server re-saves with
  Pillow without EXIF as a backstop. Check with `exiftool -a -G1` on a camera photo with
  location on.
- **Voice:** keep WAV 16 kHz mono (Voice Transcribe takes nothing else); on Android try
  `AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition)` against the default in
  the voice eval; no denoising on the phone; log upload bytes and milliseconds per note.
- No FFmpeg or custom native code in the app (`ffmpeg_kit_flutter` is retired and its forks are
  GPL). If the server needs to convert audio, check `ffmpeg -version` in a deployed function
  first; the fallback is `soundfile` + `soxr`.

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
  flutter_web_plugins: {sdk: flutter}   # usePathUrlStrategy()
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
  bloc_tools: ^0.1.0-dev.24      # from the template; CI's bloc lint
  very_good_analysis: ^11.0.0
  fake_cloud_firestore: ^4.5.0
  firebase_auth_mocks: ^0.16.0

flutter:
  generate: true
  uses-material-design: true
  fonts:          # bundled from github.com/google/fonts (OFL 1.1); the two families have different copyright holders, so register both OFL notices with LicenseRegistry
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
  recording. Give every tappable widget `Semantics(identifier: ...)`, except `NavigationBar`
  destinations: wrapping them breaks Flutter's "a tab must have a tap action" semantics check,
  so Maestro taps tabs by their label.
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
   to `es_419` (`resolveAppLocale()`). Use `appLocalizationsDelegates` from the same file, never
   the generated `AppLocalizations.localizationsDelegates`: the generated list wires the
   framework's Material localizations, not `material_ui`'s, and every non-English locale then
   throws "No MaterialLocalizations found". Tests' `pumpApp` uses the same list, and packages use
   `material_ui`'s `GlobalMaterialLocalizations.delegates` directly. Widget tests pump es-419 by
   default, so a missing delegate fails in tests before it fails in the app.
3. `cloud_functions` calls `us-central1` unless you use
   `FirebaseFunctions.instanceFor(region: 'southamerica-east1')`.
4. `record` defaults to AAC 44.1 kHz stereo. Set `encoder: AudioEncoder.wav, sampleRate: 16000,
   numChannels: 1`. On web `stop()` returns a blob URL: fetch the bytes and `putData`.
5. The FCM web service worker must use the Firebase JS SDK 13.1.0 compat scripts (the plugin's
   example still shows 9.10.0).
6. `path_provider` and ML Kit don't exist on web: guard with `kIsWeb`.
7. AGP 9: don't set `isMinifyEnabled` or `proguardFiles` in `android/app/build.gradle.kts`. The
   Flutter Gradle plugin already turns on R8 for release with `proguard-android-optimize.txt`,
   its own rules and `android/app/proguard-rules.pro` if present; AGP 9 fails on
   `getDefaultProguardFile("proguard-android.txt")` and on a listed keep file that doesn't exist.
   Its R8 keep rules are stricter too (`-keep class A` no longer keeps the constructor), so check
   a release APK on a device after adding a rule. Flutter's "plugins that apply Kotlin Gradle
   Plugin" warning names cloud_functions, firebase_auth, firebase_core and firebase_storage. It
   comes from a text match on FlutterFire's own `apply plugin: 'kotlin-android'` line, which only
   runs while built-in Kotlin is off. It shows with the flag on or off, and the latest FlutterFire
   still prints it, so leave it.
8. On the Pixel 8 emulator, Gboard's "Try out your stylus" sheet can open over the app during
   Maestro's `inputText`, and the next tap then fails. Press Back, reset and run again; it doesn't
   come back.

## Push with "Voy / Esta no"

| | Android | iOS (only with the paid Apple Developer Program) | Web |
|---|---|---|---|
| Payload | Data-only, `android.priority: HIGH` | Notification with `aps.category: "RSVP"` (data messages are dropped after force-quit) | Plain notification |
| Buttons | flutter_local_notifications actions on a high-importance "rsvp" channel | Category registered through flutter_local_notifications; both actions `.foreground` | None: the card has big buttons |
| Tap | FLN response handlers; "Voy" → callable `rsvp` | `RemoteMessage.actionIdentifier` via firebase_messaging | Opens the card |

Store `platform` with each FCM token. iPhone web users get push only after Add to Home Screen.

## Native and project checklist

**Firebase project `ronda-uy`** (Blaze, decided 2026-10-27; budget alert at $20, `max_instances`
on every function): **Google sign-in** enabled (free and unlimited on Spark; Android needs the SHA-1 and SHA-256, iOS the
reversed client id URL scheme, web the authorised domains); Firestore in `southamerica-east1`;
Web Push (VAPID) key; admin custom claim for the owner. Phone/SMS sign-in stays off: it needs
Blaze and bills per SMS, so it is never enabled. Storage bucket in `southamerica-east1`. App Check
after the hackathon (callables require `auth != null` meanwhile).

**Firebase in this repo** (set up 2026-10-27, #13). Five apps are registered in `ronda-uy`: Android
`com.ciroapps.ronda` (production) and `com.ciroapps.ronda.dev` (development), the same two
bundle ids on iOS, and one web app both flavors share. The debug keystore's SHA-1 and SHA-256 are
on both Android apps; the release ones are added when a release key exists.

- **Generated config stays out of git:** `lib/firebase_options_development.dart`,
  `lib/firebase_options_production.dart`, `android/app/src/<flavor>/google-services.json` and
  `ios/config/<flavor>/GoogleService-Info.plist`. CI copies `tool/firebase_options_stub.dart`
  (fake values) to both Dart names in the workflow's `setup:` step, so analyze and test pass on a
  clean checkout. The app reads its config from the Dart options; the iOS plists are written but
  not bundled (flutterfire's per-configuration build phase needs the CLI at build time and app ids
  in `firebase.json`, so it was left out).
- **Fresh clone:** `firebase login`, then for each flavor
  `flutterfire configure --project=ronda-uy --platforms=android,ios,web --yes --out=lib/firebase_options_<flavor>.dart --android-package-name=<id> --android-out=android/app/src/<flavor>/google-services.json --ios-bundle-id=<id> --ios-out=ios/config/<flavor>/GoogleService-Info.plist --ios-build-config=Debug-<flavor>`
  (`<id>` is `com.ciroapps.ronda` or `com.ciroapps.ronda.dev`). Without `--ios-build-config` the
  CLI stops at an interactive prompt even with `--yes`. Afterwards revert what it adds to
  `ios/Runner.xcodeproj/project.pbxproj` and the `flutter` block it writes into `firebase.json`
  (both carry app ids). Functions: `uv venv --seed --python 3.13 functions/venv` and
  `VIRTUAL_ENV=functions/venv uv pip install -r functions/requirements.txt`.
- **Emulators:** `firebase emulators:start` from the repo root (auth 9099, firestore **8088**,
  functions 5001, storage 9199, pubsub 8085, UI on :4000). Firestore is off its default 8080
  because web dev servers often hold that port. `ping` answers at
  `http://127.0.0.1:5001/ronda-uy/southamerica-east1/ping`. No hosting emulator, so node 26 works;
  `.nvmrc` says 24 for when hosting joins.
- **Demo data** (`docs/ARCHITECTURE.md` § Demo data), from the repo root with the emulators up:
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 uv run --python 3.13 scripts/reset.py`
  restores the golden path (no Auth accounts; seat facts and the 30 invented sign-ups), and
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 uv run --python 3.13 scripts/seed.py 200` writes the
  200 set on top (`reset.py 200` for that set alone). Both refuse to run without the emulator
  hosts; the project is `GCLOUD_PROJECT`, else `.firebaserc`'s default. **Real project:**
  `uv run --python 3.13 scripts/reset.py --project ronda-uy`, with Application Default
  Credentials and no emulator hosts, deletes only the demo documents (`users/demo-*` and what
  hangs under them, `avoid` pairs naming a `demo-` uid, the demo seat facts) and writes the set
  again; real members' documents and every Auth account stay. It deletes nothing if a demo seat
  fact was changed (a host set a place). Tests: `cd scripts`, `uv sync`, `uv run pytest`; the
  reset tests run only with both hosts set, on their own project id (`demo-ronda-reset`), so they
  never wipe `ronda-uy`.
- **Which host the development app uses:** `localhost` on web and the iOS simulator, `10.0.2.2`
  on the Android emulator, and on a USB phone `127.0.0.1` after
  `for p in 9099 8088 5001 9199; do adb reverse tcp:$p tcp:$p; done`, passed as
  `--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1`. The development flavor's
  `network_security_config.xml` allows cleartext to those three hosts only; production keeps
  Android's default.

**Google sign-in against the Auth emulator** (checked 2026-10-27 in the Firebase docs, the
FlutterFire 7.0.1 plugin source, the iOS SDK source and the Android SDK 25.0.0 binary):

| Platform | Flow (`GoogleSignInFlow`) | Reaches the emulator? |
|---|---|---|
| Web | `signInWithPopup(GoogleAuthProvider())` | Yes: the popup is the emulator's "Sign-in with Google.com" picker. Tried on Chrome: user created, app on Mi ronda |
| Android | `signInWithProvider(GoogleAuthProvider())` | Yes: FlutterFire calls `startActivityForSignInWithProvider`; with `useAuthEmulator` set, `GenericIdpActivity` opens `http://<host>:9099/emulator/auth/handler…` in Chrome (seen in logcat on the Pixel 8 emulator). Needs a browser past its first run |
| iOS | `signInWithProvider(GoogleAuthProvider())` | Yes by source: FlutterFire builds an `OAuthProvider("google.com")`, and the iOS SDK swaps `https://<authDomain>/__/auth/handler` for `http://<host>/emulator/auth/handler` when an emulator is set. Not run yet |
| Android, iOS, web (opt-in) | `signInWithCredential(GoogleAuthProvider.credential(idToken: '{"sub":…,"email":…,"email_verified":true}'))` | Yes: the emulator takes a literal JSON string as the Google id token (Firebase docs, "Connect your app to the Authentication Emulator"). Signs in as `vecina@example.com` with no picker; `--dart-define=EMULATOR_GOOGLE_CREDENTIAL=true` on `main_development.dart` only. Tried on the Pixel 8 emulator and on web (2026-10-27, for browsers that can't open the popup, such as an embedded preview) |

`main_production.dart` can only pass `popup` (web) or `provider` (phones); the real project
rejects the unsigned token anyway. On iOS the provider flow against the real project also needs the
reversed client id (or the encoded app id) as a URL scheme in `Info.plist`, per flavor.

**Android:** SHA-1 and SHA-256 (debug and release) in the console; manifest: `RECORD_AUDIO`,
`POST_NOTIFICATIONS` (ask at runtime on 13+), the FLN `ActionBroadcastReceiver`, the TTS
`<queries>` block, `allowBackup="false"` + `dataExtractionRules` excluding cloud backup **and**
device transfer + `fullBackupContent`; handle `ImagePicker.retrieveLostData()`.

**iOS:** Apple Developer Program for push; APNs key uploaded to
Firebase; Push + Background Modes (remote notifications); Encoded App ID URL scheme;
`NSMicrophoneUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
localised in `es.lproj/InfoPlist.strings`; Podfile 15.5 + armv7 excluded; the
`UNUserNotificationCenter` delegate line.

**Web:** HTTPS (mic, secure storage); `usePathUrlStrategy()`; the Flutter app is built with
`--base-href /app/` and served under `/app` with an SPA rewrite, so its `/app/cerca` route never
collides with the public plain-HTML `/cerca` and `/f/{id}` pages; ask notification permission only
from a tap.

**Needs on the phone:** one JSON blob under the key `needs`, shaped `{"needs":["walkALot","noCar"]}` (the `Need` enum names, so renaming a value loses what phones saved), in flutter_secure_storage with
`IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)`. On web it is
experimental: say "lo sabe solo este navegador".

## What doesn't work on web
Face blur (no ML Kit): the photo flows say "Hacelo desde la app del teléfono". Push buttons
(Chromium only). iPhone push without a Home Screen install. Everything else works.
