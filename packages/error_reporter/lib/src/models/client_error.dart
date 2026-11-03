import 'package:equatable/equatable.dart';

/// {@template client_error}
/// One stored web error report, as the admin reads it on `/admin/errores`.
/// {@endtemplate}
class const ClientError({
  /// The document id.
  required final String id,

  /// `web`, `android`, `ios` or `other`.
  required final String platform,

  /// The app's version.
  required final String appVersion,

  /// The app's build number.
  required final String build,

  /// `development`, `production` or `other`.
  required final String flavor,

  /// The route pattern on screen.
  required final String screen,

  /// The step or action.
  required final String step,

  /// The error code.
  required final String code,

  /// The scrubbed first line.
  required final String message,

  /// The scrubbed stack.
  required final String stack,

  /// Whether nothing caught it.
  required final bool fatal,

  /// When the server stored it.
  required final DateTime at,
}) extends Equatable {
  /// {@macro client_error}
  this;

  /// This report as plain text for a bug report: screen, step, code,
  /// message, build, time (UTC) and stack.
  String get reportText => [
    'screen: ${screen.isEmpty ? '-' : screen}',
    'step: ${step.isEmpty ? '-' : step}',
    'code: $code',
    'message: ${message.isEmpty ? '-' : message}',
    'platform: $platform',
    'build: $appVersion ($build) $flavor',
    'fatal: $fatal',
    'time: ${at.toUtc().toIso8601String()}',
    'stack:',
    if (stack.isEmpty) '-' else stack,
  ].join('\n');

  @override
  List<Object?> get props => [
    id,
    platform,
    appVersion,
    build,
    flavor,
    screen,
    step,
    code,
    message,
    stack,
    fatal,
    at,
  ];
}

/// Why the error log couldn't be read.
enum ClientErrorLogFailureReason {
  /// The account isn't the admin.
  forbidden,

  /// Anything else (offline, a server error).
  other,
}

/// {@template client_error_log_failure}
/// The error log couldn't be read.
/// {@endtemplate}
class const ClientErrorLogFailure(final ClientErrorLogFailureReason reason)
    implements Exception {
  /// {@macro client_error_log_failure}
  this;

  @override
  String toString() => 'ClientErrorLogFailure(${reason.name})';
}
