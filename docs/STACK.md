# Stack: packages, tools and setup (checked 2026-10-26)

Research behind this file: three research reports of 2026-10-26, with sources (kept privately).
Versions are from pub.dev / PyPI / npm on 2026-10-26; the VGV conventions are from the
vgv-ai-flutter-plugin skills (`layered-architecture`, `bloc`, `material-theming`,
`internationalization`, `testing`, `green-gate`, `static-security`), checked 2026-10-26.

## Toolchain

| Tool | Version | Note |
|---|---|---|
| Flutter / Dart | 3.47.8 / 3.13.7 (stable 2026-10-23) | This Mac has 3.47.1: `flutter upgrade` |
| Android | minSdk 24, compile/target 36, Gradle 9.3.1, AGP 9.1.0, Kotlin plugin 2.3.20 (`compilerOptions` DSL, not `kotlinOptions`), JDK 17+ (this Mac runs 23); core-library desugaring on (`desugar_jdk_libs` 2.1.4, the version flutter_local_notifications 22's README names; added in #27) | Gradle 9.3.1 and AGP 9.1.0 are Flutter 3.47.8's template versions (AGP 9.1 needs Gradle ≥ 9.3.1; Flutter warns below Gradle 9.1 / AGP 9.0.1 / Kotlin 2.3.20). Like the template, `gradle.properties` keeps `android.builtInKotlin=false` and `android.newDsl=false`; `org.jetbrains.kotlin.android` stays in `settings.gradle.kts` (`apply false`) and the app module does not apply it, because the Flutter Gradle plugin applies it to the app and plugins while built-in Kotlin is off. FlutterFire BoM 35 sets the floors; `firebase-auth` 25.0.0 ships Kotlin 2.4 metadata, which Kotlin 2.2 can't read (checked 2026-10-27). Upgraded 2026-10-28 |
| iOS | deployment target 15.5 (ML Kit), armv7 excluded in the Podfile | CocoaPods still used for ML Kit and flutter_tts |
| Python (functions, scripts) | 3.13 (`uv python install 3.13`) | Firebase Python functions run 3.10–3.13; this Mac's 3.14 won't deploy |
| firebase-tools | 15.34.1 via npm | Installed under nvm's node 26. The Hosting emulator's `superstatic` 10.0.0 declares node 20, 22 and 24 only, but served the `/app` rewrite and headers correctly under node 26.5.1 (checked 2026-10-29). If it stops working: `nvm install 24`, `nvm use 24` (`.nvmrc`), reinstall firebase-tools there |
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
| `ronda_api` | Data | Firestore, Storage and the callables (`extract`, `propose_groups`, `make_mate_flyer`, `answer_rsvp`, `answer_seguimos`, `run_job`, `answer_move`, `ronda_candidates`, `add_to_ronda`, `pilot_numbers`, `ronda_setups`, `set_ronda_setup`, `record_attendance`, `answer_bench_offer`, `answer_waitlist`) | #13 |
| `device_store` | Data | flutter_secure_storage (needs, and the terms and answers held until sign-in); a flags API over shared_preferences is added when a feature needs one | #18 |
| `voice_recorder` | Data | `record`, WAV 16 kHz mono | #19 |
| `push_client` | Data | firebase_messaging + flutter_local_notifications | #27 |
| `push_repository` | Repository | The notification permission, the "Ahora no" snooze, and the FCM token under `users/{uid}/tokens` (over `push_client` + `ronda_api` + `device_store`); the token never leaves it | #27 |
| `face_blur` | Data | `image_picker`, ML Kit face detection + `image` pixelation (native only); only it makes a `BlurredPhoto` | #44 |
| `share_sheet` | Data | share_plus: one file to the phone's share sheet | #44 |
| `link_opener` | Data | url_launcher: a `mailto:`, `tel:` or `https:` link to the phone's mail app, dialer or browser; the app opens links only through it | #54 |
| `flyer_repository` | Repository | The "Un mate de más" flyer: blurred photo → `make_mate_flyer` → share (over `face_blur`, `ronda_api`, `share_sheet`); its upload takes only a `BlurredPhoto` | #44 |
| `auth_repository` | Repository | `FirebaseAuth` passed in from bootstrap; Google's page to make an account, over `link_opener` | #13 |
| `profile_repository` | Repository | Profile, eligible seat ids (over `ronda_api`); the terms and answers held on the phone until sign-in (over `device_store`) | #18 |
| `needs_repository` | Repository | Needs and the seat filter, over `device_store` only: this repository has no network path | #18 |
| `onboarding_repository` | Repository | Voice note → upload → `extract` → fields (over `voice_recorder` + `ronda_api`) | #19 |
| `ronda_repository` | Repository | Rondas, weeks, RSVPs, proposals (proposals built in #25), Cerca tuyo's demand by barrio (#52), place, hour, hosts and attendance (#47) | #25 |
| `organiser_repository` | Repository | The organiser agent: the admin's trace (`agent_runs`), a ronda's acta and [Algo estuvo mal], the host's rain proposal and pick, the rain check by hand (over `ronda_api`'s `OrganiserApi`) | #49 |
| `contact_repository` | Repository | The contact address (`RONDA_CONTACT_EMAIL`) and the helplines: a mail to Ronda or a call, opened in the person's own app (over `link_opener`) | #54 |
| `error_reporter` | Repository | Error monitoring (§ Monitoring): `ErrorReporter` with Crashlytics (`firebase_crashlytics`), the `report_client_error` callable (web) and a local log; the scrubber; the error hooks; the admin's `ClientErrorLog` over Firestore. Takes the Firebase clients from bootstrap, like `auth_repository` | error log |

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
- Motion and feel (`docs/DESIGN.md` § Motion and feel): `AppMotion` (springs and tokens),
  `RondaMotion` (reduced motion), `PressedShape` (the button themes' press) and `PressScale` (any
  other tappable), `showRondaSheet` / `RondaSheetRoute` (every modal sheet, `StepSheet` included;
  it brings the handle tap and the close button, so sheets add none), `RondaPageTransitionsBuilder`,
  `RondaSwap` (with `RondaSwap.topStartLayout` for states in a column), `StepSwitcher` (the steps
  of one page, pushed and popped in place), `SpringBuilder` (with `from:`), `RondaHaptics`.
  `ronda_ui` depends on `cupertino_ui` for the page slide and its edge swipe back.
- Status (`docs/DESIGN.md` § Motion and feel): `StatusLine` (a line read out as it changes),
  `LoadingStatus` / `LoadingStatus.inline` (a ring and a line while a screen reads), `BusyLabel`
  (a ring inside the pressed button) and `RsvpBar`'s `pending:` / `savingLabel:` (an answer on
  its way). Screens use these rather than a bare `CircularProgressIndicator` or their own
  live-region text.
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
| `flows/onboarding_voice.yaml` | a reset, signed out, the Functions emulator with `MODEL_API_KEY` | "¿Entendimos bien?" (or "No te entendimos bien" on a silent emulator mic), with no `audio/` object left |

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
   question. `launchApp` with `clearState: true` signs the phone out and clears its needs and the
   terms and answers it held.
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
- Meta and Baseten keys exist only in Cloud Functions config: `MODEL_API_KEY` and
  `BASETEN_API_KEY` in Secret Manager, bound to the functions that call a model (`extract`,
  `make_mate_flyer`, and `dispatch` and `run_job` for the organiser agent). They reach the code as
  environment variables and are never logged. The app ships Firebase's web/app
  config, which is public by design: restrict those API keys to the Firebase APIs and the app ids
  in the Google Cloud console.
- Needs, tokens and anything personal go to flutter_secure_storage; shared_preferences holds
  only flags such as "onboarding seen".
- Logs carry ids and type names: phone numbers, names, transcripts, needs and FCM tokens stay
  out of `log()`, `debugPrint()` and the BlocObserver.
- Error reports (Crashlytics and `client_errors`, § Monitoring) are scrubbed twice, on the phone
  and on the server, carry the route pattern rather than the path, and at most a hashed uid.
- Form fields (first name) are validated `formz` inputs held in Cubit state; the
  submit reads state, never a `TextEditingController`.
- Release builds use `--obfuscate --split-debug-info` (`scripts/distribute_android.sh`, § Pilot
  builds); `osv-scanner --lockfile=pubspec.lock`
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
`pydantic`, `meta-sam-parser`, `Pillow`, `segno` (flyer QR). The flyer's fonts are the app's:
`functions/fonts` links to `packages/ronda_ui/assets/fonts` (OFL 1.1), as `functions/ronda_solver`
links to the solver. Check WAV headers with the
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
   Plugin" warning names cloud_functions, firebase_auth, firebase_core, firebase_crashlytics and
  firebase_storage (and flutter_image_compress_common). It
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
| Tap | FLN background response handler; "Voy" / "Esta no" → callable `answer_rsvp` | `RemoteMessage.actionIdentifier` via firebase_messaging | Opens the card |

Store `platform` with each FCM token. iPhone web users get push only after Add to Home Screen.

Built in #27 (`packages/push_client`, `packages/push_repository`, `lib/push/`):
- **Token:** `users/{uid}/tokens/{token}` = exactly `{platform, updatedAt}` (server time), written
  by the owner only and never read by a client (`firestore.rules`, tested in
  `rules/tokens.test.js`). Saved when notifications are allowed, on every launch that lands on
  Mi ronda, and again on every FCM token refresh. Signing out (`AppSignOutRequested` in
  `AppBloc`) first deletes the document, while the member still may, then the FCM token itself
  (`deleteToken`), each step giving up after 5 s; a browser that never allowed notifications is
  skipped, since asking it for a token opens its prompt. The token stays inside `push_repository`: no
  state, log or failure carries it. There is no FCM emulator, so the development flavor gets its
  token from the real `ronda-uy` sender and saves it in the Firestore emulator. It is read with
  `getToken()`, which firebase_messaging 17 deprecates for installation ids (`register()`); the
  console's test message and the HTTP v1 API address registration tokens, so it stays until the
  sender moves.
- **The ask:** never at launch. Mi ronda shows "¿Te avisamos los martes?" (PRODUCT copy) while
  the phone can still ask; [Sí, avisame] opens the system prompt (`POST_NOTIFICATIONS` on
  Android 13+, the browser's on web), [Ahora no] hides it for 7 days across launches
  (`push.promptSnoozedAt` in `device_store`, `PushRepository.promptSnooze`; #51). A phone that
  refuses for good gets one line on how to turn notifications on in its settings. Maestro taps
  `push.allow` / `push.later`; `launchApp` grants the permission itself, so the card only shows
  after `adb shell pm revoke <app id> android.permission.POST_NOTIFICATIONS`.
- **Android:** the app creates the high-importance `rsvp` channel at start, named in the phone's
  language ("Tu ronda de la semana"). Data-only messages are drawn by `showPushInBackground` in
  `lib/bootstrap.dart` (top level, `@pragma('vm:entry-point')`, its own isolate) and by
  `showForegroundMessages` while the app is open; Ronda's payload is `data: {title, body}`. The
  manifest makes `rsvp` FCM's default channel and `ic_notification` its icon, so a notification
  message (the console's "Send test message") lands on the same channel. Checked 2026-10-29 on
  the Pixel 8 emulator: one HTTP v1 data message with the app in the background showed on `rsvp`
  at high importance.
- **Web:** the service worker `web/firebase-messaging-sw.js` is generated (§ Native and project
  checklist) and registered relative to the base href, so it works under `/app/`. Its scope is the
  base href, the same as Flutter's own `flutter_service_worker.js`, which since 3.47 only
  unregisters itself: Flutter's default bootstrap registers it whenever a worker already covers
  the page, so every launch after the first would drop the push subscription. `web/flutter_bootstrap.js`
  therefore calls `_flutter.loader.load()` without `serviceWorkerSettings` (checked 2026-10-29 in
  headless Chrome under the Hosting emulator: with the default bootstrap an FCM-style worker at
  `/app/` was gone after a reload; with this one it stayed). The token needs
  the Web Push certificate's public key, passed as `--dart-define=FCM_VAPID_KEY=<key>` to
  `flutter run -d chrome` and `flutter build web` (`scripts/build_web.sh` takes it from the
  `FCM_VAPID_KEY` environment variable). It is public by design (browsers receive it),
  so the rule against keys in dart-defines doesn't apply. Without it the JS SDK falls back to
  Firebase's default key, which may not work.

Built in #45 (`functions/rsvp.py`, `functions/fcm.py`, `packages/push_client`, `lib/bootstrap.dart`,
`lib/my_ronda/`):
- **Payload** (`rsvp.rsvp_messages`): Android gets `data: {type: "rsvp", rondaId, week, title,
  body}` with `android.priority: HIGH` and no `notification`; web gets `notification: {title,
  body}` with `webpush.fcm_options.link` to `/app/ronda` on the project's Hosting; `ios` tokens
  are skipped until the Apple Developer Program exists. The title is the ronda's line ("Sábado a
  la tarde · mate en la rambla", plus the public place's name once a host sets one) and the body
  who's going so far, what this member brings and "¿Venís?", in es-419, written by the server.
  No address ever goes into a push. A token FCM answers `UNREGISTERED` for is deleted.
- **Buttons:** `PushClient` draws a `type: rsvp` message with "Voy" and "Esta no"
  (`rsvp.yes` / `rsvp.no`, labelled in the phone's language), `showsUserInterface: false`, and
  the ronda and week as the payload. The manifest declares FLN's `ActionBroadcastReceiver`. A
  tap runs `answerRsvpFromNotification` (top level in each `main_<flavor>.dart`, so it knows the
  flavor's options and emulators) in a background engine, even with the app's process gone:
  `answerRsvpInBackground` starts Firebase, waits for the signed-in member, calls `answer_rsvp`
  through `RondaRepository` like the card does, and replaces the push with "Listo, vas." /
  "Listo, esta no." or, when it failed, "No se guardó tu respuesta". Checked 2026-10-29 on a
  Pixel 8 emulator with the app's process killed: [Voy] recorded the answer through the callable
  and the notice replaced the push.
- **Emulators:** FCM has no emulator, so `fcm.send` sends nothing under `FUNCTIONS_EMULATOR`. A
  second functions emulator is reached with `--dart-define=FIREBASE_FUNCTIONS_PORT=<port>` on
  `main_development.dart`.

Built in #46 (`functions/seguimos.py`, `packages/push_client`, `lib/bootstrap.dart`,
`lib/my_ronda/`):
- **The ask** has the RSVP push's shape with `data: {type: "seguimos", rondaId, title, body}`
  (no week: the server refuses an answer once the question has closed). `PushClient` draws it
  with "Sí" and "No" (`seguimos.yes` / `seguimos.no`, `SeguimosActionLabels`), and
  `answerRsvpInBackground` answers either push: `PushClient.seguimosActionFrom` reads the tap
  and `answer_seguimos` records it through `RondaRepository`. The notice that replaces the push
  says the answer was saved, never which: it shows on the lock screen.
- **The close's own messages** ("Gracias por venir.", the didn't-fill words, the season's words
  for whoever the RSVP skipped) are `data.type: "seguimosResult"`, drawn plain.
- Every Ronda notification uses `BigTextStyleInformation`, so the expanded notification shows
  the whole body ("… Nadie del grupo se entera de lo que digas.").
- Checked 2026-10-29 on the Pixel 8 emulator: one HTTP v1 data message built by the real job
  showed with [Yes] [No]; [Yes] with the app's process killed recorded the answer through the
  callable and the notice replaced the push.

Built in #48 (`functions/bench.py`, `packages/push_client`, `lib/bootstrap.dart`,
`lib/my_ronda/`):
- **The offer of a freed seat** goes through the organiser's outbox (gates, the introduction on
  a first message) with `data: {type: "benchOffer", offerId, rondaId, title, body}`.
  `PushClient` draws it with "Lo tomo" and "Esta vez no" (`bench.take` / `bench.pass`,
  `BenchOfferActionLabels`), and `answerRsvpInBackground` answers it through
  `answer_bench_offer` (`PushClient.benchOfferActionFrom`), replacing the push with "Listo, el
  lugar es tuyo." or "Listo, esta vez no.". The same offer shows on Mi ronda with the same two
  buttons. Not yet checked on the Pixel 8 emulator.
- **The simulated week** (`functions/tests/test_week.py`) runs the RSVP push, the answers, the
  bench, attendance and the ¿seguimos? close on the stand-in with every suite, and on the
  Firestore emulator with `scripts/week_on_emulators.sh` (project `demo-ronda-bench`).

Built in #47 and #50 (`packages/push_client`, `packages/push_repository`, `lib/app/view/app.dart`,
`packages/link_opener`, `packages/contact_repository`):
- **Taps that open a screen:** "¿Quién vino hoy?" (`data.type: attendance`) is drawn with a
  payload `{type, rondaId, week}` and no buttons. A tap on its body comes out of
  `PushClient.taps` (FLN's `onDidReceiveNotificationResponse`) while the app runs, or
  `launchTap()` (`getNotificationAppLaunchDetails`) when it started the app; `PushRepository`
  turns them into `OpenedRoll`s and `AppView` pushes `/asistencia/{rondaId}/{week}`. Every other
  push still opens Mi ronda, whose card asks "¿Abrís vos?", the después at your home and the
  buddy's card. Not checked on a device yet (no emulator in that session).
- **WhatsApp for a buddy:** `ContactRepository.openWhatsApp` opens `whatsapp://send` with no
  number and no text; `canOpenWhatsApp` asks url_launcher, which on Android 11+ needs the
  `whatsapp` scheme in the manifest's `<queries>` (added), and is always false on web, so
  [Le escribo] hides there.

## Native and project checklist

**Firebase project `ronda-uy`** (Blaze, decided 2026-10-27; budget alert at $20, `max_instances`
on every function): **Google sign-in** enabled (free and unlimited on Spark; Android needs the SHA-1 and SHA-256, iOS the
reversed client id URL scheme, web the authorised domains); Firestore in `southamerica-east1`;
Web Push (VAPID) key; admin custom claim for the owner. Phone/SMS sign-in stays off: it needs
Blaze and bills per SMS, so it is never enabled. Storage bucket in `southamerica-east1`. App Check
after the hackathon (callables require `auth != null` meanwhile, except `report_client_error`,
which is rate-limited instead: § Monitoring).

**Firebase in this repo** (set up 2026-10-27, #13). Five apps are registered in `ronda-uy`: Android
`com.ciroapps.ronda` (production) and `com.ciroapps.ronda.dev` (development), the same two
bundle ids on iOS, and one web app both flavors share. The debug keystore's SHA-1 and SHA-256 are
on both Android apps, and release builds are signed with that key until a release keystore exists
(§ Pilot builds).

- **Generated config stays out of git:** `lib/firebase_options_development.dart`,
  `lib/firebase_options_production.dart`, `android/app/src/<flavor>/google-services.json` and
  `ios/config/<flavor>/GoogleService-Info.plist`. CI copies `tool/firebase_options_stub.dart`
  (fake values) to both Dart names in the workflow's `setup:` step, so analyze and test pass on a
  clean checkout. The app reads its config from the Dart options; the iOS plists are written but
  not bundled (flutterfire's per-configuration build phase needs the CLI at build time and app ids
  in `firebase.json`, so it was left out). The FCM web worker carries the web config inline, so it
  is generated and git-ignored too: `dart tool/firebase_messaging_sw.dart` (from the repo root)
  writes `web/firebase-messaging-sw.js` from `lib/firebase_options_development.dart` (both flavors
  share the web app); CI runs it on the stub, and `scripts/build_web.sh` runs it on the options of
  the flavor it builds.
- **Fresh clone:** `firebase login`, then for each flavor
  `flutterfire configure --project=ronda-uy --platforms=android,ios,web --yes --out=lib/firebase_options_<flavor>.dart --android-package-name=<id> --android-out=android/app/src/<flavor>/google-services.json --ios-bundle-id=<id> --ios-out=ios/config/<flavor>/GoogleService-Info.plist --ios-build-config=Debug-<flavor>`
  (`<id>` is `com.ciroapps.ronda` or `com.ciroapps.ronda.dev`). Without `--ios-build-config` the
  CLI stops at an interactive prompt even with `--yes`. Afterwards revert what it adds to
  `ios/Runner.xcodeproj/project.pbxproj` and the `flutter` block it writes into `firebase.json`
  (both carry app ids), and run `dart tool/firebase_messaging_sw.dart`. Functions: `uv venv --seed --python 3.13 functions/venv` and
  `VIRTUAL_ENV=functions/venv uv pip install -r functions/requirements.txt`. The solver reaches
  the functions through the symlink `functions/ronda_solver → ../solver/ronda_solver`; the
  deploy archive follows it. Functions tests: add `-r functions/requirements-dev.txt`, then
  `cd functions && venv/bin/pytest --cov` (100%, over in-memory Firestore and Storage stand-ins,
  `functions/tests/fake_firestore.py` and `fake_storage.py`) and `venv/bin/ruff check . && venv/bin/ruff format --check .`.
  A whole voice sign-up on the Firestore and Storage emulators (the phone's writes under the
  rules, the real `extract` with Meta faked, then no need and no `audio/` path anywhere) runs
  from `functions/` with `firebase emulators:exec --only firestore,storage --project
  demo-ronda-voice "venv/bin/pytest tests/test_voice_signup_emulators.py"`; plain `pytest`
  skips it.
- **Rules tests** (`rules/`, `@firebase/rules-unit-testing` 6.0.0 on node's test runner):
  `cd rules && npm ci && npm run test:emulator` starts a Firestore emulator for them; with one
  already running on 8088, `npm test` uses it under the tests' own project ids
  (`demo-ronda-rules`, `demo-ronda-users`, `demo-ronda-public`, `demo-ronda-errors`: one per
  file, as node runs test files in parallel).
- **Admin claim:** the owner signs in once, then
  `uv run --python 3.13 scripts/set_admin.py <email>` (real project, Application Default
  Credentials) or with `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` for the emulator; sign out
  and in again for the claim to reach the token. The approval screen is `/admin` (web).
- **Emulators:** `firebase emulators:start` from the repo root (auth 9099, firestore **8088**,
  functions 5001, storage 9199, pubsub 8085, hosting **5002**, UI on :4000). Firestore is off its
  default 8080 because web dev servers often hold that port, and hosting off 5000 because macOS's
  AirPlay Receiver holds it. `ping` answers at
  `http://127.0.0.1:5001/ronda-uy/southamerica-east1/ping`. Hosting serves whatever `hosting/`
  holds (§ Pilot builds); an empty or missing folder only gives 404s.
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

**Android:** SHA-1 and SHA-256 of the signing key in the console (§ Pilot builds); manifest: `RECORD_AUDIO`,
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
collides with the public plain-HTML pages at `/` and `/f/{id}` (§ Pilot builds); ask
notification permission only from a tap.

**Needs on the phone:** one JSON blob under the key `needs`, shaped `{"needs":["walkALot","noCar"]}` (the `Need` enum names, so renaming a value loses what phones saved), in flutter_secure_storage with
`IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)`. On web it is
experimental: say "lo sabe solo este navegador".

## Pilot builds: Android on App Distribution, iPhone on the web app

Set up in #34. The owner runs every command that ships (the upload, `firebase deploy`); an agent
stops at `scripts/distribute_android.sh --build-only` and `scripts/build_web.sh development`.

**Android signing** (`android/app/build.gradle.kts`). A release build is signed with the first of:
the keystore in `ANDROID_KEYSTORE_PATH` (with `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`
and `ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD`); the one `android/key.properties` names (`storeFile`,
`storePassword`, `keyAlias`, `keyPassword`; git-ignored); else **the debug key**, and Gradle prints
a `WARNING: no release keystore` line. The debug key is the pilot default: its SHA-1 and SHA-256
are already on both Android apps and on the Android API key's restriction, so a debug-signed
release signs in with no console change. It can never go to a store, and only the Mac holding that
`~/.android/debug.keystore` can sign updates that install over it. To switch to a real key:
`keytool -genkeypair -v -keystore <path outside the repo>.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`,
write `android/key.properties`, register the key's SHAs (below) before shipping, and have testers
uninstall the debug-signed app once (Android refuses an update signed by another key).

**The SHAs to register** are those of the key that signs the build.
`scripts/distribute_android.sh` prints them for the APK it built (`apksigner verify --print-certs
build/app/outputs/flutter-apk/app-production-release.apk`, from the newest Android `build-tools`).
Before any build: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey
-storepass android` for the debug key, `keytool -list -v -keystore <path>.jks -alias upload` for a
release key.

**Contact address** (`RONDA_CONTACT_EMAIL`). Ajustes' "Contar algo que pasó" and "Tus datos"
show one address and open a mail to it (`contact_repository`, over `link_opener` and
url_launcher). It is read once in `lib/bootstrap.dart` from `--dart-define=RONDA_CONTACT_EMAIL=…`;
missing or empty, it is `hola@ciroapps.com`. Both build scripts below pass the
`RONDA_CONTACT_EMAIL` environment variable through. The address is public (it is on the screen),
not a secret. A person must read it: route it to a watched inbox before a build reaches members.

**Android build** (`scripts/distribute_android.sh ["<release notes>"]`): the production release
APK with `--obfuscate`, uploaded to the `pilot` group with the notes (default: the last commit's
subject). The app id comes from `lib/firebase_options_production.dart`. Symbols go to
`symbols/android/<version>-<commit>/` (git-ignored): keep them, `flutter symbolize` needs them to
read a crash. It stops early, saying what to do, when the production config files are missing or
firebase-tools isn't logged in. Bump `version:` in `pubspec.yaml` (`1.0.0+2`, `+3`, …) before each
upload, so testers see a new version. gen_snapshot's "unobfuscated DWARF debugging information"
warning is expected: AGP strips `libapp.so` when it packages the APK (no `.debug_*` section left,
checked 2026-10-29).

**Web on Hosting** (`firebase.json`). Hosting serves `hosting/`: the Flutter web app in
`hosting/app/` (git-ignored, staged by `scripts/build_web.sh`), and at the root the plain-HTML
public pages (§ Choices, built in #43), tracked: Cerca tuyo at `/` (`hosting/index.html`) and the
tear-off flyer's page at `/f/{id}` (`hosting/f/index.html`), sharing `hosting/assets/` (styles,
scripts, and the app's fonts with their OFL licences). No build step, no Firebase SDK.
- Cerca tuyo reads one `cerca/{barrio}` with Firestore's REST API, taking the project id and web
  key from Hosting's reserved `/__/firebase/init.json`; on `127.0.0.1` or `localhost` it reads the
  Firestore emulator on 8088 instead. The flyer page calls `/api/f/{id}`, which rewrites to the
  `flyer_landing` function in `southamerica-east1` (the Hosting emulator proxies it to the
  functions emulator). Copy is es-419, or English when the browser prefers it or `?lang=en`.
- `Cache-Control: no-cache` on the public pages' HTML, JS and CSS too, for the same reason as
  below; the fonts keep Hosting's default caching.
- `/app/**` rewrites to `/app/index.html`: the app uses the path URL strategy, so a deep link or a
  reload lands in the app.
- `Cache-Control: no-cache` on everything under `/app`: `index.html` (also served for every route
  through the rewrite), `flutter_service_worker.js`, `firebase-messaging-sw.js`, and the rest,
  because Flutter 3.47's file names carry no hash (`main.dart.js`, `flutter_bootstrap.js`,
  `assets/`) and no Flutter service worker caches them (§ Push, Web). Browsers revalidate with the
  ETag (a 304 when nothing changed), so a deploy reaches testers on their next launch.
- `predeploy` runs `scripts/build_web.sh`, so a deploy always ships a fresh production build, never
  a leftover development one, and needs `FCM_VAPID_KEY` set. With a `hosting` block a bare
  `firebase deploy` deploys Hosting too: always pass `--only`.
- `scripts/build_web.sh [production|development]` regenerates the FCM worker from that flavor's
  options, runs `flutter build web --release --base-href /app/` on its entrypoint with
  `--dart-define=FCM_VAPID_KEY` (required for production) and `RONDA_CONTACT_EMAIL` (optional,
  above), and copies `build/web` to
  `hosting/app/`. To try Hosting locally: `scripts/build_web.sh development` with the emulators
  up, then `http://127.0.0.1:5002/app/`.
- Add to Home Screen (iOS 16.4+, needed for push) uses what `web/` already has: `display:
  standalone` and the name in `manifest.json`, `apple-touch-icon` and `apple-mobile-web-app-title`
  in `index.html`.
- iPhone testers get `https://ronda-uy.firebaseapp.com/app/` rather than the `web.app` address: it
  is the web config's `authDomain`, so the Google sign-in popup stays on the app's own site and
  Safari's third-party storage blocking can't get in its way. Not yet tried from a Home Screen
  install; if the popup never comes back there, the fix is `signInWithRedirect` on that same
  domain, in `auth_repository`.

**Tear-off flyers** (`scripts/flyer.py`, #43). One command per spot writes `flyers/{id}` and a
printable A4 PDF: seven strips, each with a QR to `{base}/f/{id}` and "Ronda nunca pide plata".
From the repo root, with `--project ronda-uy` and Application Default Credentials for the real
project (or `FIRESTORE_EMULATOR_HOST=127.0.0.1:8088` and no `--project` for the emulator):
`uv run --python 3.13 scripts/flyer.py --lat <lat> --lng <lng> --label "<where it hangs>" --slot sat-afternoon --project ronda-uy`.
It downloads the DNT timetable (2.7 MB) unless `--gtfs <zip>` names a copy, prints the five
nearest stops with their last buses, uses the nearest unless `--stop <stop_id>` picks another
(the nearest can be a stop with three buses a day, or the wrong side of the road), and writes
`flyer-<id>.pdf`. `--base-url` defaults to `https://<project>.firebaseapp.com`, the sign-in domain,
so [Quiero sumarme] signs in on the same site. Print at 100% (no "fit to page"): the QRs are
24 mm. Scans are `flyers/{id}.scans` (Firestore console until the admin screen shows them).

**Shipping both, in order** (the owner):
1. `firebase login` with the account that owns `ronda-uy`.
2. Console → App Distribution, on the Android app `com.ciroapps.ronda` (Get started if asked) →
   Testers & Groups: create the group `pilot` (its alias must be `pilot`) and add the testers'
   Google emails.
3. Signing SHAs: nothing to do with the debug-signed default. With a release key, first add its
   SHA-1 and SHA-256 to `com.ciroapps.ronda` (Project settings → Your apps) and its SHA-1 to the
   Android API key's restriction (Google Cloud console → Credentials).
4. Console → Authentication → Settings → Authorised domains: check that `ronda-uy.firebaseapp.com`
   and `ronda-uy.web.app` are listed (Firebase adds both); add any custom domain.
5. Console → Project settings → Cloud Messaging → Web configuration → Web Push certificates:
   Generate key pair (unless one is listed), and copy the public key.
6. `scripts/distribute_android.sh "<qué cambió>"` (from the second upload on, bump `version:` in
   `pubspec.yaml` first). Testers get an email from App Distribution.
7. `FCM_VAPID_KEY=<public key> firebase deploy --only hosting` (the predeploy builds the web app),
   then send iPhone testers the link above: Safari → Share → Add to Home Screen, open Ronda from
   the icon, sign in, tap [Sí, avisame].
8. A test push: Console → Messaging → new notification campaign → Send test message, with a token
   from Firestore (`users/{uid}/tokens`: the document id is the token).

## Monitoring

Errors reach the owner two ways, chosen in `lib/bootstrap.dart` (`_errorReporter`), both through
`packages/error_reporter`'s `ErrorReporter`, which builds every report from the same scrubbed
fields (`docs/ARCHITECTURE.md` § Data model, `client_errors`):

| Where | Sink | When it sends |
|---|---|---|
| Android, iOS | Firebase Crashlytics (`CrashlyticsErrorReporter`): fatal and non-fatal, custom keys `screen` and `step` only, the uid hash as the user | Release builds of production only. The manifest (`firebase_crashlytics_collection_enabled`) and `Info.plist` (`FirebaseCrashlyticsCollectionEnabled`) start it off, so nothing is sent before Dart runs; bootstrap turns it on there, and elsewhere turns it off and deletes what it cached |
| Web | The `report_client_error` callable (`CallableErrorReporter`) → `client_errors/{id}`, 30 days | Always: the development flavor reports to the functions emulator. A debug build of production only logs |
| Debug phones, development flavor | `LocalErrorReporter`: one `dart:developer` line, code, screen and step | Never leaves the machine |

What feeds it:
- **Uncaught errors:** `installErrorHooks` wraps `FlutterError.onError` (step `framework`) and
  `PlatformDispatcher.instance.onError` (step `uncaught`), both fatal, after bootstrap's own
  debug log. Flutter's error details are never sent, only the exception and its stack.
- **Bloc errors:** `AppBlocObserver` is installed in both flavors (the development one logs type
  names, production's logs nothing) and sends every `addError` with the cubit's type as the step.
- **Handled failures that matter:** `ErrorReporter.reportFailure(screen:, step:, code:)`, a typed
  code with no message or stack. The reporter is provided above the app
  (`context.read<ErrorReporter>()`), so a page hands it to its cubit. For the voice sign-up
  (`agent/voice-web`), when the upload fails:
  `errorReporter.reportFailure(screen: OnboardingPage.path, step: 'voiceUpload', code: 'voice/${failure.reason.name}')`.
  Release web builds minify type names, so a typed code reads better than the error's type.
- **Screen:** `AppView` tells the reporter the route pattern on every navigation
  (`/acta/:rondaId`, never the filled path with its ids).
- The web sink batches for 2 s (a fatal report goes at once), 10 a call, sends each code and
  screen once and at most 20 reports a session; the server keeps at most 60 per caller per hour.

**How to read errors:**
- Android and iOS: Firebase console → Crashlytics, per app (`com.ciroapps.ronda`). Dart frames
  are readable once the build's symbols are uploaded: `scripts/distribute_android.sh` does it
  (`firebase crashlytics:symbols:upload --app=<app id> symbols/android/<version>-<commit>`);
  by hand, the same command.
- Web: `/admin/errores` (admin claim), grouped by code and screen, each group opening its
  newest reports. In the console: Firestore → `client_errors`.
- Server side: `firebase functions:log --only <function>` (for example `extract`,
  `report_client_error`), or Cloud Logging in the console.

**Not done yet (needs Xcode or the console):**
- iOS dSYMs: Crashlytics reads native iOS frames only with the dSYM upload run script build
  phase (`"${PODS_ROOT}/FirebaseCrashlytics/run"`, with the build's `GoogleService-Info.plist`)
  in `ios/Runner.xcodeproj`. The plists are written but not bundled (§ Native and project
  checklist), so add the phase with them, in Xcode, when iOS builds ship; until then iOS Dart
  errors still arrive, with Dart symbols uploaded by hand
  (`firebase crashlytics:symbols:upload --app=<ios app id> <symbols dir>`).
- CocoaPods: `firebase_crashlytics` adds its pod at `pod install`; the repo reverts
  `ios/Flutter/*.xcconfig` and `ios/Podfile` after `pub get`, so nothing of it is committed.

## Deploying
`scripts/deploy.sh` keeps the real project in step with main, one area at a time: Firestore
rules, indexes, Storage rules, functions and hosting.
- `scripts/deploy.sh --status` lists, per area, what changed on main since that area was last
  deployed, plus the functions in `functions/main.py` that aren't live yet and the live ones no
  longer in the code. It deploys nothing.
- `scripts/deploy.sh` deploys only the pending areas, non-interactively, from a clean `main` in
  step with `origin/main`. It then moves one tag per area to that commit
  (`deploy/ronda-uy/functions`, …) and pushes it, so the status is right on any machine.
- Hosting builds the production web app first, which needs the Web Push public key in
  `FCM_VAPID_KEY` (environment or the git-ignored `.env`). Without it hosting is skipped and
  stays pending.
- Removing a function makes a non-interactive deploy stop; check the list, then run
  `firebase deploy --only functions --force` yourself.

### Monitoring

What the owner does once in the console, after the deploy that brings `report_client_error`
(the app side is § Monitoring above):
1. **Crashlytics:** Firebase console → Crashlytics → Enable, on `com.ciroapps.ronda` (Android)
   and on the iOS app when it ships. The first report from a release production build usually
   enables it; if the dashboard still says it is waiting for data, enable it there.
2. **TTL:** `firebase deploy --only firestore:indexes` (or `scripts/deploy.sh`) sets the TTL
   policies from `firestore.indexes.json` (`client_errors.expireAt`,
   `client_error_quota.expireAt`). Check them in Firestore → Time-to-live; if missing, add them
   there, or `gcloud firestore fields ttls update expireAt --collection-group=client_errors
   --enable-ttl --project=ronda-uy` (and the same for `client_error_quota`). Deletion runs within
   about a day of `expireAt`.
3. **Rules:** `client_errors` is admin-read only; deploy `firestore:rules` with the function.
4. **Symbols:** every `scripts/distribute_android.sh` upload sends the Dart symbols; a build
   uploaded another way needs `firebase crashlytics:symbols:upload` by hand.

## What doesn't work on web
Face blur (no ML Kit): the photo flows say "Hacelo desde la app del teléfono". Push buttons
(Chromium only). iPhone push without a Home Screen install. Everything else works.
