import 'package:error_reporter/src/error_reporter.dart';
import 'package:error_reporter/src/models/models.dart';
import 'package:error_reporter/src/scrub.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Reports to Firebase Crashlytics (Android and iOS, release production
/// builds only): fatal and non-fatal errors, with two custom keys, `screen`
/// and `step`, and the hashed uid as the user.
///
/// Crashlytics is handed a [ReportedError] built from the scrubbed report,
/// never the error itself, whose message could carry what someone typed.
class CrashlyticsErrorReporter extends ErrorReporter {
  /// Built in bootstrap from `FirebaseCrashlytics.instance`.
  new({required this._crashlytics, required super.app});

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> setUser(String? uid) =>
      _crashlytics.setUserIdentifier(uid == null ? '' : uidHash(uid));

  @override
  Future<void> send(ErrorReport report) async {
    await _crashlytics.setCustomKey('screen', report.screen);
    await _crashlytics.setCustomKey('step', report.step);
    await _crashlytics.recordError(
      ReportedError(report.code, report.message),
      report.stack.isEmpty ? null : StackTrace.fromString(report.stack),
      fatal: report.fatal,
      printDetails: false,
    );
  }
}

/// {@template reported_error}
/// What Crashlytics sees of an error: its code and scrubbed first line.
/// {@endtemplate}
class const ReportedError(final String code, final String message)
    implements Exception {
  /// {@macro reported_error}
  this;

  @override
  String toString() => message.isEmpty ? code : '$code: $message';
}
