import 'package:equatable/equatable.dart';
import 'package:error_reporter/src/models/app_info.dart';

/// {@template error_report}
/// One scrubbed error report: where it happened and what. It never holds a
/// name, a phone number, an email, audio, a transcript, a need, a barrio, a
/// photo or free text (`docs/ARCHITECTURE.md`, `client_errors`).
/// {@endtemplate}
class const ErrorReport({
  /// The platform, version, build and flavor.
  required final AppInfo app,

  /// The route pattern on screen (`/acta/:rondaId`), or empty.
  required final String screen,

  /// The step or action (`voiceUpload`, a cubit's type), or empty.
  required final String step,

  /// What went wrong: a typed failure's code (`voice/uploadFailed`), a
  /// Firebase error (`firebase_storage/unauthorized`) or the error's type.
  required final String code,

  /// The error's first line, scrubbed; empty for a typed failure.
  final String message = '',

  /// The stack, scrubbed; empty for a typed failure.
  final String stack = '',

  /// Whether it took the app down (an uncaught error).
  final bool fatal = false,
}) extends Equatable {
  /// {@macro error_report}
  this;

  /// The shape `report_client_error` takes; the server adds the time and
  /// the hashed uid from the call itself.
  Map<String, Object> toJson() => {
    'platform': app.platform,
    'appVersion': app.version,
    'build': app.build,
    'flavor': app.flavor,
    'screen': screen,
    'step': step,
    'code': code,
    'message': message,
    'stack': stack,
    'fatal': fatal,
  };

  @override
  List<Object?> get props => [app, screen, step, code, message, stack, fatal];
}
