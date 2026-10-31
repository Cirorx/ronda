import 'dart:developer' as developer;

import 'package:error_reporter/src/error_reporter.dart';
import 'package:error_reporter/src/models/models.dart';

/// Writes one log line, as `dart:developer`'s `log` does.
typedef ReportLogger = void Function(String message);

/// Keeps reports on the machine: debug builds and the development flavor on
/// a phone, which must not send to Crashlytics. Logs the scrubbed code,
/// screen and step only.
class LocalErrorReporter extends ErrorReporter {
  /// Logs with `logger`, `dart:developer`'s `log` by default.
  new({required super.app, this._logger = developer.log});

  final ReportLogger _logger;

  @override
  Future<void> send(ErrorReport report) async => _logger(
    'error report: ${report.code} on "${report.screen}" '
    '(${report.step})${report.fatal ? ', fatal' : ''}',
  );
}
