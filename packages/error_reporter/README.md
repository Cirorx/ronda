# error_reporter

Repository layer. Ronda's error monitoring (`docs/STACK.md` § Monitoring): every report is built
here from the same scrubbed fields, then sent to Crashlytics (Android, iOS), to the
`report_client_error` callable (web), or only to the debug log. It also reads the web error log
for the admin's `/admin/errores`.

A report holds the platform, version, build and flavor, the route pattern, the step, an error
code, the error's first line and its stack (both scrubbed: URL queries, emails, quoted text, ids
and long numbers are replaced), whether it was fatal, and on Crashlytics a hash of the uid. It
never holds a name, a phone number, an email, audio, a transcript, a need or free text.

## API

| Member | Does |
|---|---|
| `AppInfo.load(flavor:)` | The platform, version and build of the running app |
| `CrashlyticsErrorReporter(crashlytics:, app:)` | Fatal and non-fatal errors to Crashlytics, keys `screen` and `step`, the uid hash as the user |
| `CallableErrorReporter(functions:, app:)` | Batches to `report_client_error`: 10 a call, each code and screen once, 20 a session |
| `LocalErrorReporter(app:)` | One `dart:developer` line per report; nothing leaves the machine |
| `ErrorReporter.recordError(error, stack, {fatal, step})` | An error nothing handled, or a cubit's `addError` |
| `ErrorReporter.reportFailure(screen:, step:, code:)` | A handled failure that matters, by a typed code |
| `ErrorReporter.setScreen(pattern)` / `setUser(uid)` | The route pattern on screen; who is signed in (hashed) |
| `installErrorHooks(reporter)` | `FlutterError.onError` and `PlatformDispatcher.onError` to the reporter, as fatal |
| `ClientErrorLog(firestore:).watchRecent()` | The newest `client_errors`, admin only; a refusal is `ClientErrorLogFailure(forbidden)` |
| `uidHash(uid)` | The uid as reports carry it, the same as the server's `client_errors.uid_hash` |
